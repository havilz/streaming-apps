import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

/// Konfigurasi routing aplikasi menggunakan GoRouter.
/// Route akan diisi lengkap saat implementasi fitur dimulai.
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  debugLogDiagnostics: false,
  routes: [
    GoRoute(
      path: '/',
      name: 'home',
      builder: (BuildContext context, GoRouterState state) {
        // Placeholder — akan diganti dengan HomeScreen
        return const Scaffold(body: Center(child: Text('Home')));
      },
    ),
  ],
);
