import 'package:flutter/material.dart';
import 'package:streaming_mobile/core/core.dart';

/// Halaman detail film/series — akan diimplementasi pada task 5.
class DetailScreen extends StatelessWidget {
  const DetailScreen({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Text(
          'Detail: $slug',
          style: const TextStyle(color: AppColors.textPrimary),
        ),
      ),
    );
  }
}
