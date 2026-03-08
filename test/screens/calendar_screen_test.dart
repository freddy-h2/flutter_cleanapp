import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_cleanapp/models/user_model.dart';
import 'package:flutter_cleanapp/screens/calendar_screen.dart';

const _testUser = UserModel(
  id: 'test-id',
  name: 'Test User',
  room: 'Cuarto 1A',
);

const _testAdmin = UserModel(
  id: 'admin-id',
  name: 'Admin User',
  room: 'Cuarto 0A',
  role: UserRole.admin,
);

void main() {
  group('CalendarScreen', () {
    testWidgets('shows loading indicator initially', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: CalendarScreen(currentUser: _testUser)),
        ),
      );
      // Before pumpAndSettle — should show loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('can be constructed with regular user', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: CalendarScreen(currentUser: _testUser)),
        ),
      );
      expect(find.byType(CalendarScreen), findsOneWidget);
    });

    testWidgets('can be constructed with admin user', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: CalendarScreen(currentUser: _testAdmin)),
        ),
      );
      expect(find.byType(CalendarScreen), findsOneWidget);
    });
  });
}
