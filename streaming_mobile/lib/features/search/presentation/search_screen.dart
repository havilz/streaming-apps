import 'package:flutter/material.dart';
import 'package:streaming_mobile/core/core.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: const Center(
        child: Text(
          'Search Screen',
          style: TextStyle(color: AppColors.textPrimary),
        ),
      ),
    );
  }
}
