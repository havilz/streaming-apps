import 'package:flutter/material.dart';

/// Token border radius.
abstract final class AppRadius {
  /// 6dp — border radius badge dan elemen kecil
  static const double sm = 6.0;
  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));

  /// 12dp — border radius card konten
  static const double md = 12.0;
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));

  /// 20dp — border radius bottom sheet, modal
  static const double lg = 20.0;
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));

  /// 9999dp — border radius kapsul (pill shape)
  static const double full = 9999.0;
  static const BorderRadius fullAll = BorderRadius.all(Radius.circular(full));
}
