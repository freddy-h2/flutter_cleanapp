import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_cleanapp/screens/home_screen.dart';
import 'package:flutter_cleanapp/data/mock_data.dart';

/// Returns true if the current user has cleaning duty this week.
bool _currentUserHasDutyThisWeek() {
  final currentUser = MockData.currentUser;
  final now = DateTime.now();
  final currentMonday = now.subtract(Duration(days: now.weekday - 1));
  final currentWeekStart = DateTime(
    currentMonday.year,
    currentMonday.month,
    currentMonday.day,
  );
  final currentWeekEnd = currentWeekStart.add(const Duration(days: 7));

  return MockData.schedules.any(
    (s) =>
        s.userId == currentUser.id &&
        !s.date.isBefore(currentWeekStart) &&
        s.date.isBefore(currentWeekEnd) &&
        !s.isCompleted,
  );
}

void main() {
  group('HomeScreen', () {
    testWidgets('shows user name and apartment', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: HomeScreen(onNavigateToActivities: () {})),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(MockData.currentUser.name), findsOneWidget);
      expect(find.text(MockData.currentUser.apartment), findsOneWidget);
    });

    testWidgets('shows Ir a Actividades button when user has duty', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: HomeScreen(onNavigateToActivities: () {})),
        ),
      );
      await tester.pumpAndSettle();

      if (_currentUserHasDutyThisWeek()) {
        expect(find.text('Ir a Actividades'), findsOneWidget);
      } else {
        // User is free this week — button should not be present.
        expect(find.text('Ir a Actividades'), findsNothing);
        expect(find.text('¡Estás libre esta semana!'), findsOneWidget);
      }
    });

    testWidgets('calls onNavigateToActivities when button tapped', (
      tester,
    ) async {
      var callCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeScreen(onNavigateToActivities: () => callCount++),
          ),
        ),
      );
      await tester.pumpAndSettle();

      if (_currentUserHasDutyThisWeek()) {
        await tester.tap(find.text('Ir a Actividades'));
        await tester.pumpAndSettle();
        expect(callCount, 1);
      } else {
        // User is free this week — verify the free-week message is shown.
        expect(find.text('¡Estás libre esta semana!'), findsOneWidget);
        expect(callCount, 0);
      }
    });
  });
}
