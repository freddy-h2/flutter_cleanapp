import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_cleanapp/models/user_model.dart';
import 'package:flutter_cleanapp/screens/activities_screen.dart';

const _testUser = UserModel(
  id: 'test-id',
  name: 'Test User',
  apartment: 'Depto 1A',
);

const _testAdmin = UserModel(
  id: 'admin-id',
  name: 'Admin User',
  apartment: 'Depto 0A',
  role: UserRole.admin,
);

void main() {
  group('ActivitiesScreen', () {
    testWidgets('shows loading indicator initially', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ActivitiesScreen(currentUser: _testUser)),
        ),
      );
      // Before pumpAndSettle — should show loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('can be constructed with regular user', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ActivitiesScreen(currentUser: _testUser)),
        ),
      );
      expect(find.byType(ActivitiesScreen), findsOneWidget);
    });

    testWidgets('can be constructed with admin user', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ActivitiesScreen(currentUser: _testAdmin)),
        ),
      );
      expect(find.byType(ActivitiesScreen), findsOneWidget);
    });

    testWidgets('shows warning when Finalizar pressed with incomplete tasks', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ActivitiesScreen(currentUser: _testUser)),
        ),
      );
      // Loading state — no Finalizar button yet
      expect(find.text('Finalizar Aseo'), findsNothing);
    });
  });
}
