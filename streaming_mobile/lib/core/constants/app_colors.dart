import 'package:flutter/material.dart';

/// Semua token warna aplikasi.
abstract final class AppColors {
  // --- Brand / Accent ---
  /// Warna aksen utama: merah gelap premium
  static const Color primary = Color(0xFF9B1C1C);

  /// Background item navigasi / tab yang sedang aktif
  static const Color activeBackground = Color(0xFF7F1D1D);

  /// Glow shadow merah gelap (gunakan sebagai BoxShadow color)
  static const Color primaryGlow = Color(0x669B1C1C);

  /// Glow lebih transparan untuk hover ringan
  static const Color primaryGlowLight = Color(0x1A9B1C1C);

  // --- Background ---
  /// Latar belakang utama seluruh halaman
  static const Color background = Color(0xFF0B0F17);

  /// Latar belakang card, bottom sheet, panel (elevated surface)
  static const Color surface = Color(0xFF111827);

  /// Background navbar semi-transparan (dipakai bersama BackdropFilter)
  static const Color navbarBackground = Color(0xCC0B0F17);

  // --- Text ---
  /// Teks utama: putih pudar
  static const Color textPrimary = Color(0xFFF9FAFB);

  /// Teks sekunder: abu-abu muted untuk keterangan dan meta-info
  static const Color textMuted = Color(0xFF9CA3AF);

  // --- Border ---
  /// Border tipis transparan untuk card dan panel
  static const Color borderSubtle = Color(0x1AFFFFFF);

  /// Border atas navbar tipis
  static const Color borderNavbar = Color(0x0DFFFFFF);

  // --- Utility ---
  /// Warna transparan penuh
  static const Color transparent = Colors.transparent;
}
