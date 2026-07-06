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
    int? limit,
  }) async {
    var query = supabaseClient
        .from(ApiEndpoints.movies)
        .select(
          'id, title, slug, poster_path, backdrop_path, overview, release_date, vote_average, quality, created_at, movie_genres(genres(name)), movie_countries(countries(name))',
        );

    if (year != null) {
      query = query.like('release_date', '$year%');
    }
    if (genreId != null) {
      query = query.eq('movie_genres.genre_id', genreId);
    }

    final limitVal = limit ?? _pageSize;
    final data = await query
        .order('created_at', ascending: false)
        .range(page * limitVal, (page + 1) * limitVal - 1);

    return (data as List).map((e) => MovieModel.fromMap(e)).toList();
  }

  /// Ambil daftar series dengan paginasi dan filter opsional.
  Future<List<SeriesModel>> fetchSeries({
    int page = 0,
    int? genreId,
    String? year,
    int? limit,
  }) async {
    var query = supabaseClient
        .from(ApiEndpoints.series)
        .select(
          'id, title, slug, poster_path, backdrop_path, overview, first_air_date, vote_average, quality, created_at, series_genres(genres(name)), series_networks(networks(name)), series_countries(countries(name))',
        );

    if (year != null) {
      query = query.like('first_air_date', '$year%');
    }
    if (genreId != null) {
      query = query.eq('series_genres.genre_id', genreId);
    }

    final limitVal = limit ?? _pageSize;
    final data = await query
        .order('created_at', ascending: false)
        .range(page * limitVal, (page + 1) * limitVal - 1);

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

  /// Ambil semua negara dari tabel countries.
  Future<List<({int id, String name})>> fetchAvailableCountries() async {
    final data = await supabaseClient
        .from(ApiEndpoints.countries)
        .select('id, name')
        .order('name');

    return (data as List)
        .map((e) => (id: e['id'] as int, name: e['name'] as String))
        .toList();
  }

  /// Ambil semua network dari tabel networks.
  Future<List<({int id, String name, String? logoPath})>> fetchAvailableNetworks() async {
    final data = await supabaseClient
        .from(ApiEndpoints.networks)
        .select('id, name, logo_path')
        .order('name');

    return (data as List)
        .map((e) => (
              id: e['id'] as int,
              name: e['name'] as String,
              logoPath: e['logo_path'] as String?,
            ))
        .toList();
  }

  /// Ambil semua tahun unik dari movies dan series.
  Future<List<String>> fetchAvailableYears() async {
    final results = await Future.wait([
      supabaseClient
          .from(ApiEndpoints.movies)
          .select('release_date')
          .not('release_date', 'is', null)
          .order('release_date', ascending: false)
          .limit(1000),
      supabaseClient
          .from(ApiEndpoints.movies)
          .select('release_date')
          .not('release_date', 'is', null)
          .order('release_date', ascending: true)
          .limit(1000),
      supabaseClient
          .from(ApiEndpoints.series)
          .select('first_air_date')
          .not('first_air_date', 'is', null)
          .order('first_air_date', ascending: false)
          .limit(1000),
      supabaseClient
          .from(ApiEndpoints.series)
          .select('first_air_date')
          .not('first_air_date', 'is', null)
          .order('first_air_date', ascending: true)
          .limit(1000),
    ]);

    final yearSet = <String>{};
    for (final res in results) {
      for (final row in res as List) {
        final date = (row['release_date'] ?? row['first_air_date']) as String?;
        if (date != null && date.length >= 4) {
          yearSet.add(date.substring(0, 4));
        }
      }
    }

    return yearSet.toList()..sort((a, b) => b.compareTo(a));
  }

  /// Ambil series berdasarkan nama network (partial match, case-insensitive).
  /// Melakukan 3-step query: networks → series_networks → series.
  Future<List<SeriesModel>> fetchSeriesByNetwork(
    String networkPattern, {
    double minRating = 0.0,
    int limit = 50,
  }) async {
    // Step 1: cari network IDs yang namanya mengandung networkPattern
    final networkRows = await supabaseClient
        .from(ApiEndpoints.networks)
        .select('id')
        .ilike('name', '%$networkPattern%');

    final networkIds =
        (networkRows as List).map((n) => n['id'] as int).toList();
    if (networkIds.isEmpty) return [];

    // Step 2: ambil series_id dari junction table
    final junctionRows = await supabaseClient
        .from(ApiEndpoints.seriesNetworks)
        .select('series_id')
        .inFilter('network_id', networkIds)
        .limit(200);

    final seriesIds = (junctionRows as List)
        .map((n) => n['series_id'] as String)
        .toSet()
        .toList();
    if (seriesIds.isEmpty) return [];

    // Step 3: fetch series dengan rating filter, ordered by vote_average desc
    var query = supabaseClient
        .from(ApiEndpoints.series)
        .select(
          'id, title, slug, poster_path, backdrop_path, overview, '
          'first_air_date, vote_average, quality, number_of_seasons, '
          'series_genres(genres(name)), series_networks(networks(name)), series_countries(countries(name))',
        )
        .inFilter('id', seriesIds);

    if (minRating > 0) {
      query = query.gte('vote_average', minRating);
    }

    final data = await query
        .order('vote_average', ascending: false)
        .limit(limit);

    return (data as List).map((e) => SeriesModel.fromMap(e)).toList();
  }

  /// Ambil film berdasarkan ID genre via junction table `movie_genres`
  Future<List<MovieModel>> fetchMoviesByGenre(
    int genreId, {
    int limit = 50,
  }) async {
    final junctionRows = await supabaseClient
        .from(ApiEndpoints.movieGenres)
        .select('movie_id')
        .eq('genre_id', genreId)
        .limit(limit);

    final ids = (junctionRows as List)
        .map((n) => n['movie_id'] as String)
        .toSet()
        .toList();
    if (ids.isEmpty) return [];

    final data = await supabaseClient
        .from(ApiEndpoints.movies)
        .select(
          'id, title, slug, poster_path, backdrop_path, overview, release_date, '
          'vote_average, quality, movie_genres(genres(name)), movie_countries(countries(name))',
        )
        .inFilter('id', ids)
        .limit(limit);

    return (data as List).map((e) => MovieModel.fromMap(e)).toList();
  }

  /// Ambil series berdasarkan ID genre via junction table `series_genres`
  Future<List<SeriesModel>> fetchSeriesByGenre(
    int genreId, {
    int limit = 50,
  }) async {
    final junctionRows = await supabaseClient
        .from(ApiEndpoints.seriesGenres)
        .select('series_id')
        .eq('genre_id', genreId)
        .limit(limit);

    final ids = (junctionRows as List)
        .map((n) => n['series_id'] as String)
        .toSet()
        .toList();
    if (ids.isEmpty) return [];

    final data = await supabaseClient
        .from(ApiEndpoints.series)
        .select(
          'id, title, slug, poster_path, backdrop_path, overview, first_air_date, '
          'vote_average, quality, number_of_seasons, '
          'series_genres(genres(name)), series_networks(networks(name)), series_countries(countries(name))',
        )
        .inFilter('id', ids)
        .limit(limit);

    return (data as List).map((e) => SeriesModel.fromMap(e)).toList();
  }

  /// Ambil film berdasarkan ID negara via junction table `movie_countries`
  Future<List<MovieModel>> fetchMoviesByCountry(
    int countryId, {
    int limit = 50,
  }) async {
    final junctionRows = await supabaseClient
        .from(ApiEndpoints.movieCountries)
        .select('movie_id')
        .eq('country_id', countryId)
        .limit(limit);

    final ids = (junctionRows as List)
        .map((n) => n['movie_id'] as String)
        .toSet()
        .toList();
    if (ids.isEmpty) return [];

    final data = await supabaseClient
        .from(ApiEndpoints.movies)
        .select(
          'id, title, slug, poster_path, backdrop_path, overview, release_date, '
          'vote_average, quality, movie_genres(genres(name)), movie_countries(countries(name))',
        )
        .inFilter('id', ids)
        .limit(limit);

    return (data as List).map((e) => MovieModel.fromMap(e)).toList();
  }

  /// Ambil series berdasarkan ID negara via junction table `series_countries`
  Future<List<SeriesModel>> fetchSeriesByCountry(
    int countryId, {
    int limit = 50,
  }) async {
    final junctionRows = await supabaseClient
        .from(ApiEndpoints.seriesCountries)
        .select('series_id')
        .eq('country_id', countryId)
        .limit(limit);

    final ids = (junctionRows as List)
        .map((n) => n['series_id'] as String)
        .toSet()
        .toList();
    if (ids.isEmpty) return [];

    final data = await supabaseClient
        .from(ApiEndpoints.series)
        .select(
          'id, title, slug, poster_path, backdrop_path, overview, first_air_date, '
          'vote_average, quality, number_of_seasons, '
          'series_genres(genres(name)), series_networks(networks(name)), series_countries(countries(name))',
        )
        .inFilter('id', ids)
        .limit(limit);

    return (data as List).map((e) => SeriesModel.fromMap(e)).toList();
  }

  /// Ambil film berdasarkan tahun
  Future<List<MovieModel>> fetchMoviesByYear(
    String year, {
    int limit = 50,
  }) async {
    final data = await supabaseClient
        .from(ApiEndpoints.movies)
        .select(
          'id, title, slug, poster_path, backdrop_path, overview, release_date, '
          'vote_average, quality, movie_genres(genres(name)), movie_countries(countries(name))',
        )
        .like('release_date', '$year%')
        .limit(limit);

    return (data as List).map((e) => MovieModel.fromMap(e)).toList();
  }

  /// Ambil series berdasarkan tahun
  Future<List<SeriesModel>> fetchSeriesByYear(
    String year, {
    int limit = 50,
  }) async {
    final data = await supabaseClient
        .from(ApiEndpoints.series)
        .select(
          'id, title, slug, poster_path, backdrop_path, overview, first_air_date, '
          'vote_average, quality, number_of_seasons, '
          'series_genres(genres(name)), series_networks(networks(name)), series_countries(countries(name))',
        )
        .like('first_air_date', '$year%')
        .limit(limit);

    return (data as List).map((e) => SeriesModel.fromMap(e)).toList();
  }

  /// Ambil daftar episode terbaru beserta data series-nya.
  Future<List<UpdatedItem>> fetchNewestEpisodes({int limit = 15}) async {
    final data = await supabaseClient
        .from('episodes')
        .select(
          'id, season_number, episode_number, title, still_path, created_at, series:series_id(title, slug, poster_path, backdrop_path, vote_average)',
        )
        .order('created_at', ascending: false)
        .limit(limit);

    return (data as List).map((e) => UpdatedItem.fromEpisodeMap(e as Map<String, dynamic>)).toList();
  }
}
