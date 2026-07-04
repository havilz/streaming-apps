import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streaming_mobile/features/detail/data/data.dart';
import 'package:streaming_mobile/features/home/data/movie_model.dart';

// ── Repository ───────────────────────────────────────────────

final detailRepositoryProvider = Provider<DetailRepository>(
  (_) => const DetailRepository(),
);

// ── Detail konten ────────────────────────────────────────────

/// Provider untuk halaman detail film (tabel `movies`)
final movieDetailProvider = FutureProvider.family<MovieModel?, String>((
  ref,
  slug,
) async {
  return ref.read(detailRepositoryProvider).fetchMovieDetail(slug);
});

/// Provider untuk halaman detail series (tabel `series`)
final seriesDetailProvider = FutureProvider.family<SeriesModel?, String>((
  ref,
  slug,
) async {
  return ref.read(detailRepositoryProvider).fetchSeriesDetail(slug);
});

/// Provider untuk detail satu episode (tabel `episodes`)
final episodeDetailProvider = FutureProvider.family<EpisodeModel?, String>((
  ref,
  episodeId,
) async {
  return ref.read(detailRepositoryProvider).fetchEpisodeById(episodeId);
});

// ── Season aktif ─────────────────────────────────────────────

class ActiveSeasonNotifier extends Notifier<int> {
  @override
  int build() => 1;

  void set(int season) => state = season;
}

final _activeSeasonCache =
    <String, NotifierProvider<ActiveSeasonNotifier, int>>{};

NotifierProvider<ActiveSeasonNotifier, int> activeSeasonProviderFor(
  String slug,
) {
  return _activeSeasonCache.putIfAbsent(
    slug,
    () => NotifierProvider<ActiveSeasonNotifier, int>(
      () => ActiveSeasonNotifier(),
    ),
  );
}

// ── Daftar episode ───────────────────────────────────────────

final episodesProvider =
    FutureProvider.family<List<EpisodeModel>, ({String seriesId, int season})>((
      ref,
      args,
    ) async {
      return ref
          .read(detailRepositoryProvider)
          .fetchEpisodes(args.seriesId, seasonNumber: args.season);
    });

// ── Daftar season dari JSON string ───────────────────────────

final seasonsProvider = Provider.family<List<SeasonMeta>, String?>((
  ref,
  seasonsJson,
) {
  if (seasonsJson == null || seasonsJson.isEmpty) return [];
  try {
    final list = jsonDecode(seasonsJson) as List;
    return list
        .map((s) => SeasonMeta.fromMap(s as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return [];
  }
});

class SeasonMeta {
  const SeasonMeta({
    required this.seasonNumber,
    required this.name,
    this.episodeCount,
  });

  final int seasonNumber;
  final String name;
  final int? episodeCount;

  factory SeasonMeta.fromMap(Map<String, dynamic> map) {
    return SeasonMeta(
      seasonNumber: (map['seasonNumber'] as num?)?.toInt() ?? 1,
      name: map['name'] as String? ?? 'Season ${map['seasonNumber']}',
      episodeCount: (map['episodeCount'] as num?)?.toInt(),
    );
  }
}

// ── State unlock stream ───────────────────────────────────────

class StreamState {
  const StreamState({
    this.isLoading = false,
    this.result,
    this.error,
    this.step = 0,
  });

  final bool isLoading;
  final StreamResult? result;
  final String? error;

  /// 0=idle, 1=gate, 2=waiting, 3=claiming, 4=done
  final int step;

  bool get hasResult => result != null;

  StreamState copyWith({
    bool? isLoading,
    StreamResult? result,
    String? error,
    int? step,
  }) => StreamState(
    isLoading: isLoading ?? this.isLoading,
    result: result ?? this.result,
    error: error,
    step: step ?? this.step,
  );
}

// ── Stream notifier per episodeId ─────────────────────────────
// Karena Riverpod 3.x family Notifier butuh Notifier.new pattern
// dan kita butuh episodeId sebagai parameter, kita pakai provider
// cache manual agar setiap episodeId punya instance terpisah.

class StreamNotifier extends Notifier<StreamState> {
  StreamNotifier(this._episodeId);

  final String _episodeId;

  @override
  StreamState build() => const StreamState();

  Future<void> unlock({required String slug, required bool isMovie}) async {
    if (state.isLoading) return;
    state = const StreamState(isLoading: true, step: 1);
    state = state.copyWith(step: 2);

    final result = await ref
        .read(detailRepositoryProvider)
        .unlockStream(episodeId: _episodeId, slug: slug, isMovie: isMovie);

    state = result == null
        ? const StreamState(error: 'Gagal memuat stream. Coba lagi.')
        : StreamState(result: result, step: 4);
  }

  void reset() => state = const StreamState();
}

final _streamCache = <String, NotifierProvider<StreamNotifier, StreamState>>{};

/// Ambil atau buat provider stream untuk [episodeId] tertentu.
NotifierProvider<StreamNotifier, StreamState> streamProviderFor(
  String episodeId,
) {
  return _streamCache.putIfAbsent(
    episodeId,
    () => NotifierProvider<StreamNotifier, StreamState>(
      () => StreamNotifier(episodeId),
    ),
  );
}
