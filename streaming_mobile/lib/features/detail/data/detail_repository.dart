import 'package:streaming_mobile/core/core.dart';
import 'package:streaming_mobile/features/detail/data/episode_model.dart';
import 'package:streaming_mobile/features/detail/data/stream_result.dart';
import 'package:streaming_mobile/features/home/data/movie_model.dart';

class DetailRepository {
  const DetailRepository();

  /// Ambil detail film berdasarkan slug dari tabel `movies`.
  Future<MovieModel?> fetchMovieDetail(String slug) async {
    final data = await supabaseClient
        .from(ApiEndpoints.movies)
        .select('*, movie_genres(genres(name))')
        .eq('slug', slug)
        .maybeSingle();
    if (data == null) return null;
    return MovieModel.fromMap(data);
  }

  /// Ambil detail series berdasarkan slug dari tabel `series`.
  Future<SeriesModel?> fetchSeriesDetail(String slug) async {
    final data = await supabaseClient
        .from(ApiEndpoints.series)
        .select(
          '*, series_genres(genres(name)), series_networks(networks(name))',
        )
        .eq('slug', slug)
        .maybeSingle();
    if (data == null) return null;
    return SeriesModel.fromMap(data);
  }

  /// Ambil daftar episode untuk satu season dari tabel `episodes`.
  Future<List<EpisodeModel>> fetchEpisodes(
    String seriesId, {
    int seasonNumber = 1,
  }) async {
    final data = await supabaseClient
        .from(ApiEndpoints.episodes)
        .select()
        .eq('series_id', seriesId)
        .eq('season_number', seasonNumber)
        .order('episode_number');
    return (data as List).map((e) => EpisodeModel.fromMap(e)).toList();
  }

  /// Unlock stream URL via Supabase Edge Function `unlock-stream`.
  /// Edge Function menjalankan 3-step Pentos flow di server
  /// sehingga tidak terkena Cloudflare 403 di Android.
  Future<StreamResult?> unlockStream({
    required String episodeId,
    required String slug,
    required bool isMovie,
  }) async {
    try {
      final response = await supabaseClient.functions.invoke(
        ApiEndpoints.unlockStream,
        body: {'episodeId': episodeId, 'slug': slug, 'isMovie': isMovie},
      );

      if (response.data == null) return null;
      final data = response.data as Map<String, dynamic>;
      if (data.containsKey('error')) return null;

      return StreamResult.fromMap(data);
    } catch (_) {
      return null;
    }
  }

  /// Trigger sync manual via Edge Function `sync-content`.
  Future<({int synced, String message})?> triggerSync({
    String mode = 'new',
    required String secret,
  }) async {
    try {
      final response = await supabaseClient.functions.invoke(
        ApiEndpoints.syncContent,
        body: {'mode': mode, 'secret': secret},
      );
      if (response.data == null) return null;
      final data = response.data as Map<String, dynamic>;
      return (
        synced: (data['synced'] as num?)?.toInt() ?? 0,
        message: data['message'] as String? ?? '',
      );
    } catch (_) {
      return null;
    }
  }
}
