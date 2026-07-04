import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streaming_mobile/features/home/data/data.dart';
import 'package:streaming_mobile/features/home/domain/home_provider.dart';

class GenreDetailState {
  const GenreDetailState({
    required this.heroItems,
    required this.trendingItems,
    required this.netflixItems,
    required this.hboItems,
    required this.disneyItems,
    required this.bestCountryItems,
    required this.isLoading,
    this.error,
  });

  final List<ContentItem> heroItems;
  final List<ContentItem> trendingItems;
  final List<ContentItem> netflixItems;
  final List<ContentItem> hboItems;
  final List<ContentItem> disneyItems;
  final List<ContentItem> bestCountryItems;
  final bool isLoading;
  final String? error;
}

final genreDetailProvider = FutureProvider.family<GenreDetailState, int>((ref, genreId) async {
  final repo = ref.read(homeRepositoryProvider);
  try {
    // 1. Fetch movies and series of this genre in parallel
    final results = await Future.wait([
      repo.fetchMoviesByGenre(genreId, limit: 100),
      repo.fetchSeriesByGenre(genreId, limit: 100),
    ]);

    final movies = (results[0] as List<MovieModel>).map(ContentItem.fromMovie).toList();
    final series = (results[1] as List<SeriesModel>).map(ContentItem.fromSeries).toList();

    final combined = [...movies, ...series];

    // Curate Hero items: Top 10 newest items
    final heroItems = List<ContentItem>.from(combined);
    heroItems.sort((a, b) {
      final yA = int.tryParse(a.year ?? '') ?? 0;
      final yB = int.tryParse(b.year ?? '') ?? 0;
      return yB.compareTo(yA);
    });
    final topHero = heroItems.take(10).toList();

    // Curate Trending Items: Year 2026 AND rating >= 7.0
    final trending = combined.where((item) {
      final isYear2026 = item.year == '2026';
      final hasRating7 = item.voteAverage != null && item.voteAverage! >= 7.0;
      return isYear2026 && hasRating7;
    }).toList();

    // Sort trending by rating desc
    trending.sort((a, b) => (b.voteAverage ?? 0.0).compareTo(a.voteAverage ?? 0.0));

    // Curate Netflix, HBO, Disney+ (series of this genre & network, rating >= 7.0)
    final netflixSeries = series.where((item) {
      final hasNetwork = item.networks.any((n) => n.toLowerCase().contains('netflix'));
      final hasRating7 = item.voteAverage != null && item.voteAverage! >= 7.0;
      return hasNetwork && hasRating7;
    }).toList();

    final hboSeries = series.where((item) {
      final hasNetwork = item.networks.any((n) => n.toLowerCase().contains('hbo') || n.toLowerCase().contains('max'));
      final hasRating7 = item.voteAverage != null && item.voteAverage! >= 7.0;
      return hasNetwork && hasRating7;
    }).toList();

    final disneySeries = series.where((item) {
      final hasNetwork = item.networks.any((n) => n.toLowerCase().contains('disney'));
      final hasRating7 = item.voteAverage != null && item.voteAverage! >= 7.0;
      return hasNetwork && hasRating7;
    }).toList();

    // Curate Best in Country: Combined, rating >= 7.0, max 15 items, sorted by rating desc
    final countryItems = combined.where((item) {
      final hasRating7 = item.voteAverage != null && item.voteAverage! >= 7.0;
      return hasRating7;
    }).toList();
    countryItems.sort((a, b) => (b.voteAverage ?? 0.0).compareTo(a.voteAverage ?? 0.0));
    final topCountry = countryItems.take(15).toList();

    return GenreDetailState(
      heroItems: topHero,
      trendingItems: trending,
      netflixItems: netflixSeries,
      hboItems: hboSeries,
      disneyItems: disneySeries,
      bestCountryItems: topCountry,
      isLoading: false,
    );
  } catch (e) {
    return GenreDetailState(
      heroItems: const [],
      trendingItems: const [],
      netflixItems: const [],
      hboItems: const [],
      disneyItems: const [],
      bestCountryItems: const [],
      isLoading: false,
      error: e.toString(),
    );
  }
});
