import 'package:flutter/material.dart';

/// Token durasi animasi dan kurva transisi.
abstract final class AppDuration {
  /// 150ms — feedback tap, opacity cepat
  static const Duration fast = Duration(milliseconds: 150);

  /// 250ms — transisi state navigasi, hover card
  static const Duration normal = Duration(milliseconds: 250);

  /// 400ms — page transition, modal masuk/keluar
  static const Duration slow = Duration(milliseconds: 400);

  // --- Kurva Animasi ---
  static const Curve defaultCurve = Curves.easeInOut;
  static const Curve entryCurve = Curves.easeOut;
  static const Curve exitCurve = Curves.easeIn;
}
