/// Konstanta nama tabel dan Edge Function di Supabase.
/// Gunakan konstanta ini agar tidak ada typo nama tabel di query.
abstract final class ApiEndpoints {
  // --- Tabel ---
  /// Tabel konten film dan series
  static const String movies = 'movies';

  /// Tabel episode serial TV
  static const String episodes = 'episodes';

  // --- Edge Functions ---
  /// Fungsi untuk melakukan unlock stream URL (bypass gate token)
  static const String unlockStream = 'unlock-stream';
}
