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
    this.items = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
    this.currentPage = 0,
  });

  final List<ContentItem> items;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;
  final int currentPage;

  HomeState copyWith({
    List<ContentItem>? items,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? error,
    int? currentPage,
  }) => HomeState(
    items: items ?? this.items,
    isLoading: isLoading ?? this.isLoading,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    hasMore: hasMore ?? this.hasMore,
    error: error,
    currentPage: currentPage ?? this.currentPage,
  );
}

final homeProvider = NotifierProvider<HomeNotifier, HomeState>(
  HomeNotifier.new,
);

class HomeNotifier extends Notifier<HomeState> {
  HomeRepository get _repo => ref.read(homeRepositoryProvider);
  HomeFilter get _filter => ref.read(homeFilterProvider);

  @override
  HomeState build() {
    ref.listen(homeFilterProvider, (_, __) => reload());
    return const HomeState(isLoading: true);
  }

  Future<void> reload() async {
    state = const HomeState(isLoading: true);
    try {
      final items = await _fetchPage(0);
      state = HomeState(
        items: items,
        isLoading: false,
        hasMore: items.length >= 20,
        currentPage: 0,
      );
    } catch (e) {
      state = HomeState(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final nextPage = state.currentPage + 1;
      final more = await _fetchPage(nextPage);

      // Deduplicate
      final seen = <String>{};
      final merged = [
        ...state.items,
        ...more,
      ].where((i) => seen.add(i.id)).toList();

      state = state.copyWith(
        items: merged,
        isLoadingMore: false,
        hasMore: more.length >= 20,
        currentPage: nextPage,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }

  /// Fetch halaman sesuai tab aktif — movies, series, atau keduanya
  Future<List<ContentItem>> _fetchPage(int page) async {
    final f = _filter;

    switch (f.tab) {
      case ContentTab.movies:
        final movies = await _repo.fetchMovies(
          page: page,
          genreId: f.genreId,
          year: f.year,
        );
        return movies.map(ContentItem.fromMovie).toList();

      case ContentTab.series:
        final series = await _repo.fetchSeries(
          page: page,
          genreId: f.genreId,
          year: f.year,
        );
        return series.map(ContentItem.fromSeries).toList();

      case ContentTab.all:
        // Ambil movies dan series secara parallel, lalu merge & sort
        final results = await Future.wait([
          _repo.fetchMovies(page: page, genreId: f.genreId, year: f.year),
          _repo.fetchSeries(page: page, genreId: f.genreId, year: f.year),
        ]);
        final movies = (results[0] as List<MovieModel>)
            .map(ContentItem.fromMovie)
            .toList();
        final series = (results[1] as List<SeriesModel>)
            .map(ContentItem.fromSeries)
            .toList();
        // Interleave: 1 movie, 1 series, dst
        final merged = <ContentItem>[];
        final maxLen = movies.length > series.length
            ? movies.length
            : series.length;
        for (int i = 0; i < maxLen; i++) {
          if (i < movies.length) merged.add(movies[i]);
          if (i < series.length) merged.add(series[i]);
        }
        return merged;
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
