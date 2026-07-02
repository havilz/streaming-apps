/// Model data untuk konten film dan series.
/// Field sesuai skema tabel `movies` di Supabase.
class MovieModel {
  const MovieModel({
    required this.id,
    required this.title,
    required this.slug,
    required this.contentType,
    this.tmdbId,
    this.originalTitle,
    this.overview,
    this.posterPath,
    this.backdropPath,
    this.releaseDate,
    this.runtime,
    this.voteAverage,
    this.genres,
    this.quality,
    this.seasons,
  });

  final String id;
  final String title;
  final String slug;

  /// 'movie' atau 'series'
  final String contentType;

  final int? tmdbId;
  final String? originalTitle;
  final String? overview;
  final String? posterPath;
  final String? backdropPath;
  final String? releaseDate;
  final int? runtime;
  final double? voteAverage;

  /// JSON string dari Supabase, contoh: '[{"name":"Action"}]'
  final String? genres;

  final String? quality;

  /// JSON string daftar season untuk series
  final String? seasons;

  /// Apakah konten ini series
  bool get isSeries => contentType == 'series';

  /// Tahun rilis dari release_date ISO string
  String get year => (releaseDate != null && releaseDate!.length >= 4)
      ? releaseDate!.substring(0, 4)
      : '';

  factory MovieModel.fromMap(Map<String, dynamic> map) {
    return MovieModel(
      id: map['id'] as String,
      title: map['title'] as String,
      slug: map['slug'] as String,
      contentType: map['content_type'] as String? ?? 'movie',
      tmdbId: map['tmdb_id'] as int?,
      originalTitle: map['original_title'] as String?,
      overview: map['overview'] as String?,
      posterPath: map['poster_path'] as String?,
      backdropPath: map['backdrop_path'] as String?,
      releaseDate: map['release_date'] as String?,
      runtime: map['runtime'] as int?,
      voteAverage: (map['vote_average'] as num?)?.toDouble(),
      genres: map['genres'] as String?,
      quality: map['quality'] as String?,
      seasons: map['seasons'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'slug': slug,
    'content_type': contentType,
    'tmdb_id': tmdbId,
    'original_title': originalTitle,
    'overview': overview,
    'poster_path': posterPath,
    'backdrop_path': backdropPath,
    'release_date': releaseDate,
    'runtime': runtime,
    'vote_average': voteAverage,
    'genres': genres,
    'quality': quality,
    'seasons': seasons,
  };
}
