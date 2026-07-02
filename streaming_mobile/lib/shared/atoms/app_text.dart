import 'package:flutter/material.dart';
import 'package:streaming_mobile/core/core.dart';

/// Widget teks dengan style bawaan dari sistem desain.
/// Pilih [variant] yang sesuai daripada mendefinisikan style manual.
enum AppTextVariant { heading, title, body, caption, badge, logo }

class AppText extends StatelessWidget {
  const AppText(
    this.text, {
    super.key,
    this.variant = AppTextVariant.body,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  final String text;
  final AppTextVariant variant;
  final Color? color;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  TextStyle get _baseStyle => switch (variant) {
    AppTextVariant.logo => AppTypography.logo,
    AppTextVariant.heading => AppTypography.heading,
    AppTextVariant.title => AppTypography.title,
    AppTextVariant.body => AppTypography.body,
    AppTextVariant.caption => AppTypography.caption,
    AppTextVariant.badge => AppTypography.badge,
  };

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: _baseStyle.copyWith(color: color ?? AppColors.textPrimary),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
