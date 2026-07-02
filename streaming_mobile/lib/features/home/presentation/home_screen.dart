import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:streaming_mobile/core/core.dart';
import 'package:streaming_mobile/features/home/data/movie_model.dart';
import 'package:streaming_mobile/features/home/domain/home_provider.dart';
import 'package:streaming_mobile/shared/shared.dart';

/// Halaman utama — grid konten film & series dengan filter dan infinite scroll.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(homeProvider.notifier).reload();
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      ref.read(homeProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final homeState = ref.watch(homeProvider);
    final filter = ref.watch(homeFilterProvider);
    final genres = ref.watch(availableGenresProvider);
    final years = ref.watch(availableYearsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          onRefresh: () => ref.read(homeProvider.notifier).reload(),
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverAppBar(
                floating: true,
                snap: true,
                backgroundColor: AppColors.background,
                title: const Text('StreamVault', style: AppTypography.logo),
                titleTextStyle: AppTypography.logo.copyWith(
                  color: AppColors.primary,
                ),
                actions: [
                  IconButton(
                    icon: const Icon(
                      Icons.search,
                      color: AppColors.textPrimary,
                    ),
                    onPressed: () => context.go('/search'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: AppColors.textMuted),
                    tooltip: 'Refresh konten',
                    onPressed: () => ref.read(homeProvider.notifier).reload(),
                  ),
                ],
              ),

              SliverToBoxAdapter(
                child: _ContentTypeTabs(
                  selected: filter.contentType,
                  onSelected: (type) => ref
                      .read(homeFilterProvider.notifier)
                      .setContentType(type),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: FilterBar(
                    genres: genres.when(
                      data: (v) => v,
                      error: (_, __) => [],
                      loading: () => [],
                    ),
                    years: years.when(
                      data: (v) => v,
                      error: (_, __) => [],
                      loading: () => [],
                    ),
                    selectedGenre: filter.genre,
                    selectedYear: filter.year,
                    onGenreChanged: (v) =>
                        ref.read(homeFilterProvider.notifier).setGenre(v),
                    onYearChanged: (v) =>
                        ref.read(homeFilterProvider.notifier).setYear(v),
                  ),
                ),
              ),

              if (homeState.error != null && homeState.movies.isEmpty)
                SliverFillRemaining(
                  child: _ErrorView(
                    message: homeState.error!,
                    onRetry: () => ref.read(homeProvider.notifier).reload(),
                  ),
                ),

              if (!homeState.isLoading || homeState.movies.isNotEmpty)
                _ContentGridSliver(
                  movies: homeState.movies,
                  isLoading: homeState.isLoading,
                  onItemTap: (slug) => context.push('/detail/$slug'),
                ),

              if (homeState.isLoadingMore)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContentTypeTabs extends StatelessWidget {
  const _ContentTypeTabs({required this.selected, required this.onSelected});

  final String? selected;
  final void Function(String?) onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          _Tab(
            label: 'Semua',
            value: null,
            selected: selected,
            onTap: onSelected,
          ),
          const SizedBox(width: AppSpacing.sm),
          _Tab(
            label: 'Film',
            value: 'movie',
            selected: selected,
            onTap: onSelected,
          ),
          const SizedBox(width: AppSpacing.sm),
          _Tab(
            label: 'Series',
            value: 'series',
            selected: selected,
            onTap: onSelected,
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String? value;
  final String? selected;
  final void Function(String?) onTap;

  bool get _isActive => selected == value;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppDuration.normal,
      child: InkWell(
        onTap: () => onTap(value),
        borderRadius: AppRadius.fullAll,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: _isActive ? AppColors.primary : AppColors.surface,
            borderRadius: AppRadius.fullAll,
            border: Border.all(
              color: _isActive ? AppColors.primary : AppColors.borderSubtle,
            ),
          ),
          child: Text(
            label,
            style: AppTypography.caption.copyWith(
              color: _isActive ? AppColors.textPrimary : AppColors.textMuted,
              fontWeight: _isActive ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

class _ContentGridSliver extends StatelessWidget {
  const _ContentGridSliver({
    required this.movies,
    required this.isLoading,
    required this.onItemTap,
  });

  final List<MovieModel> movies;
  final bool isLoading;
  final void Function(String slug) onItemTap;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = width >= 600 ? 3 : 2;

    if (isLoading) {
      return SliverPadding(
        padding: const EdgeInsets.all(AppSpacing.md),
        sliver: SliverGrid(
          delegate: SliverChildBuilderDelegate(
            (_, __) => const AppShimmer(
              width: double.infinity,
              height: double.infinity,
            ),
            childCount: 10,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 2 / 3,
          ),
        ),
      );
    }

    if (movies.isEmpty) {
      return const SliverFillRemaining(
        child: Center(
          child: AppText(
            'Tidak ada konten ditemukan.',
            variant: AppTextVariant.body,
            color: AppColors.textMuted,
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(AppSpacing.md),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate((context, index) {
          final movie = movies[index];
          return MovieCard(
            title: movie.title,
            posterUrl: movie.posterPath ?? '',
            year: movie.year,
            onTap: () => onItemTap(movie.slug),
          );
        }, childCount: movies.length),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          childAspectRatio: 2 / 3,
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              color: AppColors.textMuted,
              size: 48,
            ),
            const SizedBox(height: AppSpacing.md),
            AppText(
              message,
              variant: AppTextVariant.caption,
              color: AppColors.textMuted,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextButton(
              onPressed: onRetry,
              child: const Text(
                'Coba Lagi',
                style: TextStyle(color: AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
