import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:streaming_mobile/core/core.dart';
import 'package:streaming_mobile/features/detail/data/stream_result.dart';
import 'package:streaming_mobile/features/detail/domain/detail_provider.dart';
import 'package:streaming_mobile/shared/atoms/app_text.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

enum VideoScaleMode { fit, zoom, stretch }

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
  ChewieController? _chewieController;
  VideoScaleMode _scaleMode = VideoScaleMode.fit;

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
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Duration _parseVttDuration(String s) {
    final parts = s.split(':');
    if (parts.length == 3) {
      final hours = int.parse(parts[0]);
      final minutes = int.parse(parts[1]);
      final secondsParts = parts[2].split('.');
      final seconds = int.parse(secondsParts[0]);
      final milliseconds = int.parse(secondsParts[1].padRight(3, '0').substring(0, 3));
      return Duration(hours: hours, minutes: minutes, seconds: seconds, milliseconds: milliseconds);
    } else if (parts.length == 2) {
      final minutes = int.parse(parts[0]);
      final secondsParts = parts[1].split('.');
      final seconds = int.parse(secondsParts[0]);
      final milliseconds = int.parse(secondsParts[1].padRight(3, '0').substring(0, 3));
      return Duration(minutes: minutes, seconds: seconds, milliseconds: milliseconds);
    }
    throw FormatException("Invalid VTT duration: $s");
  }

  Subtitles _parseVtt(String vttContent) {
    final List<Subtitle> list = [];
    final lines = vttContent.replaceAll('\r\n', '\n').split('\n');

    int index = 0;
    String? timestampLine;
    final List<String> textLines = [];

    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        if (timestampLine != null && textLines.isNotEmpty) {
          try {
            final times = timestampLine.split('-->');
            if (times.length == 2) {
              final start = _parseVttDuration(times[0].trim());
              final end = _parseVttDuration(times[1].trim());
              list.add(Subtitle(
                index: index++,
                start: start,
                end: end,
                text: textLines.join('\n'),
              ));
            }
          } catch (_) {}
          timestampLine = null;
          textLines.clear();
        }
        continue;
      }

      if (trimmed.startsWith('WEBVTT') || trimmed.startsWith('NOTE')) {
        continue;
      }

      if (trimmed.contains('-->')) {
        timestampLine = trimmed;
      } else if (timestampLine != null) {
        textLines.add(trimmed);
      }
    }

    if (timestampLine != null && textLines.isNotEmpty) {
      try {
        final times = timestampLine.split('-->');
        if (times.length == 2) {
          final start = _parseVttDuration(times[0].trim());
          final end = _parseVttDuration(times[1].trim());
          list.add(Subtitle(
            index: index++,
            start: start,
            end: end,
            text: textLines.join('\n'),
          ));
        }
      } catch (_) {}
    }

    return Subtitles(list);
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

    Subtitles? parsedSubtitles;
    if (subtitleTracks != null && subtitleTracks.isNotEmpty) {
      final track = subtitleTracks.firstWhere(
        (t) => t.lang.toLowerCase() == 'id' || t.label.toLowerCase().contains('indo'),
        orElse: () => subtitleTracks.first,
      );
      final vttContent = await _fetchUrl(track.path);
      if (vttContent != null) {
        parsedSubtitles = _parseVtt(vttContent);
      }
    }

    _chewieController = ChewieController(
      videoPlayerController: _videoController!,
      autoPlay: true,
      looping: false,
      allowFullScreen: true,
      allowMuting: true,
      showControls: true,
      subtitle: parsedSubtitles,
      subtitleBuilder: parsedSubtitles != null
          ? (context, subtitle) => Positioned(
                bottom: 25,
                left: 20,
                right: 20,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(6.0),
                    ),
                    child: Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16.0,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              )
          : null,
      materialProgressColors: ChewieProgressColors(
        playedColor: AppColors.primary,
        handleColor: AppColors.primary,
        bufferedColor: AppColors.primaryGlow,
        backgroundColor: AppColors.surface,
      ),
    );

    if (mounted) setState(() {});
  }

  Widget _buildScaledVideoPlayer() {
    final size = _videoController!.value.size;
    final width = size.width;
    final height = size.height;

    if (width == 0 || height == 0) {
      return Chewie(controller: _chewieController!);
    }

    switch (_scaleMode) {
      case VideoScaleMode.fit:
        return Chewie(controller: _chewieController!);
      case VideoScaleMode.zoom:
        return FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: width,
            height: height,
            child: Chewie(controller: _chewieController!),
          ),
        );
      case VideoScaleMode.stretch:
        return FittedBox(
          fit: BoxFit.fill,
          child: SizedBox(
            width: width,
            height: height,
            child: Chewie(controller: _chewieController!),
          ),
        );
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

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Video Player ──
          if (_chewieController != null)
            Center(
              child: SizedBox.expand(
                child: Stack(
                  children: [
                    // Ambient glow merah
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryGlow,
                            blurRadius: 60,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                    ),
                    _buildScaledVideoPlayer(),
                    ValueListenableBuilder(
                      valueListenable: _videoController!,
                      builder: (context, VideoPlayerValue value, child) {
                        if (value.isBuffering) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                ),
              ),
            ),

          // ── Video Sizing Mode Toggle Button (Top-Right) ──
          if (_chewieController != null)
            Positioned(
              top: 16,
              right: 68,
              child: ClipOval(
                child: Material(
                  color: Colors.black.withOpacity(0.5),
                  child: IconButton(
                    icon: Icon(
                      _scaleMode == VideoScaleMode.fit
                          ? Icons.fit_screen_outlined
                          : _scaleMode == VideoScaleMode.zoom
                              ? Icons.fullscreen_exit_outlined
                              : Icons.fullscreen_outlined,
                      color: Colors.white,
                    ),
                    tooltip: 'Sizing Mode',
                    onPressed: () {
                      setState(() {
                        if (_scaleMode == VideoScaleMode.fit) {
                          _scaleMode = VideoScaleMode.zoom;
                        } else if (_scaleMode == VideoScaleMode.zoom) {
                          _scaleMode = VideoScaleMode.stretch;
                        } else {
                          _scaleMode = VideoScaleMode.fit;
                        }
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            _scaleMode == VideoScaleMode.fit
                                ? 'Mode: Fit (Asli)'
                                : _scaleMode == VideoScaleMode.zoom
                                    ? 'Mode: Zoom (Penuhi Layar)'
                                    : 'Mode: Stretch (Regangkan)',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          duration: const Duration(seconds: 1),
                          behavior: SnackBarBehavior.floating,
                          width: 250,
                          backgroundColor: AppColors.surface.withOpacity(0.9),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

          // ── Loading / Countdown Screen ──
          if (!streamState.hasResult && _chewieController == null)
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
