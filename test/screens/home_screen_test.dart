import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_cleanapp/models/user_model.dart';
import 'package:flutter_cleanapp/screens/home_screen.dart';

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
  group('HomeScreen', () {
    testWidgets('shows loading indicator initially', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeScreen(
              currentUser: _testUser,
              onNavigateToActivities: () {},
            ),
          ),
        ),
      );
      // Before pumpAndSettle — should show loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('can be constructed with regular user', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeScreen(
              currentUser: _testUser,
              onNavigateToActivities: () {},
            ),
          ),
        ),
      );
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('can be constructed with admin user', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeScreen(
              currentUser: _testAdmin,
              onNavigateToActivities: () {},
            ),
          ),
        ),
      );
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });
}
