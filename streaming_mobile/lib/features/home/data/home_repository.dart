import 'package:streaming_mobile/core/core.dart';
import 'package:streaming_mobile/features/home/data/movie_model.dart';

/// Repository home — query paginated ke tabel movies di Supabase.
class HomeRepository {
  const HomeRepository();

  static const int _pageSize = 20;

  /// Ambil daftar konten dengan paginasi dan filter opsional.
  ///
  /// [page] dimulai dari 0.
  /// [genre] filter berdasarkan nama genre (null = semua).
  /// [year] filter berdasarkan tahun rilis (null = semua).
  /// [contentType] filter 'movie' / 'series' / null = semua.
  Future<List<MovieModel>> fetchMovies({
    int page = 0,
    String? genre,
    String? year,
    String? contentType,
  }) async {
    // Bangun query dengan filter opsional
    var query = supabaseClient
        .from(ApiEndpoints.movies)
        .select(
          'id, title, slug, content_type, poster_path, release_date, vote_average, genres, quality',
        );

    if (contentType != null) {
      query = query.eq('content_type', contentType);
    }
    if (year != null) {
      query = query.like('release_date', '$year%');
    }
    if (genre != null) {
      query = query.ilike('genres', '%"name":"$genre"%');
    }

    final data = await query
        .order('created_at', ascending: false)
        .range(page * _pageSize, (page + 1) * _pageSize - 1);

    return (data as List).map((e) => MovieModel.fromMap(e)).toList();
  }

  /// Ambil semua genre unik yang tersedia untuk filter.
  Future<List<String>> fetchAvailableGenres() async {
    final data = await supabaseClient
        .from(ApiEndpoints.movies)
        .select('genres')
        .not('genres', 'is', null)
        .limit(500);

    final genreSet = <String>{};
    for (final row in data as List) {
      final raw = row['genres'] as String?;
      if (raw == null || raw.isEmpty) continue;
      // Parse JSON string '[{"name":"Action"},...]'
      try {
        final decoded = _parseGenreJson(raw);
        genreSet.addAll(decoded);
      } catch (_) {}
    }

    final sorted = genreSet.toList()..sort();
    return sorted;
  }

  /// Ambil semua tahun unik yang tersedia untuk filter.
  Future<List<String>> fetchAvailableYears() async {
    final data = await supabaseClient
        .from(ApiEndpoints.movies)
        .select('release_date')
        .not('release_date', 'is', null)
        .order('release_date', ascending: false)
        .limit(2000);

    final yearSet = <String>{};
    for (final row in data as List) {
      final date = row['release_date'] as String?;
      if (date != null && date.length >= 4) {
        yearSet.add(date.substring(0, 4));
      }
    }

    final sorted = yearSet.toList()..sort((a, b) => b.compareTo(a));
    return sorted;
  }

  /// Parse JSON string genres ke List<String> nama genre.
  List<String> _parseGenreJson(String raw) {
    // Format: '[{"name":"Action"},{"name":"Drama"}]'
    final names = <String>[];
    final matches = RegExp(r'"name"\s*:\s*"([^"]+)"').allMatches(raw);
    for (final m in matches) {
      final name = m.group(1);
      if (name != null) names.add(name);
    }
    return names;
  }
}
