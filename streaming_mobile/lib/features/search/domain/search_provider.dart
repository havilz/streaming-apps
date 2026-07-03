import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streaming_mobile/features/home/data/movie_model.dart';
import 'package:streaming_mobile/features/search/data/search_repository.dart';

// ── Repository ───────────────────────────────────────────────

final searchRepositoryProvider = Provider<SearchRepository>(
  (_) => const SearchRepository(),
);

// ── Search state ─────────────────────────────────────────────

class SearchState {
  const SearchState({
    this.query = '',
    this.results = const [],
    this.isLoading = false,
    this.error,
    this.hasSearched = false,
  });

  final String query;
  final List<ContentItem> results;
  final bool isLoading;
  final String? error;

  /// True setelah user pernah mengetik dan search dijalankan
  final bool hasSearched;

  SearchState copyWith({
    String? query,
    List<ContentItem>? results,
    bool? isLoading,
    String? error,
    bool? hasSearched,
  }) => SearchState(
    query: query ?? this.query,
    results: results ?? this.results,
    isLoading: isLoading ?? this.isLoading,
    error: error,
    hasSearched: hasSearched ?? this.hasSearched,
  );
}

// ── Search notifier ───────────────────────────────────────────

class SearchNotifier extends Notifier<SearchState> {
  @override
  SearchState build() => const SearchState();

  Future<void> search(String query) async {
    state = state.copyWith(query: query, isLoading: true, hasSearched: true);

    if (query.trim().isEmpty) {
      state = const SearchState(hasSearched: false);
      return;
    }

    try {
      final results = await ref.read(searchRepositoryProvider).search(query);
      state = state.copyWith(results: results, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void clear() => state = const SearchState();
}

final searchProvider = NotifierProvider<SearchNotifier, SearchState>(
  SearchNotifier.new,
);
