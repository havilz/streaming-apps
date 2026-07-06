import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:streaming_mobile/core/core.dart';
import 'package:streaming_mobile/features/home/data/movie_model.dart';
import 'package:streaming_mobile/features/home/domain/series_screen_provider.dart';
import 'package:streaming_mobile/features/home/presentation/home_screen.dart'; // import HeroSection
import 'package:streaming_mobile/features/home/presentation/menu_modal.dart';
import 'package:streaming_mobile/features/search/presentation/search_modal.dart';
import 'package:streaming_mobile/shared/shared.dart';

class SeriesScreen extends ConsumerStatefulWidget {
  const SeriesScreen({super.key});

  @override
  ConsumerState<SeriesScreen> createState() => _SeriesScreenState();
}

class _SeriesScreenState extends ConsumerState<SeriesScreen> {
  final _scrollController = ScrollController();
  bool _showGlassBackground = false;
  String _newUpdatedFilter = 'All';

  final _trendingKey = GlobalKey();
  final _genreKey = GlobalKey();
  final _countryKey = GlobalKey();

  void _scrollToKey(GlobalKey key) {
    final context = key.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  void _handleMenuSelection(String item) {
    switch (item) {
      case 'home':
        context.go('/');
        break;
      case 'movie':
        context.push('/movies');
        break;
      case 'series':
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
        break;
      case 'genres':
        _scrollToKey(_genreKey);
        break;
      case 'network':
        context.go('/');
        break;
      case 'country':
        _scrollToKey(_countryKey);
        break;
      case 'years':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fitur filter Tahun akan segera hadir!'),
            duration: Duration(seconds: 2),
          ),
        );
        break;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(seriesScreenProvider.notifier).reload();
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final showGlass = _scrollController.offset > 50;
    if (showGlass != _showGlassBackground) {
      setState(() {
        _showGlassBackground = showGlass;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final seriesState = ref.watch(seriesScreenProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.surface,
            onRefresh: () => ref.read(seriesScreenProvider.notifier).reload(),
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverToBoxAdapter(
                  child: HeroSection(
                    items: seriesState.heroItems,
                    scrollController: _scrollController,
                  ),
                ),

                if (seriesState.error != null &&
                    seriesState.trendingItems.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Text(
                          seriesState.error!,
                          style: const TextStyle(color: AppColors.textMuted),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),

                if (seriesState.isLoading)
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHorizontalShimmerLane(title: 'Trending Now'),
                        _buildHorizontalShimmerLane(title: 'Action'),
                        _buildHorizontalShimmerLane(title: 'Drama'),
                      ],
                    ),
                  )
                else ...[
                  // 1. New Updated Series/Episodes section
                  SliverToBoxAdapter(
                    child: Builder(
                      builder: (context) {
                        final filteredItems = seriesState.newUpdatedItems.where((item) {
                          if (_newUpdatedFilter == 'Series') return item.isSeries;
                          return true;
                        }).toList();

                        return _buildHorizontalUpdatedLane(
                          title: 'New Updated',
                          items: filteredItems,
                          trailingHeader: _buildDynamicFilterRow(
                            options: ['All', 'Series'],
                            active: _newUpdatedFilter,
                            onTap: (v) => setState(() => _newUpdatedFilter = v),
                          ),
                        );
                      },
                    ),
                  ),

                  // 2. Trending Now (series only, no interactive filters)
                  SliverToBoxAdapter(
                    child: Container(
                      key: _trendingKey,
                      child: _buildHorizontalLane(
                        title: 'Trending Now',
                        items: seriesState.trendingItems,
                      ),
                    ),
                  ),

                  // 3. Best in Genre (series only, no interactive filters)
                  SliverToBoxAdapter(
                    child: Container(
                      key: _genreKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: seriesState.genreItems.entries.map((entry) {
                          return _buildHorizontalLane(
                            title: entry.key,
                            items: entry.value,
                          );
                        }).toList(),
                      ),
                    ),
                  ),

                  // 4. Best in Country (series only, no interactive filters)
                  SliverToBoxAdapter(
                    child: Container(
                      key: _countryKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: seriesState.countryItems.entries.map((entry) {
                          return _buildHorizontalLane(
                            title: 'Best in ${entry.key}',
                            items: entry.value,
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],

                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.xl),
                ),
              ],
            ),
          ),

          // Pinned Floating Glassmorphic App Bar (SV Logo + Search + Menu)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 12,
            left: 16,
            right: 16,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(
                begin: 0.0,
                end: _showGlassBackground ? 12.0 : 0.0,
              ),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              builder: (context, blurValue, child) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: blurValue,
                      sigmaY: blurValue,
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _showGlassBackground
                            ? Colors.black.withValues(alpha: 0.55)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: _showGlassBackground
                            ? Border.all(
                                color: Colors.white.withValues(alpha: 0.08),
                                width: 1,
                              )
                            : null,
                      ),
                      child: child,
                    ),
                  ),
                );
              },
              child: Row(
                children: [
                  Text(
                    'SV',
                    style: AppTypography.logo.copyWith(
                      color: AppColors.primary,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                    icon: const Icon(
                      Icons.search,
                      color: AppColors.textPrimary,
                      size: 20,
                    ),
                    onPressed: () => showSearchModal(context),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  IconButton(
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                    icon: const Icon(
                      Icons.menu_rounded,
                      color: AppColors.textPrimary,
                      size: 22,
                    ),
                    onPressed: () => showMenuModal(
                      context,
                      onItemSelected: _handleMenuSelection,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalLane({
    required String title,
    required List<ContentItem> items,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: SizedBox(
                  width: 120,
                  child: MovieCard(
                    title: item.title,
                    posterUrl: item.posterUrl ?? '',
                    year: item.year,
                    voteAverage: item.voteAverage,
                    numberOfSeasons: item.numberOfSeasons,
                    onTap: () {
                      context.push(
                        '/detail/${item.slug}',
                        extra: {
                          'isSeries': item.isSeries,
                          'initialSeason': item.isSeries
                              ? item.numberOfSeasons
                              : null,
                        },
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHorizontalUpdatedLane({
    required String title,
    required List<UpdatedItem> items,
    Widget? trailingHeader,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (trailingHeader != null) trailingHeader,
            ],
          ),
        ),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: SizedBox(
                  width: 120,
                  child: MovieCard(
                    title: item.title,
                    posterUrl: item.posterUrl ?? '',
                    voteAverage: item.voteAverage,
                    customBadge: item.subtitle,
                    onTap: () {
                      if (item.isEpisode) {
                        context.push(
                          '/episode/${item.id}',
                          extra: {
                            'slug': item.slug,
                          },
                        );
                      } else {
                        context.push(
                          '/detail/${item.slug}',
                          extra: {
                            'isSeries': item.isSeries,
                            'initialSeason': item.isSeries ? item.seasonNumber : null,
                          },
                        );
                      }
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDynamicFilterRow({
    required List<String> options,
    required String active,
    required void Function(String) onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: options.map((tab) {
            final isActive = active == tab;
            return GestureDetector(
              onTap: () => onTap(tab),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.white.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: isActive
                      ? Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                          width: 1,
                        )
                      : null,
                ),
                child: Text(
                  tab,
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildHorizontalShimmerLane({required String title}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 4,
            itemBuilder: (context, index) {
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: SizedBox(
                  width: 120,
                  child: AspectRatio(
                    aspectRatio: 2 / 3,
                    child: AppShimmer(
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
