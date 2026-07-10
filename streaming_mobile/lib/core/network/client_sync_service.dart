import 'dart:convert';
import 'dart:io';
import 'package:streaming_mobile/core/core.dart';

class ClientSyncService {
  ClientSyncService._();

  static final _baseUrl = const String.fromEnvironment('IDLIX_BASE_URL', defaultValue: 'https://z2.idlixku.com');

  /// Check if the global home page sync is allowed (cooldown of 30 minutes).
  static Future<bool> shouldSyncGlobal() async {
    try {
      final tempFile = File('${Directory.systemTemp.path}/last_sync_time.txt');
      if (!await tempFile.exists()) return true;
      final content = await tempFile.readAsString();
      final lastSync = DateTime.parse(content.trim());
      return DateTime.now().difference(lastSync) > const Duration(minutes: 30);
    } catch (_) {
      return true;
    }
  }

  /// Mark global sync as successfully completed.
  static Future<void> markGlobalSynced() async {
    try {
      final tempFile = File('${Directory.systemTemp.path}/last_sync_time.txt');
      await tempFile.writeAsString(DateTime.now().toIso8601String());
    } catch (_) {}
  }

  /// Check if targeted sync for a specific series is allowed (cooldown of 5 minutes).
  static Future<bool> shouldSyncSeries(String seriesId) async {
    try {
      final tempFile = File('${Directory.systemTemp.path}/last_sync_series_$seriesId.txt');
      if (!await tempFile.exists()) return true;
      final content = await tempFile.readAsString();
      final lastSync = DateTime.parse(content.trim());
      return DateTime.now().difference(lastSync) > const Duration(minutes: 5);
    } catch (_) {
      return true;
    }
  }

  /// Mark targeted series sync as successfully completed.
  static Future<void> markSeriesSynced(String seriesId) async {
    try {
      final tempFile = File('${Directory.systemTemp.path}/last_sync_series_$seriesId.txt');
      await tempFile.writeAsString(DateTime.now().toIso8601String());
    } catch (_) {}
  }

  /// Level 1: Global Background Sync (Home Screen)
  static Future<void> syncGlobal() async {
    if (!await shouldSyncGlobal()) {
      print('[ClientSyncService] Global sync skipped due to 30-minute cooldown.');
      return;
    }

    print('[ClientSyncService] Running global sync...');
    try {
      // Sync Movies Page 1
      try {
        final url = '$_baseUrl/api/movies?page=1&limit=24';
        final body = await CloudflareBypassService.instance.fetchInWebView(url);
        if (body != null && !body.startsWith('ERROR:')) {
          final data = jsonDecode(body) as Map<String, dynamic>;
          final items = (data['data'] as List?) ?? [];
          
          for (var item in items) {
            await supabaseClient.from('movies').upsert({
              'id': item['id'].toString(),
              'title': item['title'],
              'slug': item['slug'],
              'poster_path': item['posterPath'],
              'backdrop_path': item['backdropPath'],
              'release_date': item['releaseDate'] ?? item['firstAirDate'],
              'vote_average': item['voteAverage'] != null ? double.tryParse(item['voteAverage'].toString()) : null,
              'quality': item['quality'],
            });
          }
          print('[ClientSyncService] Synced ${items.length} movies.');
        } else {
          throw Exception('Movies API returned error: $body');
        }
      } catch (e) {
        print('[ClientSyncService] Failed to sync movies: $e');
      }

      // Sync Series Page 1
      try {
        final url = '$_baseUrl/api/series?page=1&limit=24';
        final body = await CloudflareBypassService.instance.fetchInWebView(url);
        if (body != null && !body.startsWith('ERROR:')) {
          final data = jsonDecode(body) as Map<String, dynamic>;
          final items = (data['data'] as List?) ?? [];
          
          for (var item in items) {
            await supabaseClient.from('series').upsert({
              'id': item['id'].toString(),
              'title': item['title'],
              'slug': item['slug'],
              'poster_path': item['posterPath'],
              'backdrop_path': item['backdropPath'],
              'first_air_date': item['releaseDate'] ?? item['firstAirDate'],
              'vote_average': item['voteAverage'] != null ? double.tryParse(item['voteAverage'].toString()) : null,
              'quality': item['quality'],
            });
          }
          print('[ClientSyncService] Synced ${items.length} series.');
        } else {
          throw Exception('Series API returned error: $body');
        }
      } catch (e) {
        print('[ClientSyncService] Failed to sync series: $e');
      }

      await markGlobalSynced();
      print('[ClientSyncService] Global sync completed successfully.');
    } catch (e) {
      print('[ClientSyncService] Error during global sync: $e');
    }
  }

  /// Level 2: Just-In-Time (JIT) Targeted Sync (Series Detail Screen)
  static Future<void> syncSeriesEpisodes(String seriesId, String seriesSlug) async {
    if (!await shouldSyncSeries(seriesId)) {
      print('[ClientSyncService] Series $seriesSlug sync skipped due to 5-minute cooldown.');
      return;
    }

    print('[ClientSyncService] Running JIT series sync for $seriesSlug...');
    try {
      // 1. Fetch series detail to get number of seasons
      final detailUrl = '$_baseUrl/api/series/$seriesSlug';
      final detailBody = await CloudflareBypassService.instance.fetchInWebView(detailUrl);
      
      if (detailBody != null && !detailBody.startsWith('ERROR:')) {
        final detailData = jsonDecode(detailBody) as Map<String, dynamic>;
        
        // Update number of seasons in db
        final seasonsList = (detailData['seasons'] as List?) ?? [];
        await supabaseClient.from('series').update({
          'number_of_seasons': seasonsList.isNotEmpty ? seasonsList.length : 1,
        }).eq('id', seriesId);

        // 2. Fetch and upsert episodes for each season
        for (var season in seasonsList) {
          final seasonNumber = season['seasonNumber'] ?? 1;
          final epUrl = '$_baseUrl/api/series/$seriesSlug/season/$seasonNumber';
          final epBody = await CloudflareBypassService.instance.fetchInWebView(epUrl);

          if (epBody != null && !epBody.startsWith('ERROR:')) {
            final epData = jsonDecode(epBody) as Map<String, dynamic>;
            final episodes = (epData['season']?['episodes'] as List?) ?? [];

            for (var ep in episodes) {
              await supabaseClient.from('episodes').upsert({
                'id': ep['id'].toString(),
                'series_id': seriesId,
                'season_number': seasonNumber,
                'episode_number': ep['episodeNumber'] ?? 1,
                'title': ep['name'],
                'overview': ep['overview'],
                'still_path': ep['stillPath'],
                'runtime': ep['runtime'] != null ? int.tryParse(ep['runtime'].toString()) : null,
                'air_date': ep['airDate'],
              });
            }
            print('[ClientSyncService] Synced ${episodes.length} episodes for season $seasonNumber of $seriesSlug.');
          }
          await Future.delayed(const Duration(milliseconds: 200));
        }
      } else {
        throw Exception('Series detail API returned error: $detailBody');
      }

      await markSeriesSynced(seriesId);
      print('[ClientSyncService] JIT series sync completed for $seriesSlug.');
    } catch (e) {
      print('[ClientSyncService] Error during series JIT sync: $e');
    }
  }
}
