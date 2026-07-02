import 'package:flutter/material.dart';
import 'package:streaming_mobile/core/core.dart';

/// Badge label kecil (genre, tipe konten, dll.).
class AppBadge extends StatelessWidget {
  const AppBadge(this.label, {super.key, this.color});

  final String label;

  /// Warna background badge. Default ke [AppColors.surface].
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: AppRadius.smAll,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Text(
        label,
        style: AppTypography.badge.copyWith(color: AppColors.textMuted),
      ),
    );
  }
}
