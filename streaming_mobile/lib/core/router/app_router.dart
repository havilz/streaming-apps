import 'package:go_router/go_router.dart';
import 'package:streaming_mobile/features/detail/presentation/detail_screen.dart';
import 'package:streaming_mobile/features/detail/presentation/player_screen.dart';
import 'package:streaming_mobile/features/home/presentation/home_screen.dart';
import 'package:streaming_mobile/features/search/presentation/search_screen.dart';
import 'package:streaming_mobile/shared/templates/main_scaffold.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  debugLogDiagnostics: false,
  routes: [
    // Halaman dengan bottom navbar
    ShellRoute(
      builder: (context, state, child) => MainScaffold(child: child),
      routes: [
        GoRoute(
          path: '/',
          name: 'home',
          builder: (_, __) => const HomeScreen(),
        ),
        GoRoute(
          path: '/search',
          name: 'search',
          builder: (_, __) => const SearchScreen(),
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
