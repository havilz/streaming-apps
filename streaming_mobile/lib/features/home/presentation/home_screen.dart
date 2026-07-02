import 'package:flutter/material.dart';
import 'package:streaming_mobile/core/core.dart';

/// Halaman utama — akan diimplementasi pada task 4.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: const Center(
        child: Text(
          'Home Screen',
          style: TextStyle(color: AppColors.textPrimary),
        ),
      ),
    );
  }
}
