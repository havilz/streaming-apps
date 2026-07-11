import 'dart:convert';
import 'dart:io';
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

  /// Ambil detail satu episode berdasarkan ID.
  Future<EpisodeModel?> fetchEpisodeById(String episodeId) async {
    final data = await supabaseClient
        .from(ApiEndpoints.episodes)
        .select()
        .eq('id', episodeId)
        .maybeSingle();
    if (data == null) return null;
    return EpisodeModel.fromMap(data);
  }


  /// Unlock stream URL via client-side Pentos flow inside headless WebView.
  Future<StreamResult?> unlockStream({
    required String episodeId,
    required String slug,
    required bool isMovie,
  }) async {
    final baseUrl = const String.fromEnvironment('IDLIX_BASE_URL', defaultValue: 'https://z2.idlixku.com');
    String activeEpisodeId = episodeId;

    final session = WebViewSession();
    try {
      await session.init();

      // Resolusi fallback TMDB
      if (!isMovie && episodeId.startsWith("tmdb-")) {
        final match = RegExp(r's(\d+)e(\d+)$').firstMatch(episodeId);
        if (match != null) {
          final seasonNumber = match.group(1)!;
          final episodeNumber = int.parse(match.group(2)!);
          print('[DetailRepository] TMDB fallback episode ID: $episodeId. Resolving for S$seasonNumber E$episodeNumber...');
          try {
            final url = '$baseUrl/api/series/$slug/season/$seasonNumber';
            final jsonStr = await session.fetch(url);
            if (jsonStr != null && !jsonStr.startsWith('ERROR:')) {
              final data = jsonDecode(jsonStr) as Map<String, dynamic>;
              final episodesList = (data['season']?['episodes'] as List?) ?? [];
              final matchedEpisode = episodesList.firstWhere(
                (ep) => ep['episodeNumber'] == episodeNumber,
                orElse: () => null,
              );
              if (matchedEpisode != null && matchedEpisode['id'] != null) {
                print('[DetailRepository] Resolved IDLIX ID: ${matchedEpisode['id']}');
                activeEpisodeId = matchedEpisode['id'].toString();
              } else {
                throw Exception('Episode $episodeNumber not found on IDLIX S$seasonNumber');
              }
            } else {
              throw Exception('Failed to fetch IDLIX episodes via WebView: $jsonStr');
            }
          } catch (e) {
            print('[DetailRepository] Error resolving IDLIX ID: $e');
            return null;
          }
        }
      }

      final playInfoUrl = isMovie
          ? '$baseUrl/api/watch/play-info/movie/$activeEpisodeId'
          : '$baseUrl/api/watch/play-info/episode/$activeEpisodeId';

      // Step 1: Gate Token
      print('[DetailRepository] Step 1: Requesting play-info from $playInfoUrl');
      final body1Str = await session.fetch(playInfoUrl);
      if (body1Str == null || body1Str.startsWith('ERROR:')) {
        throw Exception('Step 1 failed: $body1Str');
      }
      
      final body1 = jsonDecode(body1Str) as Map<String, dynamic>;
      
      if (body1.containsKey('url') && body1['url'] != null) {
        print('[DetailRepository] Stream already unlocked directly.');
        return StreamResult.fromMap(body1);
      }

      final gateToken = body1['gateToken'];
      final serverNow = body1['serverNow'];
      final unlockAt = body1['unlockAt'];

      if (gateToken == null || serverNow == null || unlockAt == null) {
        throw Exception('Invalid gate response');
      }

      // Step 2: Wait for countdown + 1.5s buffer
      final waitMs = (((unlockAt as num) - (serverNow as num)) * 1000 + 1500).clamp(0, 20000).toInt();
      print('[DetailRepository] Step 2: Waiting for countdown of $waitMs ms...');
      await Future.delayed(Duration(milliseconds: waitMs));

      // Step 3: Claim Session
      final claimUrl = '$baseUrl/api/watch/session/claim';
      print('[DetailRepository] Step 3: Claiming session at $claimUrl');
      final body2Str = await session.fetch(
        claimUrl,
        method: 'POST',
        body: jsonEncode({'gateToken': gateToken}),
      );
      if (body2Str == null || body2Str.startsWith('ERROR:')) {
        throw Exception('Step 2 failed: $body2Str');
      }

      final body2 = jsonDecode(body2Str) as Map<String, dynamic>;
      final claim = body2['claim'];
      final redeemUrl = body2['redeemUrl'];

      if (claim == null || redeemUrl == null) {
        throw Exception('Invalid claim response');
      }

      // Step 4: Redeem
      print('[DetailRepository] Step 4: Redeeming at $redeemUrl');
      final body3Str = await session.fetch(
        redeemUrl,
        method: 'POST',
        body: jsonEncode({'claim': claim}),
      );
      if (body3Str == null || body3Str.startsWith('ERROR:')) {
        throw Exception('Step 3 failed: $body3Str');
      }

      final body3 = jsonDecode(body3Str) as Map<String, dynamic>;
      if (body3['url'] == null) {
        throw Exception('No URL in redeem response');
      }

      print('[DetailRepository] Unlocking completed successfully!');
      return StreamResult.fromMap(body3);
    } catch (e, stack) {
      print('[DetailRepository] Error unlocking stream: $e\n$stack');
      return null;
    } finally {
      await session.dispose();
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
