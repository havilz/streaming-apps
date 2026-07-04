import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:streaming_mobile/core/core.dart';
import 'package:streaming_mobile/features/home/data/movie_model.dart';
import 'package:streaming_mobile/features/home/domain/network_detail_provider.dart';
import 'package:streaming_mobile/features/home/presentation/home_screen.dart'; // import HeroSection
import 'package:streaming_mobile/features/home/presentation/menu_modal.dart';
import 'package:streaming_mobile/features/search/presentation/search_modal.dart';
import 'package:streaming_mobile/shared/shared.dart';

class NetworkDetailScreen extends ConsumerStatefulWidget {
  const NetworkDetailScreen({
    super.key,
    required this.networkId,
    required this.networkName,
  });

  final int networkId;
  final String networkName;

  @override
  ConsumerState<NetworkDetailScreen> createState() =>
      _NetworkDetailScreenState();
}

class _NetworkDetailScreenState extends ConsumerState<NetworkDetailScreen> {
  final _scrollController = ScrollController();
  bool _showGlassBackground = false;

  final _trendingKey = GlobalKey();

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
        context.push('/networks');
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

  @override
  Widget build(BuildContext context) {
    final networkAsync = ref.watch(networkDetailProvider(widget.networkName));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.surface,
            onRefresh: () =>
                ref.refresh(networkDetailProvider(widget.networkName).future),
            child: networkAsync.when(
              data: (networkState) {
                return CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    SliverToBoxAdapter(
                      child: HeroSection(
                        items: networkState.heroItems,
                        scrollController: _scrollController,
                      ),
                    ),

                    if (networkState.error != null &&
                        networkState.trendingItems.isEmpty)
                      SliverFillRemaining(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.xl),
                            child: Text(
                              networkState.error!,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),

                    // 1. Trending Now (series only, no interactive filter)
                    SliverToBoxAdapter(
                      child: Container(
                        key: _trendingKey,
                        child: _buildHorizontalLane(
                          title: 'Trending ${widget.networkName}',
                          items: networkState.trendingItems,
                        ),
                      ),
                    ),

                    // 2. Best in Genre
                    SliverToBoxAdapter(
                      child: Container(
                        child: _buildHorizontalLane(
                          title: '🏳️ Best in Genre',
                          items: networkState.bestGenreItems,
                        ),
                      ),
                    ),

                    // 3. Best in Country
                    SliverToBoxAdapter(
                      child: Container(
                        child: _buildHorizontalLane(
                          title: '🏳️ Best in Country',
                          items: networkState.bestCountryItems,
                        ),
                      ),
                    ),

                    const SliverToBoxAdapter(
                      child: SizedBox(height: AppSpacing.xl),
                    ),
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
                        _buildHorizontalShimmerLane(title: '🏳️ Best in Genre'),
                        _buildHorizontalShimmerLane(
                          title: '🏳️ Best in Country',
                        ),
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
