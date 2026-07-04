import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:streaming_mobile/core/core.dart';
import 'package:streaming_mobile/features/detail/domain/detail_provider.dart';
import 'package:streaming_mobile/shared/atoms/app_text.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

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

  Future<void> _initPlayer(String url) async {
    final uri = Uri.parse(url);
    final isHls = uri.path.contains('.m3u8') ||
        url.contains('m3u8') ||
        !uri.path.endsWith('.mp4');

    _videoController = VideoPlayerController.networkUrl(
      uri,
      formatHint: isHls ? VideoFormat.hls : null,
    );
    await _videoController!.initialize();

    _chewieController = ChewieController(
      videoPlayerController: _videoController!,
      autoPlay: true,
      looping: false,
      allowFullScreen: true,
      allowMuting: true,
      showControls: true,
      materialProgressColors: ChewieProgressColors(
        playedColor: AppColors.primary,
        handleColor: AppColors.primary,
        bufferedColor: AppColors.primaryGlow,
        backgroundColor: AppColors.surface,
      ),
      zoomAndPan: true, // Coba aktifkan fitur zoom bawaan chewie jika ada
    );

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final streamState = ref.watch(streamProviderFor(widget.episodeId));

    ref.listen(streamProviderFor(widget.episodeId), (prev, next) {
      if (next.hasResult && _videoController == null) {
        _initPlayer(next.result!.url);
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
                    InteractiveViewer(
                      minScale: 1.0,
                      maxScale: 4.0,
                      child: Chewie(controller: _chewieController!),
                    ),
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
