import 'package:flutter/material.dart';
import 'package:streaming_mobile/core/core.dart';

/// Garis pemisah bertema: tipis dan transparan sesuai sistem desain.
class AppDivider extends StatelessWidget {
  const AppDivider({super.key, this.indent, this.endIndent});

  final double? indent;
  final double? endIndent;

  @override
  Widget build(BuildContext context) {
    return Divider(
      color: AppColors.borderSubtle,
      thickness: 1,
      indent: indent,
      endIndent: endIndent,
    );
  }
}
