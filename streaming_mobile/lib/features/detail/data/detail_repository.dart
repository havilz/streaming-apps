import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:streaming_mobile/core/core.dart';
import 'package:streaming_mobile/features/detail/data/episode_model.dart';
import 'package:streaming_mobile/features/detail/data/stream_result.dart';
import 'package:streaming_mobile/features/home/data/movie_model.dart';

class DetailRepository {
  const DetailRepository();

  static const String _idlixBase = 'https://z2.idlixku.com';
  static const String _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36';

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

  /// Unlock stream URL via 3-step Pentos flow ke idlix.
  /// Catatan: akan diganti dengan Edge Function call di task 7
  /// untuk menghindari Cloudflare 403 di Android.
  Future<StreamResult?> unlockStream({
    required String episodeId,
    required String slug,
    required bool isMovie,
  }) async {
    try {
      final headers = _browserHeaders(slug, isMovie);
      final playInfoUrl = isMovie
          ? '$_idlixBase/api/watch/play-info/movie/$episodeId'
          : '$_idlixBase/api/watch/play-info/episode/$episodeId';

      final res1 = await http.get(Uri.parse(playInfoUrl), headers: headers);
      if (res1.statusCode != 200) return null;

      final body1 = jsonDecode(res1.body) as Map<String, dynamic>;
      if (body1.containsKey('url')) return StreamResult.fromMap(body1);

      final gateToken = body1['gateToken'] as String?;
      final serverNow = body1['serverNow'] as int?;
      final unlockAt = body1['unlockAt'] as int?;
      if (gateToken == null || serverNow == null || unlockAt == null) {
        return null;
      }

      final cookie = _extractCookie(res1.headers['set-cookie'] ?? '');
      final waitMs = (unlockAt - serverNow + 1500).clamp(0, 20000);
      await Future.delayed(Duration(milliseconds: waitMs));

      final res2 = await http.post(
        Uri.parse('$_idlixBase/api/watch/session/claim'),
        headers: {
          ...headers,
          'content-type': 'application/json',
          if (cookie.isNotEmpty) 'cookie': cookie,
        },
        body: jsonEncode({'gateToken': gateToken}),
      );
      if (res2.statusCode != 200) return null;

      final body2 = jsonDecode(res2.body) as Map<String, dynamic>;
      final claim = body2['claim'] as String?;
      final redeemUrl = body2['redeemUrl'] as String?;
      if (claim == null || redeemUrl == null) return null;

      final res3 = await http.post(
        Uri.parse(redeemUrl),
        headers: {'Content-Type': 'text/plain', 'User-Agent': _ua},
        body: jsonEncode({'claim': claim}),
      );
      if (res3.statusCode != 200) return null;

      final body3 = jsonDecode(res3.body) as Map<String, dynamic>;
      if (body3['url'] == null) return null;

      return StreamResult.fromMap(body3);
    } catch (_) {
      return null;
    }
  }

  Map<String, String> _browserHeaders(String slug, bool isMovie) {
    final referer = isMovie
        ? '$_idlixBase/movie/$slug'
        : '$_idlixBase/series/$slug/season/1/episode/1';
    return {
      'User-Agent': _ua,
      'Accept': 'application/json, text/plain, */*',
      'Accept-Language': 'en-US,en;q=0.9,id;q=0.8',
      'Referer': referer,
      'Origin': _idlixBase,
    };
  }

  String _extractCookie(String rawSetCookie) {
    if (rawSetCookie.isEmpty) return '';
    return rawSetCookie.split(';')[0].trim();
  }
}
