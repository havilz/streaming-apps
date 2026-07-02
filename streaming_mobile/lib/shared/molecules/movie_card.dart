import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:streaming_mobile/core/core.dart';
import 'package:streaming_mobile/shared/atoms/atoms.dart';

/// Card konten film/series dengan efek glow saat ditekan.
/// Rasio aspek poster 2:3 (standar poster film).
class MovieCard extends StatefulWidget {
  const MovieCard({
    super.key,
    required this.title,
    required this.posterUrl,
    this.year,
    this.onTap,
  });

  final String title;
  final String posterUrl;
  final String? year;
  final VoidCallback? onTap;

  @override
  State<MovieCard> createState() => _MovieCardState();
}

class _MovieCardState extends State<MovieCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: AppDuration.normal,
        curve: AppDuration.defaultCurve,
        transform: Matrix4.identity()..scale(_isPressed ? 0.97 : 1.0),
        decoration: BoxDecoration(
          borderRadius: AppRadius.mdAll,
          boxShadow: _isPressed
              ? [
                  BoxShadow(
                    color: AppColors.primaryGlow,
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ]
              : [],
        ),
        child: ClipRRect(
          borderRadius: AppRadius.mdAll,
          child: AspectRatio(
            aspectRatio: 2 / 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Poster image
                CachedNetworkImage(
                  imageUrl: widget.posterUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => const AppShimmer(
                    width: double.infinity,
                    height: double.infinity,
                    borderRadius: BorderRadius.zero,
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: AppColors.surface,
                    child: const Icon(
                      Icons.movie_outlined,
                      color: AppColors.textMuted,
                      size: 40,
                    ),
                  ),
                ),
                // Gradient overlay bawah
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: AnimatedOpacity(
                    opacity: _isPressed ? 1.0 : 0.0,
                    duration: AppDuration.fast,
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [AppColors.background, Colors.transparent],
                        ),
                      ),
                      child: AppText(
                        widget.title,
                        variant: AppTextVariant.caption,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
