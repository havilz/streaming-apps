import 'package:streaming_mobile/core/core.dart';
import 'package:streaming_mobile/features/home/data/movie_model.dart';

class SearchRepository {
  const SearchRepository();

  /// Cari movies dan series berdasarkan judul.
  /// Menggabungkan hasil dari kedua tabel dan mengembalikan sebagai [ContentItem].
  Future<List<ContentItem>> search(String query, {int limit = 40}) async {
    if (query.trim().isEmpty) return [];

    final q = query.trim();

    final results = await Future.wait([
      supabaseClient
          .from(ApiEndpoints.movies)
          .select(
            'id, title, slug, poster_path, release_date, vote_average, quality',
          )
          .ilike('title', '%$q%')
          .order('vote_average', ascending: false)
          .limit(limit),
      supabaseClient
          .from(ApiEndpoints.series)
          .select(
            'id, title, slug, poster_path, first_air_date, vote_average, quality',
          )
          .ilike('title', '%$q%')
          .order('vote_average', ascending: false)
          .limit(limit),
    ]);

    final movies = (results[0] as List)
        .map((e) => ContentItem.fromMovie(MovieModel.fromMap(e)))
        .toList();

    final series = (results[1] as List)
        .map(
          (e) => ContentItem.fromSeries(
            SeriesModel.fromMap({...e, 'first_air_date': e['first_air_date']}),
          ),
        )
        .toList();

    // Gabung dan urutkan berdasarkan vote_average
    final merged = [...movies, ...series]
      ..sort((a, b) => (b.voteAverage ?? 0).compareTo(a.voteAverage ?? 0));

    return merged;
  }
}
