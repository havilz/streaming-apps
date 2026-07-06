import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streaming_mobile/features/home/data/data.dart';
import 'package:streaming_mobile/features/home/domain/home_provider.dart';

class MovieScreenState {
  const MovieScreenState({
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

  MovieScreenState copyWith({
    List<ContentItem>? heroItems,
    List<ContentItem>? trendingItems,
    List<UpdatedItem>? newUpdatedItems,
    Map<String, List<ContentItem>>? genreItems,
    Map<String, List<ContentItem>>? countryItems,
    bool? isLoading,
    String? error,
  }) => MovieScreenState(
    heroItems: heroItems ?? this.heroItems,
    trendingItems: trendingItems ?? this.trendingItems,
    newUpdatedItems: newUpdatedItems ?? this.newUpdatedItems,
    genreItems: genreItems ?? this.genreItems,
    countryItems: countryItems ?? this.countryItems,
    isLoading: isLoading ?? this.isLoading,
    error: error,
  );
}

final movieScreenProvider = NotifierProvider<MovieScreenNotifier, MovieScreenState>(
  MovieScreenNotifier.new,
);

class MovieScreenNotifier extends Notifier<MovieScreenState> {
  HomeRepository get _repo => ref.read(homeRepositoryProvider);

  @override
  MovieScreenState build() {
    return const MovieScreenState(isLoading: true);
  }

  Future<void> reload() async {
    state = const MovieScreenState(isLoading: true);
    try {
      // 1. Fetch latest movies for Hero (movies only)
      final heroMovies = await _repo.fetchMovies(page: 0, limit: 10);
      final heroItems = heroMovies.map(ContentItem.fromMovie).toList();

      // 2. Fetch large batch of 2026 movies
      final movies2026 = await _repo.fetchMovies(page: 0, year: '2026', limit: 100);

      // Filter: Year == 2026 AND voteAverage >= 7.0
      final trending = movies2026.map(ContentItem.fromMovie).where((item) {
        final hasYear2026 = item.year == '2026';
        final hasRating7 = item.voteAverage != null && item.voteAverage! >= 7.0;
        return hasYear2026 && hasRating7;
      }).toList();

      // Sort trending movies by rating descending
      trending.sort((a, b) {
        final rA = a.voteAverage ?? 0.0;
        final rB = b.voteAverage ?? 0.0;
        if (rB != rA) return rB.compareTo(rA);
        return b.id.compareTo(a.id);
      });

      // 3. Group by Genre (movies only)
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

      // 4. Group by Country (movies only)
      final countryMap = <String, List<ContentItem>>{};
      for (final item in trending) {
        for (final country in item.countries) {
          countryMap.putIfAbsent(country, () => []).add(item);
        }
      }

      // 5. Fetch newest movies for New Updated
      final newMovies = await _repo.fetchMovies(page: 0, limit: 100);

      bool isNewOr2026(String? dateStr) {
        if (dateStr != null && dateStr.length >= 4) {
          final year = int.tryParse(dateStr.substring(0, 4)) ?? 0;
          return year >= 2026;
        }
        return false;
      }

      final filteredMovies = newMovies
          .where((m) => isNewOr2026(m.releaseDate))
          .take(15)
          .toList();

      final newUpdated = filteredMovies.map((m) => UpdatedItem.fromMovie(m, createdAt: m.createdAt)).toList();

      state = MovieScreenState(
        heroItems: heroItems,
        trendingItems: trending,
        newUpdatedItems: newUpdated,
        genreItems: filteredGenreMap,
        countryItems: countryMap,
        isLoading: false,
      );
    } catch (e) {
      state = MovieScreenState(isLoading: false, error: e.toString());
    }
  }
}
