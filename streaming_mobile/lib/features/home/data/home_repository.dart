import 'package:streaming_mobile/core/core.dart';
import 'package:streaming_mobile/features/home/data/movie_model.dart';

/// Repository home — query tabel movies dan series dari Supabase.
class HomeRepository {
  const HomeRepository();

  static const int _pageSize = 20;

  /// Ambil daftar film dengan paginasi dan filter opsional.
  Future<List<MovieModel>> fetchMovies({
    int page = 0,
    int? genreId,
    String? year,
  }) async {
    var query = supabaseClient
        .from(ApiEndpoints.movies)
        .select(
          'id, title, slug, poster_path, release_date, vote_average, quality, movie_genres(genres(name))',
        );

    if (year != null) {
      query = query.like('release_date', '$year%');
    }
    if (genreId != null) {
      query = query.eq('movie_genres.genre_id', genreId);
    }

    final data = await query
        .order('created_at', ascending: false)
        .range(page * _pageSize, (page + 1) * _pageSize - 1);

    return (data as List).map((e) => MovieModel.fromMap(e)).toList();
  }

  /// Ambil daftar series dengan paginasi dan filter opsional.
  Future<List<SeriesModel>> fetchSeries({
    int page = 0,
    int? genreId,
    String? year,
  }) async {
    var query = supabaseClient
        .from(ApiEndpoints.series)
        .select(
          'id, title, slug, poster_path, first_air_date, vote_average, quality, series_genres(genres(name))',
        );

    if (year != null) {
      query = query.like('first_air_date', '$year%');
    }
    if (genreId != null) {
      query = query.eq('series_genres.genre_id', genreId);
    }

    final data = await query
        .order('created_at', ascending: false)
        .range(page * _pageSize, (page + 1) * _pageSize - 1);

    return (data as List).map((e) => SeriesModel.fromMap(e)).toList();
  }

  /// Ambil semua genre unik dari tabel genres.
  Future<List<({int id, String name})>> fetchAvailableGenres() async {
    final data = await supabaseClient
        .from(ApiEndpoints.genres)
        .select('id, name')
        .order('name');

    return (data as List)
        .map((e) => (id: e['id'] as int, name: e['name'] as String))
        .toList();
  }

  /// Ambil semua tahun unik dari movies dan series.
  Future<List<String>> fetchAvailableYears() async {
    final movies = await supabaseClient
        .from(ApiEndpoints.movies)
        .select('release_date')
        .not('release_date', 'is', null)
        .order('release_date', ascending: false)
        .limit(1000);

    final seriesList = await supabaseClient
        .from(ApiEndpoints.series)
        .select('first_air_date')
        .not('first_air_date', 'is', null)
        .order('first_air_date', ascending: false)
        .limit(1000);

    final yearSet = <String>{};
    for (final row in [...movies as List, ...seriesList as List]) {
      final date = (row['release_date'] ?? row['first_air_date']) as String?;
      if (date != null && date.length >= 4) {
        yearSet.add(date.substring(0, 4));
      }
    }

    return yearSet.toList()..sort((a, b) => b.compareTo(a));
  }
}
