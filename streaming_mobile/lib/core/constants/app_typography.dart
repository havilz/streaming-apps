import 'package:flutter/material.dart';

/// Token tipografi: ukuran teks dan font family.
abstract final class AppTypography {
  // --- Font Family ---
  static const String fontHeader = 'Outfit';
  static const String fontBody = 'Inter';

  // --- Skala Ukuran Teks (sp) ---
  /// 11sp
  static const double textXs = 11.0;

  /// 13sp
  static const double textSm = 13.0;

  /// 15sp
  static const double textMd = 15.0;

  /// 18sp
  static const double textLg = 18.0;

  /// 22sp
  static const double textXl = 22.0;

  /// 28sp
  static const double text2xl = 28.0;

  // --- Text Style Presets ---
  /// Style logo/brand: Outfit ExtraBold 28sp
  static const TextStyle logo = TextStyle(
    fontFamily: fontHeader,
    fontSize: text2xl,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
  );

  /// Style heading halaman
  static const TextStyle heading = TextStyle(
    fontFamily: fontHeader,
    fontSize: textXl,
    fontWeight: FontWeight.w700,
  );

  /// Style judul card/konten
  static const TextStyle title = TextStyle(
    fontFamily: fontHeader,
    fontSize: textLg,
    fontWeight: FontWeight.w600,
  );

  /// Style body teks utama
  static const TextStyle body = TextStyle(
    fontFamily: fontBody,
    fontSize: textMd,
    fontWeight: FontWeight.w400,
  );

  /// Style keterangan/meta info
  static const TextStyle caption = TextStyle(
    fontFamily: fontBody,
    fontSize: textSm,
    fontWeight: FontWeight.w400,
  );

  /// Style label badge kecil
  static const TextStyle badge = TextStyle(
    fontFamily: fontBody,
    fontSize: textXs,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.3,
  );
}
