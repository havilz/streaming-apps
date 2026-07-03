/// Konstanta nama tabel dan Edge Function di Supabase.
abstract final class ApiEndpoints {
  // --- Tabel utama ---
  static const String movies = 'movies';
  static const String series = 'series';
  static const String episodes = 'episodes';

  // --- Tabel referensi ---
  static const String genres = 'genres';
  static const String countries = 'countries';
  static const String networks = 'networks';

  // --- Tabel relasi ---
  static const String movieGenres = 'movie_genres';
  static const String seriesGenres = 'series_genres';
  static const String movieCountries = 'movie_countries';
  static const String seriesCountries = 'series_countries';
  static const String seriesNetworks = 'series_networks';

  // --- Edge Functions ---
  static const String unlockStream = 'unlock-stream';
  static const String syncContent = 'sync-content';
}
