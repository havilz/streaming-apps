import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:streaming_mobile/core/core.dart';
import 'package:streaming_mobile/features/home/data/movie_model.dart';
import 'package:streaming_mobile/features/home/domain/year_detail_provider.dart';
import 'package:streaming_mobile/features/home/presentation/home_screen.dart'; // import HeroSection
import 'package:streaming_mobile/features/home/presentation/menu_modal.dart';
import 'package:streaming_mobile/features/search/presentation/search_modal.dart';
import 'package:streaming_mobile/shared/shared.dart';

class YearDetailScreen extends ConsumerStatefulWidget {
  const YearDetailScreen({
    super.key,
    required this.year,
  });

  final String year;

  @override
  ConsumerState<YearDetailScreen> createState() => _YearDetailScreenState();
}

class _YearDetailScreenState extends ConsumerState<YearDetailScreen> {
  final _scrollController = ScrollController();
  bool _showGlassBackground = false;
  String _trendingFilter = 'All';

  final _trendingKey = GlobalKey();
  final _netflixKey = GlobalKey();
  final _hboKey = GlobalKey();
  final _disneyKey = GlobalKey();
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
        context.push('/series');
        break;
      case 'genres':
        context.push('/genres');
        break;
      case 'network':
        _scrollToKey(_netflixKey);
        break;
      case 'country':
        context.push('/countries');
        break;
      case 'years':
        context.push('/years');
        break;
    }
  }

  @override
  void initState() {
    super.initState();
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

  Widget _buildTrendingFilterRow() {
    return _buildDynamicFilterRow(
      options: ['All', 'Movie', 'Series'],
      active: _trendingFilter,
      onTap: (v) => setState(() => _trendingFilter = v),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive ? Colors.white.withValues(alpha: 0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: isActive
                      ? Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1)
                      : null,
                ),
                child: Text(
                  tab,
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.white54,
                    fontSize: 11,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final yearAsync = ref.watch(yearDetailProvider(widget.year));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.surface,
            onRefresh: () => ref.refresh(yearDetailProvider(widget.year).future),
            child: yearAsync.when(
              data: (yearState) {
                final trendingFiltered = yearState.trendingItems.where((item) {
                  if (_trendingFilter == 'Movie') return !item.isSeries;
                  if (_trendingFilter == 'Series') return item.isSeries;
                  return true;
                }).toList();

                return CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    SliverToBoxAdapter(
                      child: HeroSection(
                        items: yearState.heroItems,
                        scrollController: _scrollController,
                      ),
                    ),

                    if (yearState.error != null && yearState.trendingItems.isEmpty)
                      SliverFillRemaining(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.xl),
                            child: Text(
                              yearState.error!,
                              style: const TextStyle(color: AppColors.textMuted),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),

                    // 1. Trending Now (All / Movie / Series filter)
                    SliverToBoxAdapter(
                      child: Container(
                        key: _trendingKey,
                        child: _buildHorizontalLane(
                          title: 'Trending ${widget.year}',
                          items: trendingFiltered,
                          trailingHeader: _buildTrendingFilterRow(),
                        ),
                      ),
                    ),

                    // 2. Network sections
                    // Netflix
                    SliverToBoxAdapter(
                      child: Container(
                        key: _netflixKey,
                        child: _buildHorizontalLane(
                          title: '🎬 Netflix',
                          items: yearState.netflixItems,
                        ),
                      ),
                    ),

                    // HBO
                    SliverToBoxAdapter(
                      child: Container(
                        key: _hboKey,
                        child: _buildHorizontalLane(
                          title: '📺 HBO',
                          items: yearState.hboItems,
                        ),
                      ),
                    ),

                    // Disney+
                    SliverToBoxAdapter(
                      child: Container(
                        key: _disneyKey,
                        child: _buildHorizontalLane(
                          title: '✨ Disney+',
                          items: yearState.disneyItems,
                        ),
                      ),
                    ),

                    // 3. Best in Country (max 15 items, combined)
                    SliverToBoxAdapter(
                      child: Container(
                        key: _countryKey,
                        child: _buildHorizontalLane(
                          title: '🏳️ Best in Country',
                          items: yearState.bestCountryItems,
                        ),
                      ),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
                  ],
                );
              },
              loading: () => CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverToBoxAdapter(
                    child: HeroSection(
                      items: const [],
                      scrollController: _scrollController,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHorizontalShimmerLane(title: 'Trending Now'),
                        _buildHorizontalShimmerLane(title: '🎬 Netflix'),
                        _buildHorizontalShimmerLane(title: '📺 HBO'),
                      ],
                    ),
                  ),
                ],
              ),
              error: (err, _) => CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverFillRemaining(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Text(
                          err.toString(),
                          style: const TextStyle(color: AppColors.textMuted),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
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
                    filter: ImageFilter.blur(sigmaX: blurValue, sigmaY: blurValue),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
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
                    year: item.year,
                    voteAverage: item.voteAverage,
                    numberOfSeasons: item.numberOfSeasons,
                    onTap: () {
                      context.push(
                        '/detail/${item.slug}',
                        extra: {'isSeries': item.isSeries},
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
