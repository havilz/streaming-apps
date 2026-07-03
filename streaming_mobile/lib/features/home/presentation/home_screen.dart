import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
  bool _showGlassBackground = false;
  String _trendingFilter = 'All';
  String _genreFilter = 'All';

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
    final showGlass = _scrollController.offset > 50;
    if (showGlass != _showGlassBackground) {
      setState(() {
        _showGlassBackground = showGlass;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final homeState = ref.watch(homeProvider);

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

    final trendingFiltered = homeState.trendingItems.where((item) {
      if (_trendingFilter == 'Movie') return !item.isSeries;
      if (_trendingFilter == 'Series') return item.isSeries;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.surface,
            onRefresh: () => ref.read(syncProvider.notifier).sync(),
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverToBoxAdapter(
                  child: _HeroSection(
                    items: homeState.heroItems,
                    scrollController: _scrollController,
                  ),
                ),

                if (homeState.error != null && homeState.trendingItems.isEmpty)
                  SliverFillRemaining(
                    child: _ErrorView(
                      message: homeState.error!,
                      onRetry: () => ref.read(homeProvider.notifier).reload(),
                    ),
                  ),

                if (homeState.isLoading)
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
                  // 1. Trending Now
                  SliverToBoxAdapter(
                    child: _buildHorizontalLane(
                      title: 'Trending Now',
                      items: trendingFiltered,
                      trailingHeader: _buildTrendingFilterRow(),
                    ),
                  ),

                  // 2. Best in Genre — All / Movie / Series filter
                  SliverToBoxAdapter(
                    child: Builder(builder: (context) {
                      final genreItems = _genreFilter == 'All'
                          ? homeState.trendingItems
                          : homeState.trendingItems
                              .where((i) => _genreFilter == 'Movie'
                                  ? !i.isSeries
                                  : i.isSeries)
                              .toList();
                      return _buildHorizontalLane(
                        title: 'Best in Genre',
                        items: genreItems,
                        trailingHeader: _buildDynamicFilterRow(
                          options: ['All', 'Movie', 'Series'],
                          active: _genreFilter,
                          onTap: (v) => setState(() => _genreFilter = v),
                        ),
                      );
                    }),
                  ),

                  // 3. Netflix section
                  SliverToBoxAdapter(
                    child: _buildHorizontalLane(
                      title: '🎬 Netflix',
                      items: homeState.networkItems['Netflix'] ?? [],
                      showWhenEmpty: true,
                    ),
                  ),

                  // 4. HBO section
                  SliverToBoxAdapter(
                    child: _buildHorizontalLane(
                      title: '📺 HBO',
                      items: homeState.networkItems['HBO'] ?? [],
                      showWhenEmpty: true,
                    ),
                  ),

                  // 5. Disney+ section
                  SliverToBoxAdapter(
                    child: _buildHorizontalLane(
                      title: '✨ Disney+',
                      items: homeState.networkItems['Disney+'] ?? [],
                      showWhenEmpty: true,
                    ),
                  ),
                ],

                const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
              ],
            ),
          ),

          // Pinned Floating Glassmorphic App Bar (SV Logo + Search)
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
                        color: Colors.black.withValues(alpha: _showGlassBackground ? 0.5 : 0.0),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: _showGlassBackground ? 0.1 : 0.0),
                          width: 1,
                        ),
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
                    onPressed: () => context.go('/search'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }



// ── Grid konten ───────────────────────────────────────────────

  Widget _buildHorizontalLane({
    required String title,
    required List<ContentItem> items,
    Widget? trailingHeader,
    bool showWhenEmpty = false,
  }) {
    if (items.isEmpty && !showWhenEmpty) return const SizedBox.shrink();
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
        if (items.isEmpty)
          const SizedBox(
            height: 80,
            child: Center(
              child: Text(
                'Belum ada konten tersedia',
                style: TextStyle(color: Colors.white38, fontSize: 13),
              ),
            ),
          )
        else
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

// ── Hero Section ──────────────────────────────────────────────

class _HeroSection extends StatefulWidget {
  const _HeroSection({
    required this.items,
    required this.scrollController,
  });

  final List<ContentItem> items;
  final ScrollController scrollController;

  @override
  State<_HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends State<_HeroSection>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _animationController;
  int _currentPage = 0;
  int _initialPage = 1000;

  @override
  void initState() {
    super.initState();
    final count = _getCount(widget.items);
    _initialPage = count > 0 ? (1000 ~/ count) * count : 1000;
    _pageController = PageController(initialPage: _initialPage);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );

    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _goToNextPage();
      }
    });

    _animationController.forward();
  }

  @override
  void didUpdateWidget(covariant _HeroSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldCount = _getCount(oldWidget.items);
    final newCount = _getCount(widget.items);
    if (oldCount == 0 && newCount > 0) {
      _pageController.dispose();
      _initialPage = (1000 ~/ newCount) * newCount;
      _pageController = PageController(initialPage: _initialPage);
      setState(() {
        _currentPage = 0;
      });
      _animationController.reset();
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  int _getCount(List<ContentItem> items) {
    final featuredItems = items
        .where((item) => item.backdropUrl != null && item.backdropUrl!.isNotEmpty)
        .take(10)
        .toList();
    return featuredItems.isNotEmpty ? featuredItems.length : items.take(10).length;
  }

  void _goToNextPage() {
    if (!mounted) return;
    final count = _getCount(widget.items);
    if (count <= 1) return;

    final currentVirtualPage = _pageController.hasClients
        ? (_pageController.page?.round() ?? _initialPage)
        : _initialPage;

    _pageController.animateToPage(
      currentVirtualPage + 1,
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final featuredItems = widget.items
        .where((item) => item.backdropUrl != null && item.backdropUrl!.isNotEmpty)
        .take(10)
        .toList();

    final displayItems = featuredItems.isNotEmpty
        ? featuredItems
        : widget.items.take(10).toList();

    if (displayItems.isEmpty) {
      return const AppShimmer(
        width: double.infinity,
        height: 380,
      );
    }

    return AnimatedBuilder(
      animation: widget.scrollController,
      builder: (context, child) {
        final offset = widget.scrollController.hasClients ? widget.scrollController.offset : 0.0;
        final progress = (offset / 380).clamp(0.0, 1.0);
        final parallaxOffset = offset * 0.45;
        final scale = 1.0 - (progress * 0.06);
        final opacity = 1.0 - progress;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 380,
              clipBehavior: Clip.antiAlias,
              decoration: const BoxDecoration(
                color: AppColors.background,
              ),
              child: Transform.scale(
                scale: scale,
                child: Transform.translate(
                  offset: Offset(0, parallaxOffset),
                  child: Opacity(
                    opacity: opacity.clamp(0.0, 1.0),
                    child: child,
                  ),
                ),
              ),
            ),

            // 5. Indikator Slide Bullets di luar/di bawah container gambar
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: List.generate(displayItems.length, (i) {
                  final isActive = i == _currentPage;
                  if (isActive) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Container(
                        width: 24,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: AnimatedBuilder(
                          animation: _animationController,
                          builder: (context, child) {
                            return Align(
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: _animationController.value,
                                child: Container(
                                  color: AppColors.primary,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  } else {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Container(
                        width: 6,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }
                }),
              ),
            ),
          ],
        );
      },
      child: SizedBox(
        height: 380,
        child: PageView.builder(
          controller: _pageController,
          onPageChanged: (index) {
            setState(() {
              _currentPage = index % displayItems.length;
            });
            _animationController.reset();
            _animationController.forward();
          },
          itemBuilder: (context, index) {
            final featuredItem = displayItems[index % displayItems.length];
            final imageUrl = featuredItem.backdropUrl ?? featuredItem.posterUrl ?? '';
            final hasBackdrop = featuredItem.backdropUrl != null && featuredItem.backdropUrl!.isNotEmpty;

            return Stack(
              fit: StackFit.expand,
              children: [
                imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: hasBackdrop ? BoxFit.cover : BoxFit.contain,
                        alignment: hasBackdrop ? Alignment.topCenter : Alignment.center,
                        placeholder: (_, __) => const AppShimmer(
                          width: double.infinity,
                          height: double.infinity,
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: AppColors.surface,
                          child: const Icon(
                            Icons.image_not_supported_outlined,
                            color: AppColors.textMuted,
                            size: 48,
                          ),
                        ),
                      )
                    : Container(color: AppColors.surface),

                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.background.withValues(alpha: 0.0),
                          AppColors.background.withValues(alpha: 0.3),
                          AppColors.background.withValues(alpha: 0.8),
                          AppColors.background.withValues(alpha: 1.0),
                        ],
                        stops: const [0.0, 0.5, 0.85, 1.0],
                      ),
                    ),
                  ),
                ),

                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.6),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          featuredItem.isSeries ? 'SERIES' : 'FILM',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        featuredItem.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: Colors.black54,
                              offset: Offset(0, 2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          if (featuredItem.voteAverage != null) ...[
                            const Icon(
                              Icons.star_rounded,
                              color: Colors.amber,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              featuredItem.voteAverage!.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              '•',
                              style: TextStyle(color: Colors.white38, fontSize: 12),
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (featuredItem.year != null && featuredItem.year!.isNotEmpty) ...[
                            Text(
                              featuredItem.year!,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (featuredItem.quality != null && featuredItem.quality!.isNotEmpty) ...[
                            const Text(
                              '•',
                              style: TextStyle(color: Colors.white38, fontSize: 12),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.white54, width: 0.8),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                featuredItem.quality!.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (featuredItem.overview != null && featuredItem.overview!.isNotEmpty) ...[
                        Text(
                          featuredItem.overview!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      ElevatedButton.icon(
                        onPressed: () {
                          if (featuredItem.isSeries) {
                            context.push(
                              '/detail/${featuredItem.slug}',
                              extra: {'isSeries': true},
                            );
                          } else {
                            context.push(
                              '/player/${featuredItem.id}',
                              extra: {
                                'slug': featuredItem.slug,
                                'isMovie': true,
                              },
                            );
                          }
                        },
                        icon: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 20),
                        label: const Text(
                          'Putar',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
