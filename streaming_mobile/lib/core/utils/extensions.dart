/// Extension methods untuk tipe dasar Dart.

extension StringExtension on String {
  /// Mengambil 4 karakter pertama dari ISO date string sebagai tahun.
  /// Contoh: '2024-05-15'.toYear() → '2024'
  String toYear() => length >= 4 ? substring(0, 4) : this;

  /// Mengkapitalisasi huruf pertama.
  String get capitalized =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}

extension NullableStringExtension on String? {
  /// Mengembalikan string kosong jika null.
  String get orEmpty => this ?? '';

  /// Mengembalikan true jika null atau kosong.
  bool get isNullOrEmpty => this == null || this!.isEmpty;
}
