import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:streaming_mobile/core/core.dart';
import 'package:streaming_mobile/features/home/data/movie_model.dart';
import 'package:streaming_mobile/features/home/domain/domain.dart';
import 'package:streaming_mobile/shared/shared.dart';

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
      final state = ref.read(homeProvider);
      if (!state.isLoadingMore && state.hasMore && !state.isLoading) {
        ref.read(homeProvider.notifier).loadMore();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final homeState = ref.watch(homeProvider);
    final filter = ref.watch(homeFilterProvider);
    final genres = ref.watch(availableGenresProvider);
    final years = ref.watch(availableYearsProvider);

    ref.listen<SyncState>(syncProvider, (previous, next) {
      if (next.status == SyncStatus.loading) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mensinkronkan konten baru dari server...'),
            duration: Duration(seconds: 30),
          ),
        );
      } else if (next.status == SyncStatus.success) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sinkronisasi selesai! ${next.message}'),
            backgroundColor: Colors.green,
          ),
        );
        ref.read(homeProvider.notifier).reload();
      } else if (next.status == SyncStatus.error) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal sinkronisasi: ${next.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          onRefresh: () => ref.read(syncProvider.notifier).sync(),
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
                    onPressed: () => ref.read(syncProvider.notifier).sync(),
                  ),
                ],
              ),

              // Tab: Semua / Film / Series
              SliverToBoxAdapter(
                child: _ContentTypeTabs(
                  selected: filter.tab,
                  onSelected: (tab) =>
                      ref.read(homeFilterProvider.notifier).setTab(tab),
                ),
              ),

              // Filter bar genre & tahun
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: FilterBar(
                    genres: genres.when(
                      data: (v) => v.map((g) => g.name).toList(),
                      error: (_, __) => [],
                      loading: () => [],
                    ),
                    years: years.when(
                      data: (v) => v,
                      error: (_, __) => [],
                      loading: () => [],
                    ),
                    selectedGenre: genres.when(
                      data: (v) => filter.genreId != null
                          ? v
                                .where((g) => g.id == filter.genreId)
                                .firstOrNull
                                ?.name
                          : null,
                      error: (_, __) => null,
                      loading: () => null,
                    ),
                    selectedYear: filter.year,
                    onGenreChanged: (name) {
                      if (name == null) {
                        ref.read(homeFilterProvider.notifier).setGenre(null);
                      } else {
                        final id = genres.value
                            ?.where((g) => g.name == name)
                            .firstOrNull
                            ?.id;
                        ref.read(homeFilterProvider.notifier).setGenre(id);
                      }
                    },
                    onYearChanged: (v) =>
                        ref.read(homeFilterProvider.notifier).setYear(v),
                  ),
                ),
              ),

              if (homeState.error != null && homeState.items.isEmpty)
                SliverFillRemaining(
                  child: _ErrorView(
                    message: homeState.error!,
                    onRetry: () => ref.read(homeProvider.notifier).reload(),
                  ),
                ),

              if (!homeState.isLoading || homeState.items.isNotEmpty)
                _ContentGridSliver(
                  items: homeState.items,
                  isLoading: homeState.isLoading,
                  onItemTap: (item) => context.push(
                    '/detail/${item.slug}',
                    extra: {'isSeries': item.isSeries},
                  ),
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

// ── Tab Semua / Film / Series ─────────────────────────────────

class _ContentTypeTabs extends StatelessWidget {
  const _ContentTypeTabs({required this.selected, required this.onSelected});

  final ContentTab selected;
  final void Function(ContentTab) onSelected;

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
            value: ContentTab.all,
            selected: selected,
            onTap: onSelected,
          ),
          const SizedBox(width: AppSpacing.sm),
          _Tab(
            label: 'Film',
            value: ContentTab.movies,
            selected: selected,
            onTap: onSelected,
          ),
          const SizedBox(width: AppSpacing.sm),
          _Tab(
            label: 'Series',
            value: ContentTab.series,
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
  final ContentTab value;
  final ContentTab selected;
  final void Function(ContentTab) onTap;

  bool get _isActive => selected == value;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onTap(value),
      borderRadius: AppRadius.fullAll,
      child: AnimatedContainer(
        duration: AppDuration.normal,
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
    );
  }
}

// ── Grid konten ───────────────────────────────────────────────

class _ContentGridSliver extends StatelessWidget {
  const _ContentGridSliver({
    required this.items,
    required this.isLoading,
    required this.onItemTap,
  });

  final List<ContentItem> items;
  final bool isLoading;
  final void Function(ContentItem item) onItemTap;

  @override
  Widget build(BuildContext context) {
    final crossAxisCount = MediaQuery.sizeOf(context).width >= 600 ? 3 : 2;

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

    if (items.isEmpty) {
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
          final item = items[index];
          return MovieCard(
            title: item.title,
            posterUrl: item.posterUrl ?? '',
            year: item.year,
            onTap: () => onItemTap(item),
          );
        }, childCount: items.length),
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

// ── Error view ────────────────────────────────────────────────

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
