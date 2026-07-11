import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:streaming_mobile/core/core.dart';
import 'package:streaming_mobile/core/utils/file_logger.dart';
import 'package:streaming_mobile/features/detail/data/stream_result.dart';
import 'package:streaming_mobile/features/detail/domain/detail_provider.dart';
import 'package:streaming_mobile/shared/atoms/app_text.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:streaming_mobile/shared/molecules/custom_video_player.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({
    super.key,
    required this.episodeId,
    required this.slug,
    required this.isMovie,
  });

  final String episodeId;
  final String slug;
  final bool isMovie;

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  VideoPlayerController? _videoController;
  VideoPlayerController? _pendingController; // tracks in-flight controller during resolution swap
  List<PlayerSubtitle>? _subtitles;
  SubtitleTrack? _currentSubtitleTrack;
  String _currentResolutionLabel = 'Auto';
  bool _hasInitialized = false;
  bool _isDisposed = false;
  // Store notifier reference before dispose — calling ref.read() in dispose() is unsafe in Riverpod
  StreamUnlockNotifier? _streamNotifier;

  Future<void> _handleResolutionChanged(String url, String label) async {
    if (_isDisposed) return;
    FileLogger.log('[PlayerScreen] Starting resolution switch to: $label (URL: $url)');
    final oldController = _videoController;
    final position = oldController?.value.position ?? Duration.zero;
    final isPlaying = oldController?.value.isPlaying ?? false;

    // 1. Instantly set _videoController to null so the UI stops using it and renders the loading spinner
    if (mounted) {
      setState(() {
        _videoController = null;
      });
    }

    // 2. Pause and mute the old controller to free the AudioTrack/AudioSession.
    // We do NOT dispose it yet because the widget tree may still hold references/listeners to it
    // during the rebuild transition. Disposing it now will cause a crash.
    if (oldController != null) {
      try {
        FileLogger.log('[PlayerScreen] Pausing and muting old controller...');
        await oldController.pause();
        await oldController.setVolume(0.0);
      } catch (e) {
        FileLogger.log('[PlayerScreen] Failed to pause/mute old controller: $e');
      }
    }

    if (_isDisposed) {
      oldController?.dispose();
      return;
    }

    final uri = Uri.parse(url);
    final isHls = uri.path.contains('.m3u8') || url.contains('m3u8') || !uri.path.endsWith('.mp4');

    final headers = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Referer': 'https://idlixku.com/',
    };

    VideoPlayerController newController = VideoPlayerController.networkUrl(
      uri,
      formatHint: isHls ? VideoFormat.hls : null,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
      httpHeaders: headers,
    );

    _pendingController = newController;

    try {
      await newController.initialize();
      if (_isDisposed) {
        newController.dispose();
        _pendingController = null;
        return;
      }
      FileLogger.log('[PlayerScreen] New controller initialized successfully.');
      await newController.setVolume(1.0);
      FileLogger.log('[PlayerScreen] New controller volume set to 1.0.');
      await newController.seekTo(position);
      FileLogger.log('[PlayerScreen] New controller seeked to position: $position');
      if (isPlaying) {
        await newController.play();
        FileLogger.log('[PlayerScreen] New controller playback started.');
      }

      if (mounted && !_isDisposed) {
        setState(() {
          _videoController = newController;
          _currentResolutionLabel = label;
        });
        _pendingController = null;
      } else {
        newController.dispose();
        _pendingController = null;
      }

      // 3. Now that the new controller is active/set, safely dispose the old controller in the next frame.
      if (oldController != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          oldController.dispose().catchError((e) {
            FileLogger.log('[PlayerScreen] Failed to dispose old controller: $e');
          });
        });
      }
    } catch (e) {
      FileLogger.log('[PlayerScreen] Quality swap failed: $e');
      newController.dispose();
      _pendingController = null;

      // Fail-safe recovery: restore the old controller
      if (!_isDisposed && oldController != null) {
        try {
          await oldController.setVolume(1.0);
          if (isPlaying) {
            await oldController.play();
          }
        } catch (restoreError) {
          FileLogger.log('[PlayerScreen] Failed to restore old controller: $restoreError');
        }
      }

      if (mounted && !_isDisposed) {
        setState(() {
          _videoController = oldController;
        });
      } else {
        oldController?.dispose();
      }
    }
  }

  @override
  void initState() {
    super.initState();
    // Cache notifier ref here — safe to use in dispose()
    _streamNotifier = ref.read(streamProviderFor(widget.episodeId).notifier);
    // Lock ke landscape saat player dibuka
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    WakelockPlus.enable();

    // Mulai unlock stream
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(streamProviderFor(widget.episodeId).notifier)
          .unlock(slug: widget.slug, isMovie: widget.isMovie, context: context);
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    // Use pre-stored notifier — safe because it doesn't go through ref
    try { _streamNotifier?.reset(); } catch (_) {}
    // Kembalikan orientasi normal saat keluar
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WakelockPlus.disable();
    // Pause immediately to silence audio before releasing resources
    _videoController?.pause();
    _videoController?.dispose();
    // Also dispose any in-flight pending controller from a resolution swap
    _pendingController?.pause();
    _pendingController?.dispose();
    super.dispose();
  }

  Future<String?> _fetchUrl(String url) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode == 200) {
        return await response.transform(utf8.decoder).join();
      }
    } catch (_) {} finally {
      client.close();
    }
    return null;
  }

  Future<void> _initPlayer(String url, {List<SubtitleTrack>? subtitleTracks}) async {
    final uri = Uri.parse(url);
    final isHls = uri.path.contains('.m3u8') ||
        url.contains('m3u8') ||
        !uri.path.endsWith('.mp4');

    final headers = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Referer': 'https://idlixku.com/',
    };

    _videoController = VideoPlayerController.networkUrl(
      uri,
      formatHint: isHls ? VideoFormat.hls : null,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      httpHeaders: headers,
    );
    await _videoController!.initialize();

    List<PlayerSubtitle>? parsedSubtitles;
    SubtitleTrack? selectedTrack;
    if (subtitleTracks != null && subtitleTracks.isNotEmpty) {
      selectedTrack = subtitleTracks.firstWhere(
        (t) => t.lang.toLowerCase() == 'id' || t.label.toLowerCase().contains('indo'),
        orElse: () => subtitleTracks.first,
      );
      final vttContent = await _fetchUrl(selectedTrack.path);
      if (vttContent != null) {
        parsedSubtitles = CustomVideoPlayer.parseVtt(vttContent);
      }
    }

    if (mounted) {
      setState(() {
        _subtitles = parsedSubtitles;
        _currentSubtitleTrack = selectedTrack;
        _hasInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final streamState = ref.watch(streamProviderFor(widget.episodeId));

    ref.listen(streamProviderFor(widget.episodeId), (prev, next) {
      if (next.hasResult && !_hasInitialized) {
        _initPlayer(next.result!.url, subtitleTracks: next.result!.subtitles);
      }
    });

    final displayTitle = widget.slug
        .replaceAll('-', ' ')
        .split(' ')
        .map((s) => s.isNotEmpty ? s[0].toUpperCase() + s.substring(1) : '')
        .join(' ');

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Video Player ──
          if (_videoController != null && _videoController!.value.isInitialized)
            CustomVideoPlayer(
              controller: _videoController!,
              title: displayTitle,
              subtitles: _subtitles,
              subtitleTracks: streamState.result?.subtitles,
              currentSubtitleTrack: _currentSubtitleTrack,
              onSubtitleTrackChanged: (track) async {
                setState(() {
                  _currentSubtitleTrack = track;
                  _subtitles = null;
                });
                final vttContent = await _fetchUrl(track.path);
                if (vttContent != null) {
                  setState(() {
                    _subtitles = CustomVideoPlayer.parseVtt(vttContent);
                  });
                }
              },
              onBack: () => context.pop(),
              currentResolutionLabel: _currentResolutionLabel,
              onResolutionChanged: _handleResolutionChanged,
              onFullScreenControllerChanged: (newController, label) {
                setState(() {
                  _videoController = newController;
                  _currentResolutionLabel = label;
                });
              },
            ),

          // ── Loading / Countdown Screen ──
          if (!streamState.hasResult && (_videoController == null || !_videoController!.value.isInitialized))
            _CountdownOverlay(
              streamState: streamState,
              onBack: () => context.pop(),
            ),

          // ── Loading Spinner for Resolution Switching ──
          if (streamState.hasResult && (_videoController == null || !_videoController!.value.isInitialized))
            const Center(
              child: CircularProgressIndicator(
                color: Colors.red,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Countdown overlay saat proses unlock berlangsung ─────────

class _CountdownOverlay extends StatefulWidget {
  const _CountdownOverlay({required this.streamState, required this.onBack});

  final StreamState streamState;
  final VoidCallback onBack;

  @override
  State<_CountdownOverlay> createState() => _CountdownOverlayState();
}

class _CountdownOverlayState extends State<_CountdownOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  int _seconds = 16;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    // Countdown visual
    _startCountdown();
  }

  void _startCountdown() async {
    while (_seconds > 0 && mounted) {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) setState(() => _seconds--);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  String get _stepLabel => switch (widget.streamState.step) {
    1 => 'Menghubungi server...',
    2 => 'Memproses izin akses... ($_seconds detik)',
    3 => 'Mengambil stream...',
    _ => 'Mempersiapkan...',
  };

  @override
  Widget build(BuildContext context) {
    if (widget.streamState.error != null) {
      return _ErrorOverlay(
        message: widget.streamState.error!,
        onBack: widget.onBack,
      );
    }

    return Container(
      color: Colors.black,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Back button
          Align(
            alignment: Alignment.topLeft,
            child: SafeArea(
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.textMuted),
                onPressed: widget.onBack,
              ),
            ),
          ),
          const Spacer(),

          // Animasi glow
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, child) => Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(
                      alpha: 0.3 + _pulse.value * 0.4,
                    ),
                    blurRadius: 30 + _pulse.value * 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: AppColors.primary,
                size: 40,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          AppText(
            _stepLabel,
            variant: AppTextVariant.body,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: AppSpacing.sm),
          const SizedBox(
            width: 200,
            child: LinearProgressIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.surface,
            ),
          ),

          const Spacer(),
        ],
      ),
    );
  }
}

class _ErrorOverlay extends StatelessWidget {
  const _ErrorOverlay({required this.message, required this.onBack});
  final String message;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: AppColors.textMuted, size: 48),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: AppText(
              message,
              color: AppColors.textMuted,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextButton(
            onPressed: onBack,
            child: const Text(
              'Kembali',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}
