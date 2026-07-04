import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:streaming_mobile/core/core.dart';
import 'package:streaming_mobile/features/home/domain/home_provider.dart';
import 'package:streaming_mobile/features/home/presentation/menu_modal.dart';
import 'package:streaming_mobile/features/search/presentation/search_modal.dart';
import 'package:streaming_mobile/shared/shared.dart';

final availableNetworksProvider = FutureProvider((ref) {
  return ref.read(homeRepositoryProvider).fetchAvailableNetworks();
});

class NetworksScreen extends ConsumerStatefulWidget {
  const NetworksScreen({super.key});

  @override
  ConsumerState<NetworksScreen> createState() => _NetworksScreenState();
}

class _NetworksScreenState extends ConsumerState<NetworksScreen> {
  final _scrollController = ScrollController();
  bool _showGlassBackground = false;

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
    final showGlass = _scrollController.offset > 30;
    if (showGlass != _showGlassBackground) {
      setState(() {
        _showGlassBackground = showGlass;
      });
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
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
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
  Widget build(BuildContext context) {
    final networksAsync = ref.watch(availableNetworksProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          SafeArea(
            child: RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.surface,
              onRefresh: () => ref.refresh(availableNetworksProvider.future),
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  const SliverToBoxAdapter(child: SizedBox(height: 70)),

                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const AppText(
                            'Penyedia Konten',
                            variant: AppTextVariant.heading,
                            color: AppColors.textPrimary,
                          ),
                          const SizedBox(height: 4),
                          AppText(
                            'Jelajahi berbagai jaringan/jaringan streaming penyedia konten terpopuler',
                            variant: AppTextVariant.caption,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),

                  networksAsync.when(
                    data: (networksList) {
                      if (networksList.isEmpty) {
                        return const SliverFillRemaining(
                          child: Center(
                            child: AppText(
                              'Tidak ada penyedia jaringan tersedia',
                              color: AppColors.textMuted,
                            ),
                          ),
                        );
                      }

                      final crossAxisCount = MediaQuery.sizeOf(context).width >= 600 ? 3 : 2;

                      return SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverGrid(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: AppSpacing.sm,
                            mainAxisSpacing: AppSpacing.sm,
                            childAspectRatio: 1.3,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final network = networksList[index];
                              final hasLogo = network.logoPath != null && network.logoPath!.isNotEmpty;

                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    context.push(
                                      '/networks/${network.id}?name=${Uri.encodeComponent(network.name)}',
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.05),
                                        width: 1,
                                      ),
                                      color: Colors.white.withValues(alpha: 0.03),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        if (hasLogo)
                                          Image.network(
                                            'https://image.tmdb.org/t/p/w200${network.logoPath}',
                                            height: 38,
                                            fit: BoxFit.contain,
                                            errorBuilder: (_, __, ___) => const Icon(
                                              Icons.live_tv_rounded,
                                              size: 32,
                                              color: AppColors.primary,
                                            ),
                                          )
                                        else
                                          const Icon(
                                            Icons.live_tv_rounded,
                                            size: 32,
                                            color: AppColors.primary,
                                          ),
                                        const SizedBox(height: 12),
                                        AppText(
                                          network.name,
                                          variant: AppTextVariant.body,
                                          color: AppColors.textPrimary,
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                            childCount: networksList.length,
                          ),
                        ),
                      );
                    },
                    loading: () => const SliverFillRemaining(
                      child: Center(
                        child: CircularProgressIndicator(color: AppColors.primary),
                      ),
                    ),
                    error: (err, _) => SliverFillRemaining(
                      child: Center(
                        child: AppText(
                          err.toString(),
                          color: AppColors.textMuted,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xl)),
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
}
