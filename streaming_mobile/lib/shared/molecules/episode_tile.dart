import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:streaming_mobile/core/core.dart';
import 'package:streaming_mobile/shared/atoms/atoms.dart';

/// Item daftar episode dengan thumbnail, nomor episode, judul, dan tanggal.
class EpisodeTile extends StatelessWidget {
  const EpisodeTile({
    super.key,
    required this.episodeNumber,
    required this.title,
    this.stillUrl,
    this.airDate,
    this.isActive = false,
    this.onTap,
  });

  final int episodeNumber;
  final String title;
  final String? stillUrl;
  final String? airDate;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdAll,
      splashColor: AppColors.primaryGlowLight,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: isActive ? AppColors.activeBackground : Colors.transparent,
          borderRadius: AppRadius.mdAll,
          border: isActive
              ? Border.all(color: AppColors.primary)
              : Border.all(color: Colors.transparent),
        ),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: AppRadius.smAll,
              child: SizedBox(
                width: 120,
                height: 68,
                child: stillUrl != null
                    ? CachedNetworkImage(
                        imageUrl: stillUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const AppShimmer(
                          width: 120,
                          height: 68,
                          borderRadius: BorderRadius.zero,
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: AppColors.surface,
                          child: const Icon(
                            Icons.play_circle_outline,
                            color: AppColors.textMuted,
                          ),
                        ),
                      )
                    : Container(
                        color: AppColors.surface,
                        child: Center(
                          child: AppText(
                            'E$episodeNumber',
                            variant: AppTextVariant.title,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    'Episode $episodeNumber',
                    variant: AppTextVariant.caption,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  AppText(
                    title,
                    variant: AppTextVariant.body,
                    color: isActive ? AppColors.primary : null,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (airDate != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 11,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        AppText(
                          formatDate(airDate),
                          variant: AppTextVariant.badge,
                          color: AppColors.textMuted,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
