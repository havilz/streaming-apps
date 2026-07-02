import 'package:flutter/material.dart';
import 'package:streaming_mobile/core/core.dart';

/// Baris tombol pemilih season yang dapat di-scroll secara horizontal.
class SeasonSelector extends StatelessWidget {
  const SeasonSelector({
    super.key,
    required this.seasonCount,
    required this.activeSeason,
    required this.onSeasonSelected,
  });

  final int seasonCount;
  final int activeSeason;
  final void Function(int season) onSeasonSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount: seasonCount,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final season = index + 1;
          final isActive = season == activeSeason;
          return AnimatedContainer(
            duration: AppDuration.normal,
            child: InkWell(
              onTap: () => onSeasonSelected(season),
              borderRadius: AppRadius.fullAll,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primary : AppColors.surface,
                  borderRadius: AppRadius.fullAll,
                  border: Border.all(
                    color: isActive
                        ? AppColors.primary
                        : AppColors.borderSubtle,
                  ),
                ),
                child: Text(
                  'Season $season',
                  style: AppTypography.caption.copyWith(
                    color: isActive
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
