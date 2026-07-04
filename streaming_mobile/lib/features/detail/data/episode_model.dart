const _tmdbBase = 'https://image.tmdb.org/t/p';

/// Model data untuk episode series — tabel `episodes`.
class EpisodeModel {
  const EpisodeModel({
    required this.id,
    required this.seriesId,
    required this.seasonNumber,
    required this.episodeNumber,
    this.title,
    this.overview,
    this.stillPath,
    this.runtime,
    this.airDate,
    this.videoUrl,
    this.videoType,
  });

  final String id;
  final String seriesId;
  final int seasonNumber;
  final int episodeNumber;
  final String? title;
  final String? overview;
  final String? stillPath;
  final int? runtime;
  final String? airDate;
  final String? videoUrl;
  final String? videoType;

  /// URL lengkap thumbnail episode.
  ///
  /// Untuk tampilan poster episode dengan kualitas lebih baik,
  /// gunakan ukuran `w780` dari TMDB.
  String? get stillUrl {
    if (stillPath == null || stillPath!.isEmpty) return null;
    if (stillPath!.startsWith('http')) return stillPath;
    return '$_tmdbBase/w780$stillPath';
  }

  factory EpisodeModel.fromMap(Map<String, dynamic> map) {
    return EpisodeModel(
      id: map['id'] as String,
      seriesId: map['series_id'] as String,
      seasonNumber: (map['season_number'] as num?)?.toInt() ?? 1,
      episodeNumber: (map['episode_number'] as num?)?.toInt() ?? 1,
      title: map['title'] as String?,
      overview: map['overview'] as String?,
      stillPath: map['still_path'] as String?,
      runtime: (map['runtime'] as num?)?.toInt(),
      airDate: map['air_date'] as String?,
      videoUrl: map['video_url'] as String?,
      videoType: map['video_type'] as String?,
    );
  }
}
