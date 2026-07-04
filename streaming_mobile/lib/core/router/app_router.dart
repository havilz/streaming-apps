import 'package:go_router/go_router.dart';
import 'package:streaming_mobile/features/detail/presentation/detail_screen.dart';
import 'package:streaming_mobile/features/detail/presentation/player_screen.dart';
import 'package:streaming_mobile/features/home/presentation/home_screen.dart';
import 'package:streaming_mobile/features/home/presentation/movie_screen.dart';
import 'package:streaming_mobile/features/home/presentation/series_screen.dart';
import 'package:streaming_mobile/features/home/presentation/genres_screen.dart';
import 'package:streaming_mobile/features/home/presentation/genre_detail_screen.dart';
import 'package:streaming_mobile/features/home/presentation/countries_screen.dart';
import 'package:streaming_mobile/features/home/presentation/country_detail_screen.dart';
import 'package:streaming_mobile/features/home/presentation/years_screen.dart';
import 'package:streaming_mobile/features/home/presentation/year_detail_screen.dart';
import 'package:streaming_mobile/features/home/presentation/networks_screen.dart';
import 'package:streaming_mobile/features/home/presentation/network_detail_screen.dart';
import 'package:streaming_mobile/features/home/presentation/splash_screen.dart';
import 'package:streaming_mobile/shared/templates/main_scaffold.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  debugLogDiagnostics: false,
  routes: [
    // Splash Screen (di luar ShellRoute)
    GoRoute(
      path: '/splash',
      name: 'splash',
      builder: (_, __) => const SplashScreen(),
    ),
    // Halaman utama
    ShellRoute(
      builder: (context, state, child) => MainScaffold(child: child),
      routes: [
        GoRoute(
          path: '/',
          name: 'home',
          builder: (_, __) => const HomeScreen(),
        ),
        GoRoute(
          path: '/movies',
          name: 'movies',
          builder: (_, __) => const MovieScreen(),
        ),
        GoRoute(
          path: '/series',
          name: 'series',
          builder: (_, __) => const SeriesScreen(),
        ),
        GoRoute(
          path: '/genres',
          name: 'genres',
          builder: (_, __) => const GenresScreen(),
        ),
        GoRoute(
          path: '/genres/:genreId',
          name: 'genre_detail',
          builder: (context, state) {
            final genreId = int.parse(state.pathParameters['genreId']!);
            final genreName = state.uri.queryParameters['name'] ?? '';
            return GenreDetailScreen(genreId: genreId, genreName: genreName);
          },
        ),
        GoRoute(
          path: '/countries',
          name: 'countries',
          builder: (_, __) => const CountriesScreen(),
        ),
        GoRoute(
          path: '/countries/:countryId',
          name: 'country_detail',
          builder: (context, state) {
            final countryId = int.parse(state.pathParameters['countryId']!);
            final countryName = state.uri.queryParameters['name'] ?? '';
            return CountryDetailScreen(countryId: countryId, countryName: countryName);
          },
        ),
        GoRoute(
          path: '/years',
          name: 'years',
          builder: (_, __) => const YearsScreen(),
        ),
        GoRoute(
          path: '/years/:year',
          name: 'year_detail',
          builder: (context, state) {
            final year = state.pathParameters['year']!;
            return YearDetailScreen(year: year);
          },
        ),
        GoRoute(
          path: '/networks',
          name: 'networks',
          builder: (_, __) => const NetworksScreen(),
        ),
        GoRoute(
          path: '/networks/:networkId',
          name: 'network_detail',
          builder: (context, state) {
            final networkId = int.parse(state.pathParameters['networkId']!);
            final networkName = state.uri.queryParameters['name'] ?? '';
            return NetworkDetailScreen(networkId: networkId, networkName: networkName);
          },
        ),
      ],
    ),

    // Halaman tanpa bottom navbar
    GoRoute(
      path: '/detail/:slug',
      name: 'detail',
      builder: (context, state) {
        final slug = state.pathParameters['slug']!;
        final extra = state.extra as Map<String, dynamic>? ?? {};
        final isSeries = extra['isSeries'] as bool? ?? false;
        return DetailScreen(slug: slug, isSeries: isSeries);
      },
    ),

    GoRoute(
      path: '/player/:episodeId',
      name: 'player',
      builder: (context, state) {
        final episodeId = state.pathParameters['episodeId']!;
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return PlayerScreen(
          episodeId: episodeId,
          slug: extra['slug'] as String? ?? '',
          isMovie: extra['isMovie'] as bool? ?? false,
        );
      },
    ),
  ],
);
