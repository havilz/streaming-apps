import 'package:streaming_mobile/core/utils/formatters.dart';

// ignore_for_file: unused_import
// Shared TMDB image base URL
const _tmdbBase = 'https://image.tmdb.org/t/p';

String? _posterUrl(String? path) {
  if (path == null || path.isEmpty) return null;
  if (path.startsWith('http')) return path;
  return '$_tmdbBase/w500$path';
}

String? _backdropUrl(String? path) {
  if (path == null || path.isEmpty) return null;
  if (path.startsWith('http')) return path;
  return '$_tmdbBase/w1280$path';
}

String _yearFrom(String? date) =>
    (date != null && date.length >= 4) ? date.substring(0, 4) : '';

// ─────────────────────────────────────────────────────────────
// MovieModel — tabel `movies`
// ─────────────────────────────────────────────────────────────

class MovieModel {
  const MovieModel({
    required this.id,
    required this.title,
    required this.slug,
    this.tmdbId,
    this.imdbId,
    this.originalTitle,
    this.overview,
    this.posterPath,
    this.backdropPath,
    this.releaseDate,
    this.runtime,
    this.voteAverage,
    this.quality,
    this.status,
    this.genres = const [],
  });

  final String id;
  final String title;
  final String slug;
  final int? tmdbId;
  final String? imdbId;
  final String? originalTitle;
  final String? overview;
  final String? posterPath;
  final String? backdropPath;
  final String? releaseDate;
  final int? runtime;
  final double? voteAverage;
  final String? quality;

  /// 'Released', 'In Production', dll
  final String? status;

  /// Daftar nama genre (sudah diparsing dari relasi)
  final List<String> genres;

  String get year => _yearFrom(releaseDate);
  String? get posterUrl => _posterUrl(posterPath);
  String? get backdropUrl => _backdropUrl(backdropPath);

  factory MovieModel.fromMap(Map<String, dynamic> map) {
    // Genres bisa datang sebagai relasi nested atau tidak ada
    final genreList = <String>[];
    if (map['movie_genres'] != null) {
      for (final mg in map['movie_genres'] as List) {
        final name =
            (mg['genres'] as Map<String, dynamic>?)?['name'] as String?;
        if (name != null) genreList.add(name);
      }
    }

    return MovieModel(
      id: map['id'] as String,
      title: map['title'] as String,
      slug: map['slug'] as String,
      tmdbId: map['tmdb_id'] as int?,
      imdbId: map['imdb_id'] as String?,
      originalTitle: map['original_title'] as String?,
      overview: map['overview'] as String?,
      posterPath: map['poster_path'] as String?,
      backdropPath: map['backdrop_path'] as String?,
      releaseDate: map['release_date'] as String?,
      runtime: (map['runtime'] as num?)?.toInt(),
      voteAverage: (map['vote_average'] as num?)?.toDouble(),
      quality: map['quality'] as String?,
      status: map['status'] as String?,
      genres: genreList,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SeriesModel — tabel `series`
// ─────────────────────────────────────────────────────────────

class SeriesModel {
  const SeriesModel({
    required this.id,
    required this.title,
    required this.slug,
    this.tmdbId,
    this.imdbId,
    this.originalTitle,
    this.overview,
    this.posterPath,
    this.backdropPath,
    this.firstAirDate,
    this.voteAverage,
    this.quality,
    this.status,
    this.numberOfSeasons,
    this.genres = const [],
  });

  final String id;
  final String title;
  final String slug;
  final int? tmdbId;
  final String? imdbId;
  final String? originalTitle;
  final String? overview;
  final String? posterPath;
  final String? backdropPath;
  final String? firstAirDate;
  final double? voteAverage;
  final String? quality;

  /// 'Returning Series', 'Ended', 'Canceled', dll
  final String? status;

  final int? numberOfSeasons;
  final List<String> genres;

  bool get isOngoing => status == 'Returning Series';
  String get year => _yearFrom(firstAirDate);
  String? get posterUrl => _posterUrl(posterPath);
  String? get backdropUrl => _backdropUrl(backdropPath);

  factory SeriesModel.fromMap(Map<String, dynamic> map) {
    final genreList = <String>[];
    if (map['series_genres'] != null) {
      for (final sg in map['series_genres'] as List) {
        final name =
            (sg['genres'] as Map<String, dynamic>?)?['name'] as String?;
        if (name != null) genreList.add(name);
      }
    }

    return SeriesModel(
      id: map['id'] as String,
      title: map['title'] as String,
      slug: map['slug'] as String,
      tmdbId: map['tmdb_id'] as int?,
      imdbId: map['imdb_id'] as String?,
      originalTitle: map['original_title'] as String?,
      overview: map['overview'] as String?,
      posterPath: map['poster_path'] as String?,
      backdropPath: map['backdrop_path'] as String?,
      firstAirDate: map['first_air_date'] as String?,
      voteAverage: (map['vote_average'] as num?)?.toDouble(),
      quality: map['quality'] as String?,
      status: map['status'] as String?,
      numberOfSeasons: (map['number_of_seasons'] as num?)?.toInt(),
      genres: genreList,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ContentItem — unified model untuk home page grid
// Menyatukan MovieModel dan SeriesModel agar bisa ditampilkan
// dalam satu list tanpa type casting di UI
// ─────────────────────────────────────────────────────────────

class ContentItem {
  const ContentItem({
    required this.id,
    required this.title,
    required this.slug,
    required this.isSeries,
    this.posterUrl,
    this.year,
    this.voteAverage,
    this.quality,
    this.genres = const [],
  });

  final String id;
  final String title;
  final String slug;
  final bool isSeries;
  final String? posterUrl;
  final String? year;
  final double? voteAverage;
  final String? quality;
  final List<String> genres;

  factory ContentItem.fromMovie(MovieModel m) => ContentItem(
    id: m.id,
    title: m.title,
    slug: m.slug,
    isSeries: false,
    posterUrl: m.posterUrl,
    year: m.year,
    voteAverage: m.voteAverage,
    quality: m.quality,
    genres: m.genres,
  );

  factory ContentItem.fromSeries(SeriesModel s) => ContentItem(
    id: s.id,
    title: s.title,
    slug: s.slug,
    isSeries: true,
    posterUrl: s.posterUrl,
    year: s.year,
    voteAverage: s.voteAverage,
    quality: s.quality,
    genres: s.genres,
  );
}
