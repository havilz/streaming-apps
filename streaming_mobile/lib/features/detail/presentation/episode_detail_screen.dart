import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:streaming_mobile/core/core.dart';
import 'package:streaming_mobile/features/detail/data/data.dart';
import 'package:streaming_mobile/features/detail/domain/detail_provider.dart';
import 'package:streaming_mobile/shared/shared.dart';

class EpisodeDetailScreen extends ConsumerStatefulWidget {
  const EpisodeDetailScreen({
    super.key,
    required this.episodeId,
    required this.slug,
    this.initialEpisode,
  });

  final String episodeId;
  final String slug;
  final EpisodeModel? initialEpisode;

  @override
  ConsumerState<EpisodeDetailScreen> createState() => _EpisodeDetailScreenState();
}

class _EpisodeDetailScreenState extends ConsumerState<EpisodeDetailScreen> {
  late String _activeEpisodeId;
  EpisodeModel? _lastKnownEpisode;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _activeEpisodeId = widget.episodeId;
    if (widget.initialEpisode != null) {
      _lastKnownEpisode = widget.initialEpisode;
      // Inisialisasi active season sesuai season episode ini
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(activeSeasonProviderFor(widget.slug).notifier)
            .set(widget.initialEpisode!.seasonNumber);
      });
    }
  }

  @override
  void didUpdateWidget(covariant EpisodeDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.episodeId != widget.episodeId) {
      setState(() {
        _activeEpisodeId = widget.episodeId;
        _isPlaying = false;
        if (widget.initialEpisode != null) {
          _lastKnownEpisode = widget.initialEpisode;
          ref
              .read(activeSeasonProviderFor(widget.slug).notifier)
              .set(widget.initialEpisode!.seasonNumber);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final episodeAsync = ref.watch(episodeDetailProvider(_activeEpisodeId));

    // Sinkronisasi active season jika data episode dimuat asinkron
    episodeAsync.whenData((episode) {
      if (episode != null) {
        _lastKnownEpisode = episode;
        final currentActive = ref.read(activeSeasonProviderFor(widget.slug));
        if (currentActive != episode.seasonNumber) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref
                .read(activeSeasonProviderFor(widget.slug).notifier)
                .set(episode.seasonNumber);
          });
        }
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: episodeAsync.when(
        loading: () => _lastKnownEpisode != null
            ? _EpisodeDetailBody(
                episode: _lastKnownEpisode!,
                slug: widget.slug,
                activeEpisodeId: _activeEpisodeId,
                isPlaying: _isPlaying,
                onPlayPressed: () {
                  setState(() {
                    _isPlaying = true;
                  });
                },
                onEpisodeSelect: (newId, ep) {
                  setState(() {
                    _activeEpisodeId = newId;
                    _isPlaying = false;
                    if (ep != null) _lastKnownEpisode = ep;
                  });
                },
              )
            : const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
        error: (e, _) => _lastKnownEpisode != null
            ? _EpisodeDetailBody(
                episode: _lastKnownEpisode!,
                slug: widget.slug,
                activeEpisodeId: _activeEpisodeId,
                isPlaying: _isPlaying,
                onPlayPressed: () {
                  setState(() {
                    _isPlaying = true;
                  });
                },
                onEpisodeSelect: (newId, ep) {
                  setState(() {
                    _activeEpisodeId = newId;
                    _isPlaying = false;
                    if (ep != null) _lastKnownEpisode = ep;
                  });
                },
              )
            : _ErrorBody(message: e.toString()),
        data: (episode) {
          final activeEpisode = episode ?? _lastKnownEpisode;
          if (activeEpisode == null) {
            return const _ErrorBody(message: 'Episode tidak ditemukan.');
          }
          return _EpisodeDetailBody(
            episode: activeEpisode,
            slug: widget.slug,
            activeEpisodeId: _activeEpisodeId,
            isPlaying: _isPlaying,
            onPlayPressed: () {
              setState(() {
                _isPlaying = true;
              });
            },
            onEpisodeSelect: (newId, ep) {
              setState(() {
                _activeEpisodeId = newId;
                _isPlaying = false;
                if (ep != null) _lastKnownEpisode = ep;
              });
            },
          );
        },
      ),
    );
  }
}

class _EpisodeDetailBody extends ConsumerWidget {
  const _EpisodeDetailBody({
    required this.episode,
    required this.slug,
    required this.activeEpisodeId,
    required this.isPlaying,
    required this.onPlayPressed,
    required this.onEpisodeSelect,
  });

  final EpisodeModel episode;
  final String slug;
  final String activeEpisodeId;
  final bool isPlaying;
  final VoidCallback onPlayPressed;
  final void Function(String id, EpisodeModel? ep) onEpisodeSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Ambil detail series untuk info season selector & fallback backdrop
    final seriesDetailAsync = ref.watch(seriesDetailProvider(slug));
    final activeSeason = ref.watch(activeSeasonProviderFor(slug));

    return seriesDetailAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (e, _) => _ErrorBody(message: e.toString()),
      data: (series) {
        if (series == null) {
          return const _ErrorBody(message: 'Detail series tidak ditemukan.');
        }

        // Ambil daftar episode dari season aktif
        final episodesAsync = ref.watch(
          episodesProvider((seriesId: series.id, season: activeSeason)),
        );

        final imageToShow = episode.stillUrl ?? series.backdropUrl;

        return CustomScrollView(
          slivers: [
            _BackdropAppBar(
              stillUrl: imageToShow,
              episodeNumber: episode.episodeNumber,
              seasonNumber: episode.seasonNumber,
              episodeId: episode.id,
              slug: slug,
              isPlaying: isPlaying,
              onPlay: onPlayPressed,
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.sm),
                    // Judul Episode
                    AppText(
                      episode.title ?? 'Episode ${episode.episodeNumber}',
                      variant: AppTextVariant.heading,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    // Meta info
                    _MetaRow(
                      seasonNumber: episode.seasonNumber,
                      episodeNumber: episode.episodeNumber,
                      airDate: episode.airDate,
                      runtime: episode.runtime,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // Sinopsis
                    const AppText('Sinopsis Episode', variant: AppTextVariant.title),
                    const SizedBox(height: AppSpacing.xs),
                    AppText(
                      (episode.overview != null && episode.overview!.isNotEmpty)
                          ? episode.overview!
                          : 'Tidak ada sinopsis untuk episode ini.',
                      variant: AppTextVariant.body,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ),

            // Season selector
            if ((series.numberOfSeasons ?? 0) > 1)
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(
                        left: AppSpacing.md,
                        bottom: AppSpacing.sm,
                      ),
                      child: AppText('Season', variant: AppTextVariant.title),
                    ),
                    SeasonSelector(
                      seasonCount: series.numberOfSeasons!,
                      activeSeason: activeSeason,
                      onSeasonSelected: (s) =>
                          ref.read(activeSeasonProviderFor(slug).notifier).set(s),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ),
              ),

            // Label episode
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(
                  left: AppSpacing.md,
                  bottom: AppSpacing.sm,
                ),
                child: AppText('Episode Lainnya', variant: AppTextVariant.title),
              ),
            ),

            // Daftar episode
            episodesAsync.when(
              loading: () => const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                ),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: Center(
                  child: AppText(e.toString(), color: AppColors.textMuted),
                ),
              ),
              data: (epList) => SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final ep = epList[index];
                  final isCurrentActive = ep.id == activeEpisodeId;

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    child: EpisodeTile(
                      episodeNumber: ep.episodeNumber,
                      title: ep.title ?? 'Episode ${ep.episodeNumber}',
                      stillUrl: ep.stillUrl,
                      airDate: ep.airDate,
                      isActive: isCurrentActive,
                      onTap: () => onEpisodeSelect(ep.id, ep),
                    ),
                  );
                }, childCount: epList.length),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
          ],
        );
      },
    );
  }
}

class _BackdropAppBar extends StatelessWidget {
  const _BackdropAppBar({
    this.stillUrl,
    required this.episodeNumber,
    required this.seasonNumber,
    required this.episodeId,
    required this.slug,
    required this.isPlaying,
    required this.onPlay,
  });

  final String? stillUrl;
  final int episodeNumber;
  final int seasonNumber;
  final String episodeId;
  final String slug;
  final bool isPlaying;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 230,
      pinned: true,
      backgroundColor: AppColors.background,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
        onPressed: () => context.pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (isPlaying)
              EmbeddedPlayer(
                key: ValueKey(episodeId),
                episodeId: episodeId,
                slug: slug,
              )
            else ...[
              if (stillUrl != null)
                CachedNetworkImage(imageUrl: stillUrl!, fit: BoxFit.cover)
              else
                Container(color: AppColors.surface),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, AppColors.background],
                    stops: [0.5, 1.0],
                  ),
                ),
              ),
              Center(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onPlay,
                    borderRadius: BorderRadius.circular(40),
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withValues(alpha: 0.9),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.5),
                            blurRadius: 15,
                            spreadRadius: 2,
                          )
                        ],
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class EmbeddedPlayer extends ConsumerStatefulWidget {
  const EmbeddedPlayer({
    super.key,
    // Untuk episode (default):
    this.episodeId,
    // Untuk movie:
    this.contentId,
    this.isMovie = false,
    required this.slug,
  }) : assert(
          episodeId != null || contentId != null,
          'Harus ada episodeId (series) atau contentId (movie)',
        );

  final String? episodeId;
  final String? contentId;   // movie ID
  final bool isMovie;
  final String slug;

  /// ID yang digunakan sebagai key provider (episodeId untuk series, contentId untuk movie)
  String get _providerId => isMovie ? contentId! : episodeId!;

  @override
  ConsumerState<EmbeddedPlayer> createState() => _EmbeddedPlayerState();
}

class _EmbeddedPlayerState extends ConsumerState<EmbeddedPlayer> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;

  @override
  void initState() {
    super.initState();
    // Mulai unlock stream tanpa mengunci orientasi ke landscape
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(streamProviderFor(widget._providerId).notifier)
          .unlock(slug: widget.slug, isMovie: widget.isMovie);
    });
  }

  @override
  void dispose() {
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
    );

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final streamState = ref.watch(streamProviderFor(widget._providerId));

    ref.listen(streamProviderFor(widget._providerId), (prev, next) {
      if (next.hasResult && _videoController == null) {
        _initPlayer(next.result!.url);
      }
    });

    if (_chewieController != null) {
      return Center(
        child: Chewie(controller: _chewieController!),
      );
    }

    if (streamState.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: AppText(
            streamState.error!,
            color: AppColors.textMuted,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return _EmbeddedCountdown(streamState: streamState);
  }
}

class _EmbeddedCountdown extends StatefulWidget {
  const _EmbeddedCountdown({required this.streamState});
  final StreamState streamState;

  @override
  State<_EmbeddedCountdown> createState() => _EmbeddedCountdownState();
}

class _EmbeddedCountdownState extends State<_EmbeddedCountdown>
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
        2 => 'Memproses izin akses... ($_seconds d)',
        3 => 'Mengambil stream...',
        _ => 'Mempersiapkan...',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, child) => Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surface,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(
                        alpha: 0.3 + _pulse.value * 0.4,
                      ),
                      blurRadius: 15 + _pulse.value * 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: AppColors.primary,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppText(
              _stepLabel,
              variant: AppTextVariant.caption,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: AppSpacing.xs),
            const SizedBox(
              width: 140,
              height: 3,
              child: LinearProgressIndicator(
                color: AppColors.primary,
                backgroundColor: AppColors.surface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.seasonNumber,
    required this.episodeNumber,
    this.airDate,
    this.runtime,
  });

  final int seasonNumber;
  final int episodeNumber;
  final String? airDate;
  final int? runtime;

  String _formatDuration(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}j' : '${h}j ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      'Season $seasonNumber',
      'Episode $episodeNumber',
      if (airDate != null && airDate!.isNotEmpty) airDate!,
      if (runtime != null) _formatDuration(runtime!),
    ];
    return AppText(
      parts.join('  ·  '),
      variant: AppTextVariant.caption,
      color: AppColors.textMuted,
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: AppColors.textMuted,
              size: 48,
            ),
            const SizedBox(height: AppSpacing.md),
            AppText(
              message,
              color: AppColors.textMuted,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextButton(
              onPressed: () => context.pop(),
              child: const Text(
                'Kembali',
                style: TextStyle(color: AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
