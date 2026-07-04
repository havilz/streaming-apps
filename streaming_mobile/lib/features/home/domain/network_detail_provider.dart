import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streaming_mobile/features/home/data/data.dart';
import 'package:streaming_mobile/features/home/domain/home_provider.dart';

class NetworkDetailState {
  const NetworkDetailState({
    required this.heroItems,
    required this.trendingItems,
    required this.bestGenreItems,
    required this.bestCountryItems,
    required this.isLoading,
    this.error,
  });

  final List<ContentItem> heroItems;
  final List<ContentItem> trendingItems;
  final List<ContentItem> bestGenreItems;
  final List<ContentItem> bestCountryItems;
  final bool isLoading;
  final String? error;
}

final networkDetailProvider = FutureProvider.family<NetworkDetailState, String>((ref, networkName) async {
  final repo = ref.read(homeRepositoryProvider);
  try {
    // Fetch series of this network
    final series = await repo.fetchSeriesByNetwork(networkName, limit: 100);
    final items = series.map(ContentItem.fromSeries).toList();

    // Hero items: Top 10 newest items
    final heroItems = List<ContentItem>.from(items);
    heroItems.sort((a, b) {
      final yA = int.tryParse(a.year ?? '') ?? 0;
      final yB = int.tryParse(b.year ?? '') ?? 0;
      return yB.compareTo(yA);
    });
    final topHero = heroItems.take(10).toList();

    // Trending Items: 2026, rating >= 7.0
    final trending = items.where((item) {
      final isYear2026 = item.year == '2026';
      final hasRating7 = item.voteAverage != null && item.voteAverage! >= 7.0;
      return isYear2026 && hasRating7;
    }).toList();
    trending.sort((a, b) => (b.voteAverage ?? 0.0).compareTo(a.voteAverage ?? 0.0));

    // Best in Genre: rating >= 7.0, max 15 items
    final genreItems = items.where((item) {
      final hasRating7 = item.voteAverage != null && item.voteAverage! >= 7.0;
      return hasRating7;
    }).toList();
    genreItems.sort((a, b) => (b.voteAverage ?? 0.0).compareTo(a.voteAverage ?? 0.0));
    final topGenre = genreItems.take(15).toList();

    // Best in Country: rating >= 7.0, max 15 items
    final countryItems = items.where((item) {
      final hasRating7 = item.voteAverage != null && item.voteAverage! >= 7.0;
      return hasRating7;
    }).toList();
    countryItems.sort((a, b) => (b.voteAverage ?? 0.0).compareTo(a.voteAverage ?? 0.0));
    final topCountry = countryItems.take(15).toList();

    return NetworkDetailState(
      heroItems: topHero,
      trendingItems: trending,
      bestGenreItems: topGenre,
      bestCountryItems: topCountry,
      isLoading: false,
    );
  } catch (e) {
    return NetworkDetailState(
      heroItems: const [],
      trendingItems: const [],
      bestGenreItems: const [],
      bestCountryItems: const [],
      isLoading: false,
      error: e.toString(),
    );
  }
});
