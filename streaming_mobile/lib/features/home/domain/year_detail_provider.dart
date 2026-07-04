import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streaming_mobile/features/home/data/data.dart';
import 'package:streaming_mobile/features/home/domain/home_provider.dart';

class YearDetailState {
  const YearDetailState({
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

final yearDetailProvider = FutureProvider.family<YearDetailState, String>((ref, year) async {
  final repo = ref.read(homeRepositoryProvider);
  try {
    final results = await Future.wait([
      repo.fetchMoviesByYear(year, limit: 100),
      repo.fetchSeriesByYear(year, limit: 100),
    ]);

    final movies = (results[0] as List<MovieModel>).map(ContentItem.fromMovie).toList();
    final series = (results[1] as List<SeriesModel>).map(ContentItem.fromSeries).toList();
    final combined = [...movies, ...series];

    final heroItems = List<ContentItem>.from(combined);
    heroItems.sort((a, b) {
      final rA = a.voteAverage ?? 0.0;
      final rB = b.voteAverage ?? 0.0;
      return rB.compareTo(rA);
    });
    final topHero = heroItems.take(10).toList();

    final trending = combined.where((item) {
      final hasRating7 = item.voteAverage != null && item.voteAverage! >= 7.0;
      return hasRating7;
    }).toList();
    trending.sort((a, b) => (b.voteAverage ?? 0.0).compareTo(a.voteAverage ?? 0.0));

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

    final countryItems = combined.where((item) {
      final hasRating7 = item.voteAverage != null && item.voteAverage! >= 7.0;
      return hasRating7;
    }).toList();
    countryItems.sort((a, b) => (b.voteAverage ?? 0.0).compareTo(a.voteAverage ?? 0.0));
    final topCountry = countryItems.take(15).toList();

    return YearDetailState(
      heroItems: topHero,
      trendingItems: trending,
      netflixItems: netflixSeries,
      hboItems: hboSeries,
      disneyItems: disneySeries,
      bestCountryItems: topCountry,
      isLoading: false,
    );
  } catch (e) {
    return YearDetailState(
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
