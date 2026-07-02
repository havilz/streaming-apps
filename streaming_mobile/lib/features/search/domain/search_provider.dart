import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider untuk menyimpan dan mengupdate query pencarian.
class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  /// Update query pencarian.
  void setQuery(String query) => state = query;

  /// Reset query ke kosong.
  void clear() => state = '';
}

final searchQueryProvider = NotifierProvider<SearchQueryNotifier, String>(
  SearchQueryNotifier.new,
);
