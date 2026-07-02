import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streaming_mobile/features/home/data/data.dart';

final homeRepositoryProvider = Provider<HomeRepository>(
  (_) => const HomeRepository(),
);

class HomeFilter {
  const HomeFilter({this.genre, this.year, this.contentType});

  final String? genre;
  final String? year;

  /// null = semua, 'movie', atau 'series'
  final String? contentType;

  HomeFilter copyWith({
    Object? genre = _sentinel,
    Object? year = _sentinel,
    Object? contentType = _sentinel,
  }) => HomeFilter(
    genre: genre == _sentinel ? this.genre : genre as String?,
    year: year == _sentinel ? this.year : year as String?,
    contentType: contentType == _sentinel
        ? this.contentType
        : contentType as String?,
  );

  static const _sentinel = Object();
}

final homeFilterProvider = NotifierProvider<HomeFilterNotifier, HomeFilter>(
  HomeFilterNotifier.new,
);

class HomeFilterNotifier extends Notifier<HomeFilter> {
  @override
  HomeFilter build() => const HomeFilter();

  void setGenre(String? genre) => state = state.copyWith(genre: genre);
  void setYear(String? year) => state = state.copyWith(year: year);
  void setContentType(String? type) =>
      state = state.copyWith(contentType: type);
  void reset() => state = const HomeFilter();
}

class HomeState {
  const HomeState({
    this.movies = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
    this.currentPage = 0,
  });

  final List<MovieModel> movies;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;
  final int currentPage;

  HomeState copyWith({
    List<MovieModel>? movies,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? error,
    int? currentPage,
  }) => HomeState(
    movies: movies ?? this.movies,
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
    // Reload saat filter berubah
    ref.listen(homeFilterProvider, (_, __) => reload());
    return const HomeState(isLoading: true);
  }

  /// Load halaman pertama (reset state)
  Future<void> reload() async {
    state = const HomeState(isLoading: true);
    try {
      final movies = await _repo.fetchMovies(
        page: 0,
        genre: _filter.genre,
        year: _filter.year,
        contentType: _filter.contentType,
      );
      state = HomeState(
        movies: movies,
        isLoading: false,
        hasMore: movies.length >= 20,
        currentPage: 0,
      );
    } catch (e) {
      state = HomeState(isLoading: false, error: e.toString());
    }
  }

  /// Load halaman berikutnya (infinite scroll)
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final nextPage = state.currentPage + 1;
      final more = await _repo.fetchMovies(
        page: nextPage,
        genre: _filter.genre,
        year: _filter.year,
        contentType: _filter.contentType,
      );
      state = state.copyWith(
        movies: [...state.movies, ...more],
        isLoadingMore: false,
        hasMore: more.length >= 20,
        currentPage: nextPage,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }
}

final availableGenresProvider = FutureProvider<List<String>>((ref) async {
  return ref.read(homeRepositoryProvider).fetchAvailableGenres();
});

final availableYearsProvider = FutureProvider<List<String>>((ref) async {
  return ref.read(homeRepositoryProvider).fetchAvailableYears();
});
