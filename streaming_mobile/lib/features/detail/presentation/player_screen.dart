import 'package:flutter/material.dart';
import 'package:streaming_mobile/core/core.dart';

/// Halaman pemutar video — akan diimplementasi pada task 5.
class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key, required this.episodeId});

  final String episodeId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Text(
          'Player: $episodeId',
          style: const TextStyle(color: AppColors.textPrimary),
        ),
      ),
    );
  }
}
