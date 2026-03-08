import 'package:flutter/material.dart';
import 'package:flutter_cleanapp/screens/auth_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // CleanApp requires Supabase to be initialized (for auth state listening).
  // In unit tests we test the AuthScreen directly, which is what CleanApp
  // shows when the user is not authenticated.
  group('AuthScreen (shown by CleanApp when logged out)', () {
    testWidgets('renders login form with Iniciar Sesión button', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: AuthScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Iniciar Sesión'), findsWidgets);
      expect(find.text('CleanApp'), findsOneWidget);
    });

    testWidgets('shows email and password fields', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AuthScreen()));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.email), findsOneWidget);
      expect(find.byIcon(Icons.lock), findsOneWidget);
    });

    testWidgets('toggles to register mode', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AuthScreen()));
      await tester.pumpAndSettle();

      // Tap the "Regístrate" TextButton to switch to register mode.
      await tester.tap(find.text('Regístrate'));
      await tester.pumpAndSettle();

      expect(find.text('Crear Cuenta'), findsOneWidget);
      expect(find.byIcon(Icons.person), findsOneWidget);
      expect(find.byIcon(Icons.apartment), findsOneWidget);
    });

    testWidgets('register mode shows name and apartment fields', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: AuthScreen()));
      await tester.pumpAndSettle();

      // Switch to register mode.
      await tester.tap(find.text('Regístrate'));
      await tester.pumpAndSettle();

      // Register mode should show name and apartment fields.
      expect(find.byIcon(Icons.person), findsOneWidget);
      expect(find.byIcon(Icons.apartment), findsOneWidget);
      // Email and password fields still present.
      expect(find.byIcon(Icons.email), findsOneWidget);
      expect(find.byIcon(Icons.lock), findsOneWidget);
    });
  });
}
