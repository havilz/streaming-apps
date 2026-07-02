import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider search query — akan diimplementasi penuh pada task 6.
/// Menggunakan [NotifierProvider] untuk menyimpan dan mengupdate query teks.
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
