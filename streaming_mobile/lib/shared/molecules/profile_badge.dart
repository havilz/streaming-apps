import 'package:flutter/material.dart';
import 'package:streaming_mobile/core/core.dart';

/// Lencana profil berbentuk lingkaran dinamis dengan glow effect.
/// Menampilkan inisial jika login, atau ikon default jika belum login.
class ProfileBadge extends StatelessWidget {
  const ProfileBadge({
    super.key,
    this.initials = '',
    this.radius = 40.0,
  });

  final String initials;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final hasInitials = initials.trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
        border: Border.all(
          color: AppColors.primary.withOpacity(0.6),
          width: 2,
        ),
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.surface,
        child: hasInitials
            ? Text(
                initials.toUpperCase(),
                style: TextStyle(
                  fontFamily: AppTypography.fontHeader,
                  fontSize: radius * 0.7,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                  letterSpacing: 0.5,
                ),
              )
            : Icon(
                Icons.person,
                color: AppColors.textMuted,
                size: radius * 0.9,
              ),
      ),
    );
  }
}
