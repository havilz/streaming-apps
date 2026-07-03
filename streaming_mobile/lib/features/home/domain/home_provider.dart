import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streaming_mobile/features/home/data/data.dart';

// ── Repository ───────────────────────────────────────────────

final homeRepositoryProvider = Provider<HomeRepository>(
  (_) => const HomeRepository(),
);

// ── Filter state ─────────────────────────────────────────────

/// Tab konten: semua, movie saja, atau series saja
enum ContentTab { all, movies, series }

class HomeFilter {
  const HomeFilter({this.genreId, this.year, this.tab = ContentTab.all});

  /// ID genre dari tabel `genres` (null = semua genre)
  final int? genreId;
  final String? year;
  final ContentTab tab;

  HomeFilter copyWith({
    Object? genreId = _s,
    Object? year = _s,
    ContentTab? tab,
  }) => HomeFilter(
    genreId: genreId == _s ? this.genreId : genreId as int?,
    year: year == _s ? this.year : year as String?,
    tab: tab ?? this.tab,
  );

  static const _s = Object();
}

final homeFilterProvider = NotifierProvider<HomeFilterNotifier, HomeFilter>(
  HomeFilterNotifier.new,
);

class HomeFilterNotifier extends Notifier<HomeFilter> {
  @override
  HomeFilter build() => const HomeFilter();

  void setGenre(int? id) => state = state.copyWith(genreId: id);
  void setYear(String? year) => state = state.copyWith(year: year);
  void setTab(ContentTab tab) => state = state.copyWith(tab: tab);
  void reset() => state = const HomeFilter();
}

// ── Home state ───────────────────────────────────────────────

class HomeState {
  const HomeState({
    this.heroItems = const [],
    this.trendingItems = const [],
    this.genreItems = const {},
    this.networkItems = const {},
    this.isLoading = false,
    this.error,
  });

  final List<ContentItem> heroItems;
  final List<ContentItem> trendingItems;
  final Map<String, List<ContentItem>> genreItems;
  final Map<String, List<ContentItem>> networkItems;
  final bool isLoading;
  final String? error;

  HomeState copyWith({
    List<ContentItem>? heroItems,
    List<ContentItem>? trendingItems,
    Map<String, List<ContentItem>>? genreItems,
    Map<String, List<ContentItem>>? networkItems,
    bool? isLoading,
    String? error,
  }) => HomeState(
    heroItems: heroItems ?? this.heroItems,
    trendingItems: trendingItems ?? this.trendingItems,
    genreItems: genreItems ?? this.genreItems,
    networkItems: networkItems ?? this.networkItems,
    isLoading: isLoading ?? this.isLoading,
    error: error,
  );
}

final homeProvider = NotifierProvider<HomeNotifier, HomeState>(
  HomeNotifier.new,
);

class HomeNotifier extends Notifier<HomeState> {
  HomeRepository get _repo => ref.read(homeRepositoryProvider);

  @override
  HomeState build() {
    return const HomeState(isLoading: true);
  }

  Future<void> reload() async {
    state = const HomeState(isLoading: true);
    try {
      // 1. Fetch latest items for Hero (unrestricted)
      final heroMovies = await _repo.fetchMovies(page: 0, limit: 10);
      final heroSeries = await _repo.fetchSeries(page: 0, limit: 10);
      final heroCombined = [
        ...heroMovies.map(ContentItem.fromMovie),
        ...heroSeries.map(ContentItem.fromSeries),
      ]..sort((a, b) => b.id.compareTo(a.id));
      final heroItems = heroCombined.take(10).toList();

      // 2. Fetch large batch of 2026 content for sections
      final movies2026 = await _repo.fetchMovies(page: 0, year: '2026', limit: 100);
      final series2026 = await _repo.fetchSeries(page: 0, year: '2026', limit: 100);
      
      final all2026 = [
        ...movies2026.map(ContentItem.fromMovie),
        ...series2026.map(ContentItem.fromSeries),
      ];

      // Filter: Year == 2026 AND voteAverage >= 7.0
      final trending = all2026.where((item) {
        final hasYear2026 = item.year == '2026';
        final hasRating7 = item.voteAverage != null && item.voteAverage! >= 7.0;
        return hasYear2026 && hasRating7;
      }).toList();

      // Sort trending items by rating or ID (descending)
      trending.sort((a, b) {
        final rA = a.voteAverage ?? 0.0;
        final rB = b.voteAverage ?? 0.0;
        if (rB != rA) return rB.compareTo(rA);
        return b.id.compareTo(a.id);
      });

      // 3. Group by Genre
      final genreMap = <String, List<ContentItem>>{};
      for (final item in trending) {
        for (final genre in item.genres) {
          genreMap.putIfAbsent(genre, () => []).add(item);
        }
      }
      final popularGenres = ['Action', 'Comedy', 'Drama', 'Adventure', 'Science Fiction', 'Animation', 'Thriller'];
      final filteredGenreMap = <String, List<ContentItem>>{};
      for (final g in popularGenres) {
        final matchKey = genreMap.keys.firstWhere(
          (key) => key.toLowerCase() == g.toLowerCase(),
          orElse: () => '',
        );
        if (matchKey.isNotEmpty && genreMap[matchKey]!.isNotEmpty) {
          filteredGenreMap[matchKey] = genreMap[matchKey]!;
        }
      }
      if (filteredGenreMap.isEmpty) {
        genreMap.forEach((key, value) {
          if (value.isNotEmpty) filteredGenreMap[key] = value;
        });
      }

      // 4. Fetch network series using dedicated method (no year restriction, rating >= 7.0)
      final networkResults = await Future.wait([
        _repo.fetchSeriesByNetwork('Netflix', minRating: 7.0, limit: 50),
        // 'hbo' matches "HBO" and "HBO Max"; 'max' catches rebranded "Max"
        _repo.fetchSeriesByNetwork('hbo', minRating: 7.0, limit: 50),
        _repo.fetchSeriesByNetwork('Disney', minRating: 7.0, limit: 50),
      ]);

      // Merge HBO + Max results, deduplicate by id
      final hboBase = <String, ContentItem>{};
      for (final s in networkResults[1]) {
        final item = ContentItem.fromSeries(s);
        hboBase[item.id] = item;
      }
      // Also search for standalone 'Max' network (rebranded HBO Max)
      final maxSeries = await _repo.fetchSeriesByNetwork('Max', minRating: 7.0, limit: 50);
      for (final s in maxSeries) {
        final item = ContentItem.fromSeries(s);
        hboBase[item.id] = item;
      }

      final networkMap = <String, List<ContentItem>>{
        'Netflix': networkResults[0].map(ContentItem.fromSeries).toList(),
        'HBO': hboBase.values.toList()
          ..sort((a, b) => (b.voteAverage ?? 0).compareTo(a.voteAverage ?? 0)),
        'Disney+': networkResults[2].map(ContentItem.fromSeries).toList(),
      };

      state = HomeState(
        heroItems: heroItems,
        trendingItems: trending,
        genreItems: filteredGenreMap,
        networkItems: networkMap,
        isLoading: false,
      );
    } catch (e) {
      state = HomeState(isLoading: false, error: e.toString());
    }
  }
}

// ── Filter options providers ─────────────────────────────────

final availableGenresProvider = FutureProvider<List<({int id, String name})>>((
  ref,
) async {
  return ref.read(homeRepositoryProvider).fetchAvailableGenres();
});

final availableYearsProvider = FutureProvider<List<String>>((ref) async {
  return ref.read(homeRepositoryProvider).fetchAvailableYears();
});
