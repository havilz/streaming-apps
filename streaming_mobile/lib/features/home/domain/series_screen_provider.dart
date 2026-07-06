import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streaming_mobile/features/home/data/data.dart';
import 'package:streaming_mobile/features/home/domain/home_provider.dart';

class SeriesScreenState {
  const SeriesScreenState({
    this.heroItems = const [],
    this.trendingItems = const [],
    this.newUpdatedItems = const [],
    this.genreItems = const {},
    this.countryItems = const {},
    this.isLoading = false,
    this.error,
  });

  final List<ContentItem> heroItems;
  final List<ContentItem> trendingItems;
  final List<UpdatedItem> newUpdatedItems;
  final Map<String, List<ContentItem>> genreItems;
  final Map<String, List<ContentItem>> countryItems;
  final bool isLoading;
  final String? error;

  SeriesScreenState copyWith({
    List<ContentItem>? heroItems,
    List<ContentItem>? trendingItems,
    List<UpdatedItem>? newUpdatedItems,
    Map<String, List<ContentItem>>? genreItems,
    Map<String, List<ContentItem>>? countryItems,
    bool? isLoading,
    String? error,
  }) => SeriesScreenState(
    heroItems: heroItems ?? this.heroItems,
    trendingItems: trendingItems ?? this.trendingItems,
    newUpdatedItems: newUpdatedItems ?? this.newUpdatedItems,
    genreItems: genreItems ?? this.genreItems,
    countryItems: countryItems ?? this.countryItems,
    isLoading: isLoading ?? this.isLoading,
    error: error,
  );
}

final seriesScreenProvider = NotifierProvider<SeriesScreenNotifier, SeriesScreenState>(
  SeriesScreenNotifier.new,
);

class SeriesScreenNotifier extends Notifier<SeriesScreenState> {
  HomeRepository get _repo => ref.read(homeRepositoryProvider);

  @override
  SeriesScreenState build() {
    return const SeriesScreenState(isLoading: true);
  }

  Future<void> reload() async {
    state = const SeriesScreenState(isLoading: true);
    try {
      // 1. Fetch latest series for Hero (series only)
      final heroSeries = await _repo.fetchSeries(page: 0, limit: 10);
      final heroItems = heroSeries.map(ContentItem.fromSeries).toList();

      // 2. Fetch large batch of 2026 series
      final series2026 = await _repo.fetchSeries(page: 0, year: '2026', limit: 100);

      // Filter: Year == 2026 AND voteAverage >= 7.0
      final trending = series2026.map(ContentItem.fromSeries).where((item) {
        final hasYear2026 = item.year == '2026';
        final hasRating7 = item.voteAverage != null && item.voteAverage! >= 7.0;
        return hasYear2026 && hasRating7;
      }).toList();

      // Sort trending series by rating descending
      trending.sort((a, b) {
        final rA = a.voteAverage ?? 0.0;
        final rB = b.voteAverage ?? 0.0;
        if (rB != rA) return rB.compareTo(rA);
        return b.id.compareTo(a.id);
      });

      // 3. Group by Genre (series only)
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

      // 4. Group by Country (series only)
      final countryMap = <String, List<ContentItem>>{};
      for (final item in trending) {
        for (final country in item.countries) {
          countryMap.putIfAbsent(country, () => []).add(item);
        }
      }

      // 5. Fetch newest series and episodes for New Updated
      final newSeries = await _repo.fetchSeries(page: 0, limit: 15);
      final newEpisodes = await _repo.fetchNewestEpisodes(limit: 15);

      final newUpdated = <UpdatedItem>[
        ...newSeries.map((s) => UpdatedItem.fromSeries(s, createdAt: s.createdAt)),
        ...newEpisodes,
      ];
      newUpdated.sort((a, b) {
        final dateA = a.createdAt ?? '';
        final dateB = b.createdAt ?? '';
        return dateB.compareTo(dateA); // newest first
      });

      state = SeriesScreenState(
        heroItems: heroItems,
        trendingItems: trending,
        newUpdatedItems: newUpdated,
        genreItems: filteredGenreMap,
        countryItems: countryMap,
        isLoading: false,
      );
    } catch (e) {
      state = SeriesScreenState(isLoading: false, error: e.toString());
    }
  }
}
