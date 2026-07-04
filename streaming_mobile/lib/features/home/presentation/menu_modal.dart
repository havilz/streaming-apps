import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:streaming_mobile/core/core.dart';

class MenuModal extends StatelessWidget {
  const MenuModal({
    super.key,
    required this.onItemSelected,
    required this.currentLocation,
  });

  final void Function(String item) onItemSelected;
  final String currentLocation;

  bool _isItemActive(String value) {
    if (value == 'home' && currentLocation == '/') return true;
    if (value == 'movie' && currentLocation.startsWith('/movies')) return true;
    if (value == 'series' && currentLocation.startsWith('/series')) return true;
    if (value == 'genres' && currentLocation.startsWith('/genres')) return true;
    if (value == 'country' && currentLocation.startsWith('/countries')) return true;
    if (value == 'years' && currentLocation.startsWith('/years')) return true;
    if (value == 'network' && currentLocation.startsWith('/networks')) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final menuItems = [
      (label: 'Home', icon: Icons.home_rounded, value: 'home'),
      (label: 'Movie', icon: Icons.movie_rounded, value: 'movie'),
      (label: 'Series', icon: Icons.tv_rounded, value: 'series'),
      (label: 'Genres', icon: Icons.grid_view_rounded, value: 'genres'),
      (label: 'Country', icon: Icons.public_rounded, value: 'country'),
      (label: 'Years', icon: Icons.calendar_today_rounded, value: 'years'),
      (label: 'Network', icon: Icons.cell_tower_rounded, value: 'network'),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Glass background overlay
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.7),
                ),
              ),
            ),
          ),

          // Pinned floating close button matching menu hamburger button placement
          Positioned(
            top: MediaQuery.paddingOf(context).top + 12,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: IconButton(
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
                icon: const Icon(
                  Icons.close,
                  color: AppColors.textPrimary,
                  size: 22,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),

          // Menu Content
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 48),

                const Spacer(flex: 1),

                // Title
                Text(
                  'SV MENU',
                  style: AppTypography.logo.copyWith(
                    color: AppColors.primary,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3.0,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // Menu items list
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: menuItems.map((item) {
                      final isActive = _isItemActive(item.value);

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              Navigator.of(context).pop();
                              if (item.value == 'movie') {
                                context.push('/movies');
                              } else if (item.value == 'series') {
                                context.push('/series');
                              } else if (item.value == 'genres') {
                                context.push('/genres');
                              } else if (item.value == 'country') {
                                context.push('/countries');
                              } else if (item.value == 'years') {
                                context.push('/years');
                              } else if (item.value == 'network') {
                                context.push('/networks');
                              } else {
                                onItemSelected(item.value);
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.sm + 4,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: isActive
                                      ? AppColors.primary.withValues(alpha: 0.3)
                                      : Colors.white.withValues(alpha: 0.05),
                                  width: 1,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                color: isActive
                                    ? AppColors.primary.withValues(alpha: 0.08)
                                    : Colors.white.withValues(alpha: 0.03),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    item.icon,
                                    color: isActive
                                        ? AppColors.primary
                                        : AppColors.textPrimary.withValues(alpha: 0.8),
                                    size: 22,
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Text(
                                    item.label,
                                    style: AppTypography.body.copyWith(
                                      color: isActive ? AppColors.primary : AppColors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const Spacer(),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    color: isActive
                                        ? AppColors.primary.withValues(alpha: 0.7)
                                        : AppColors.textMuted,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const Spacer(flex: 2),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void showMenuModal(BuildContext context, {required void Function(String item) onItemSelected}) {
  final String currentLocation = GoRouterState.of(context).uri.path;
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Menu',
    barrierColor: Colors.black12,
    pageBuilder: (dialogContext, anim1, anim2) {
      return MenuModal(
        onItemSelected: onItemSelected,
        currentLocation: currentLocation,
      );
    },
    transitionBuilder: (dialogContext, anim1, anim2, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.0, -0.3),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: anim1,
          curve: Curves.easeOutCirc,
        )),
        child: FadeTransition(
          opacity: anim1,
          child: child,
        ),
      );
    },
  );
}
