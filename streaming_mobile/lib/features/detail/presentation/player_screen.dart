import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:streaming_mobile/core/core.dart';
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
  List<PlayerSubtitle>? _subtitles;
  SubtitleTrack? _currentSubtitleTrack;
  String _currentResolutionLabel = 'Auto';

  Future<void> _handleResolutionChanged(String url, String label) async {
    final oldController = _videoController;
    final position = oldController?.value.position ?? Duration.zero;
    final isPlaying = oldController?.value.isPlaying ?? false;

    final uri = Uri.parse(url);
    final isHls = uri.path.contains('.m3u8') || url.contains('m3u8') || !uri.path.endsWith('.mp4');

    final newController = VideoPlayerController.networkUrl(
      uri,
      formatHint: isHls ? VideoFormat.hls : null,
    );

    try {
      await newController.initialize();
      await newController.seekTo(position);
      if (isPlaying) {
        await newController.play();
      }

      if (mounted) {
        setState(() {
          _videoController = newController;
          _currentResolutionLabel = label;
        });
      }

      if (oldController != null) {
        await oldController.dispose();
      }
    } catch (e) {
      debugPrint('[PlayerScreen] Quality swap failed: $e');
      newController.dispose();
    }
  }

  @override
  void initState() {
    super.initState();
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
          .unlock(slug: widget.slug, isMovie: widget.isMovie);
    });
  }

  @override
  void dispose() {
    // Kembalikan orientasi normal saat keluar
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WakelockPlus.disable();
    _videoController?.dispose();
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

    _videoController = VideoPlayerController.networkUrl(
      uri,
      formatHint: isHls ? VideoFormat.hls : null,
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
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final streamState = ref.watch(streamProviderFor(widget.episodeId));

    ref.listen(streamProviderFor(widget.episodeId), (prev, next) {
      if (next.hasResult && _videoController == null) {
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
