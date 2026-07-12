import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:streaming_mobile/core/core.dart';
import 'package:streaming_mobile/features/detail/domain/detail_provider.dart';
import 'package:streaming_mobile/features/detail/presentation/episode_detail_screen.dart'
    show EmbeddedPlayer;
import 'package:streaming_mobile/features/home/data/movie_model.dart';
import 'package:streaming_mobile/shared/shared.dart';

class DetailScreen extends ConsumerWidget {
  const DetailScreen({
    super.key,
    required this.slug,
    required this.isSeries,
    this.initialSeason,
  });

  final String slug;
  final bool isSeries;
  final int? initialSeason;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isSeries) {
      final detail = ref.watch(seriesDetailProvider(slug));
      return Scaffold(
        backgroundColor: AppColors.background,
        body: detail.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (e, _) => _ErrorBody(message: e.toString()),
          data: (series) {
            if (series == null)
              return const _ErrorBody(message: 'Series tidak ditemukan.');
            return _SeriesBody(
              series: series,
              slug: slug,
              initialSeason: initialSeason,
            );
          },
        ),
      );
    } else {
      final detail = ref.watch(movieDetailProvider(slug));
      return Scaffold(
        backgroundColor: AppColors.background,
        body: detail.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (e, _) => _ErrorBody(message: e.toString()),
          data: (movie) {
            if (movie == null)
              return const _ErrorBody(message: 'Film tidak ditemukan.');
            return _MovieBody(movie: movie, slug: slug);
          },
        ),
      );
    }
  }
}

// ── Movie Body ────────────────────────────────────────────────

class _MovieBody extends ConsumerStatefulWidget {
  const _MovieBody({required this.movie, required this.slug});
  final MovieModel movie;
  final String slug;

  @override
  ConsumerState<_MovieBody> createState() => _MovieBodyState();
}

class _MovieBodyState extends ConsumerState<_MovieBody> {
  bool _isPlaying = false;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        try {
          await ClientSyncService.syncGlobal(force: true);
          if (mounted) {
            ref.invalidate(movieDetailProvider(widget.slug));
          }
        } catch (_) {}
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          _BackdropAppBar(
            backdropUrl: widget.movie.backdropUrl,
            isPlaying: _isPlaying,
            movieId: widget.movie.id,
            slug: widget.slug,
            onPlay: () => setState(() => _isPlaying = true),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(widget.movie.title, variant: AppTextVariant.heading),
                  const SizedBox(height: AppSpacing.xs),
                  _MetaRow(
                    year: widget.movie.year,
                    runtime: widget.movie.runtime,
                    voteAverage: widget.movie.voteAverage,
                    quality: widget.movie.quality,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (widget.movie.genres.isNotEmpty)
                    _GenreBadges(genres: widget.movie.genres),
                  const SizedBox(height: AppSpacing.md),
                  if (widget.movie.overview != null &&
                      widget.movie.overview!.isNotEmpty) ...[
                    const AppText('Sinopsis', variant: AppTextVariant.title),
                    const SizedBox(height: AppSpacing.xs),
                    AppText(
                      widget.movie.overview!,
                      variant: AppTextVariant.body,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
        ],
      ),
    );
  }
}

// ── Series Body ───────────────────────────────────────────────

class _SeriesBody extends ConsumerStatefulWidget {
  const _SeriesBody({
    required this.series,
    required this.slug,
    this.initialSeason,
  });

  final SeriesModel series;
  final String slug;
  final int? initialSeason;

  @override
  ConsumerState<_SeriesBody> createState() => _SeriesBodyState();
}

class _SeriesBodyState extends ConsumerState<_SeriesBody> {
  bool _hasSynced = false;

  @override
  void initState() {
    super.initState();
    final initialSeason = widget.initialSeason;
    if (initialSeason != null && initialSeason > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final activeSeasonProvider = activeSeasonProviderFor(widget.slug);
        final currentActive = ref.read(activeSeasonProvider);
        if (currentActive != initialSeason) {
          ref.read(activeSeasonProvider.notifier).set(initialSeason);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeSeason = ref.watch(activeSeasonProviderFor(widget.slug));

    if (!_hasSynced) {
      _hasSynced = true;
      // Trigger sync for this series immediately when the detail page is opened
      ClientSyncService.syncSeriesEpisodes(widget.series.id, widget.series.slug).then((_) {
        if (mounted) {
          ref.invalidate(episodesProvider((seriesId: widget.series.id, season: activeSeason)));
          // Also invalidate series detail in case number of seasons or other metadata was updated
          ref.invalidate(seriesDetailProvider(widget.slug));
        }
      }).catchError((_) {});
    }

    final episodes = ref.watch(
      episodesProvider((seriesId: widget.series.id, season: activeSeason)),
    );

    return RefreshIndicator(
      onRefresh: () async {
        try {
          await ClientSyncService.syncSeriesEpisodes(
            widget.series.id,
            widget.series.slug,
            force: true,
          );
          if (mounted) {
            ref.invalidate(episodesProvider((seriesId: widget.series.id, season: activeSeason)));
            ref.invalidate(seriesDetailProvider(widget.slug));
          }
        } catch (_) {}
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
        _BackdropAppBar(backdropUrl: widget.series.backdropUrl),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(widget.series.title, variant: AppTextVariant.heading),
                const SizedBox(height: AppSpacing.xs),
                _MetaRow(
                  year: widget.series.year,
                  voteAverage: widget.series.voteAverage,
                  quality: widget.series.quality,
                  extra: widget.series.status,
                ),
                const SizedBox(height: AppSpacing.sm),
                if (widget.series.genres.isNotEmpty)
                  _GenreBadges(genres: widget.series.genres),
                const SizedBox(height: AppSpacing.md),

                if (widget.series.overview != null &&
                    widget.series.overview!.isNotEmpty) ...[
                  const AppText('Sinopsis', variant: AppTextVariant.title),
                  const SizedBox(height: AppSpacing.xs),
                  AppText(
                    widget.series.overview!,
                    variant: AppTextVariant.body,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ],
            ),
          ),
        ),

        // Season selector
        if ((widget.series.numberOfSeasons ?? 0) > 1)
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
                  seasonCount: widget.series.numberOfSeasons!,
                  activeSeason: activeSeason,
                  onSeasonSelected: (s) => ref
                      .read(activeSeasonProviderFor(widget.slug).notifier)
                      .set(s),
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
            child: AppText('Episode', variant: AppTextVariant.title),
          ),
        ),

        // Daftar episode
        episodes.when(
          loading: () => const SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
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
                  onTap: () => context.push(
                    '/episode/${ep.id}',
                    extra: {'slug': widget.slug, 'episode': ep},
                  ),
                ),
              );
            }, childCount: epList.length),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
      ],
    ),
  );
}
}

// ── Shared widgets ────────────────────────────────────────────

class _BackdropAppBar extends StatelessWidget {
  const _BackdropAppBar({
    this.backdropUrl,
    this.isPlaying = false,
    this.movieId,
    this.slug,
    this.onPlay,
  });

  final String? backdropUrl;
  final bool isPlaying;
  final String? movieId;
  final String? slug;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 260,
      pinned: true,
      backgroundColor: AppColors.background,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
        onPressed: () => context.pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: isPlaying && movieId != null && slug != null
            // ── Mode Putar: ganti backdrop dengan embedded player ──
            ? EmbeddedPlayer(
                contentId: movieId!,
                slug: slug!,
                isMovie: true,
              )
            // ── Mode Normal: tampilkan backdrop + tombol play overlay ──
            : Stack(
                fit: StackFit.expand,
                children: [
                  if (backdropUrl != null)
                    CachedNetworkImage(
                      imageUrl: backdropUrl!,
                      fit: BoxFit.cover,
                    )
                  else
                    Container(color: AppColors.surface),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, AppColors.background],
                        stops: [0.4, 1.0],
                      ),
                    ),
                  ),
                  // Tombol play di tengah backdrop
                  if (onPlay != null)
                    Center(
                      child: GestureDetector(
                        onTap: onPlay,
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.9),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.5),
                                blurRadius: 20,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
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
    this.year,
    this.runtime,
    this.voteAverage,
    this.quality,
    this.extra,
  });
  final String? year;
  final int? runtime;
  final double? voteAverage;
  final String? quality;
  final String? extra;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (year != null && year!.isNotEmpty) year!,
      if (runtime != null) formatDuration(runtime),
      if (voteAverage != null) '⭐ ${voteAverage!.toStringAsFixed(1)}',
      if (quality != null) quality!,
      if (extra != null) extra!,
    ];
    return AppText(
      parts.join('  ·  '),
      variant: AppTextVariant.caption,
      color: AppColors.textMuted,
    );
  }
}

class _GenreBadges extends StatelessWidget {
  const _GenreBadges({required this.genres});
  final List<String> genres;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: genres.map((g) => AppBadge(g)).toList(),
    );
  }
}

// _PlayButton retained for potential future use in series body
class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        ),
        icon: const Icon(Icons.play_arrow_rounded),
        label: const Text('Putar'),
        onPressed: onTap,
      ),
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
