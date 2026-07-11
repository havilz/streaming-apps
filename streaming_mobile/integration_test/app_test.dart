import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:streaming_mobile/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('End-to-End App Integration Tests', () {
    testWidgets('Verify app boots up, displays home page and loads content', (WidgetTester tester) async {
      // Start the app main entrypoint
      app.main();
      await tester.pumpAndSettle();

      // Verify the App is showing and running
      expect(find.byType(ProviderScope), findsOneWidget);
      
      // Let any asynchronous loading/rendering settle
      await Future.delayed(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      // Assert that we have navigation elements like bottom navigation or search buttons
      final searchIcon = find.byIcon(Icons.search);
      expect(searchIcon, findsOneWidget);
    });
  });
}
