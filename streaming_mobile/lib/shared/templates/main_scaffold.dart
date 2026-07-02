import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:streaming_mobile/shared/organisms/app_navbar.dart';

/// Scaffold utama dengan bottom navigation bar.
/// Semua halaman utama (Home, Search) dibungkus dengan template ini.
class MainScaffold extends StatelessWidget {
  const MainScaffold({super.key, required this.child});

  final Widget child;

  int _getCurrentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/search')) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: AppNavbar(
        currentIndex: _getCurrentIndex(context),
        onTap: (index) {
          switch (index) {
            case 0:
              context.go('/');
            case 1:
              context.go('/search');
          }
        },
      ),
    );
  }
}
