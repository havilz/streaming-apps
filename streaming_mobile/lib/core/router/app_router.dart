import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:streaming_mobile/features/home/presentation/home_screen.dart';
import 'package:streaming_mobile/features/search/presentation/search_screen.dart';
import 'package:streaming_mobile/shared/templates/main_scaffold.dart';

/// Konfigurasi routing aplikasi menggunakan GoRouter.
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  debugLogDiagnostics: false,
  routes: [
    // Shell route — halaman yang punya bottom navbar
    ShellRoute(
      builder: (context, state, child) => MainScaffold(child: child),
      routes: [
        GoRoute(
          path: '/',
          name: 'home',
          builder: (BuildContext context, GoRouterState state) =>
              const HomeScreen(),
        ),
        GoRoute(
          path: '/search',
          name: 'search',
          builder: (BuildContext context, GoRouterState state) =>
              const SearchScreen(),
        ),
      ],
    ),

    // Halaman tanpa bottom navbar
    GoRoute(
      path: '/detail/:slug',
      name: 'detail',
      builder: (BuildContext context, GoRouterState state) {
        final slug = state.pathParameters['slug']!;
        return Scaffold(
          backgroundColor: const Color(0xFF0B0F17),
          appBar: AppBar(title: Text(slug)),
          body: Center(child: Text(slug)),
        );
      },
    ),

    GoRoute(
      path: '/player/:episodeId',
      name: 'player',
      builder: (BuildContext context, GoRouterState state) {
        final episodeId = state.pathParameters['episodeId']!;
        return Scaffold(
          backgroundColor: const Color(0xFF0B0F17),
          appBar: AppBar(title: Text(episodeId)),
          body: Center(child: Text(episodeId)),
        );
      },
    ),
  ],
);
