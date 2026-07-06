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
    this.voteAverage,
    this.numberOfSeasons,
    this.season,
    this.customBadge,
    this.onTap,
  });

  final String title;
  final String posterUrl;
  final String? year;
  final double? voteAverage;
  final int? numberOfSeasons;
  final int? season;
  final String? customBadge;
  final VoidCallback? onTap;

  @override
  State<MovieCard> createState() => _MovieCardState();
}

class _MovieCardState extends State<MovieCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final scale = _isPressed ? 0.97 : 1.0;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: AppDuration.normal,
        curve: AppDuration.defaultCurve,
        transform: Matrix4.diagonal3Values(scale, scale, 1.0),
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

                if (widget.customBadge != null ||
                    ((widget.season ?? widget.numberOfSeasons) != null &&
                    (widget.season ?? widget.numberOfSeasons)! > 0))
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        widget.customBadge ?? 'S${widget.season ?? widget.numberOfSeasons}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                // Bottom metadata badges (Rating & Year)
                // We fade them out when card is pressed to avoid overlap with title
                Positioned.fill(
                  child: AnimatedOpacity(
                    opacity: _isPressed ? 0.0 : 1.0,
                    duration: AppDuration.fast,
                    child: Stack(
                      children: [
                        // Rating (Bottom-Left)
                        if (widget.voteAverage != null &&
                            widget.voteAverage! > 0.0)
                          Positioned(
                            bottom: 6,
                            left: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    color: Colors.amber,
                                    size: 10,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    widget.voteAverage!.toStringAsFixed(1),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // Year (Bottom-Right)
                        if (widget.year != null && widget.year!.isNotEmpty)
                          Positioned(
                            bottom: 6,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                widget.year!,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Gradient overlay bawah (Title appears when pressed)
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
