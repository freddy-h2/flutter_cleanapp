import 'package:flutter/material.dart';
import 'package:flutter_cleanapp/screens/auth_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthScreen', () {
    testWidgets('shows login form by default', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AuthScreen()));
      await tester.pumpAndSettle();

      // Login mode shows "Iniciar Sesión" title and button
      expect(find.text('Iniciar Sesión'), findsWidgets);
      // Email and password fields are present
      expect(find.byIcon(Icons.email), findsOneWidget);
      expect(find.byIcon(Icons.lock), findsOneWidget);
      // Register-only fields are NOT shown
      expect(find.byIcon(Icons.person), findsNothing);
      expect(find.byIcon(Icons.meeting_room), findsNothing);
    });

    testWidgets('toggles to register form', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AuthScreen()));
      await tester.pumpAndSettle();

      // Tap "Regístrate" to switch to register mode
      await tester.tap(find.text('Regístrate'));
      await tester.pumpAndSettle();

      // Register mode shows "Crear Cuenta" title
      expect(find.text('Crear Cuenta'), findsOneWidget);
      // Name and room fields appear
      expect(find.byIcon(Icons.person), findsOneWidget);
      expect(find.byIcon(Icons.meeting_room), findsOneWidget);
    });

    testWidgets('validates empty email on submit', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AuthScreen()));
      await tester.pumpAndSettle();

      // Tap the submit button without entering any data
      await tester.tap(find.text('Iniciar Sesión').last);
      await tester.pumpAndSettle();

      // Validation error for invalid email
      expect(find.text('Ingresa un correo electrónico válido'), findsOneWidget);
    });

    testWidgets('validates short password on submit', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AuthScreen()));
      await tester.pumpAndSettle();

      // Enter a valid email but a short password using TextFormField finders
      final emailField = find.byType(TextFormField).first;
      final passwordField = find.byType(TextFormField).last;
      await tester.enterText(emailField, 'test@example.com');
      await tester.enterText(passwordField, 'abc');
      await tester.tap(find.text('Iniciar Sesión').last);
      await tester.pumpAndSettle();

      // Validation error for short password
      expect(
        find.text('La contraseña debe tener al menos 6 caracteres'),
        findsOneWidget,
      );
    });

    testWidgets('shows CleanApp title', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AuthScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Limpy'), findsOneWidget);
    });

    testWidgets('toggles back to login from register', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AuthScreen()));
      await tester.pumpAndSettle();

      // Switch to register mode
      await tester.tap(find.text('Regístrate'));
      await tester.pumpAndSettle();
      expect(find.text('Crear Cuenta'), findsOneWidget);

      // Switch back to login mode using ensureVisible to handle scroll
      await tester.ensureVisible(find.text('Inicia Sesión'));
      await tester.tap(find.text('Inicia Sesión'), warnIfMissed: false);
      await tester.pumpAndSettle();
      // Register-only fields gone again
      expect(find.byIcon(Icons.person), findsNothing);
    });
  });
}
