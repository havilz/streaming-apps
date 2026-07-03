/// Hasil unlock stream dari idlix (3-step Pentos flow).
class StreamResult {
  const StreamResult({
    required this.url,
    this.subtitles = const [],
    this.videoId,
    this.title,
  });

  /// URL HLS (.m3u8) yang siap diputar.
  final String url;

  /// Daftar subtitle yang tersedia.
  final List<SubtitleTrack> subtitles;

  final String? videoId;
  final String? title;

  factory StreamResult.fromMap(Map<String, dynamic> map) {
    final rawSubs = map['subtitles'] as List? ?? [];
    return StreamResult(
      url: map['url'] as String,
      subtitles: rawSubs
          .map((s) => SubtitleTrack.fromMap(s as Map<String, dynamic>))
          .toList(),
      videoId: map['videoId'] as String?,
      title: map['title'] as String?,
    );
  }
}

class SubtitleTrack {
  const SubtitleTrack({
    required this.lang,
    required this.label,
    required this.path,
  });

  final String lang;
  final String label;
  final String path;

  factory SubtitleTrack.fromMap(Map<String, dynamic> map) {
    return SubtitleTrack(
      lang: map['lang'] as String? ?? '',
      label: map['label'] as String? ?? '',
      path: map['path'] as String? ?? '',
    );
  }
}
