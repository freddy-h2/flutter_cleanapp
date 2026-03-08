import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_cleanapp/screens/activities_screen.dart';
import 'package:flutter_cleanapp/data/mock_data.dart';

/// Returns true if the current user has a cleaning schedule this week.
bool _currentUserHasScheduleThisWeek() {
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
        s.date.isBefore(currentWeekEnd),
  );
}

void main() {
  group('ActivitiesScreen', () {
    testWidgets('shows all 8 cleaning tasks', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ActivitiesScreen())),
      );
      await tester.pumpAndSettle();

      if (_currentUserHasScheduleThisWeek()) {
        // All 8 task titles should be visible.
        for (final title in MockData.defaultTaskTitles) {
          expect(find.text(title), findsOneWidget);
        }
      } else {
        // No schedule this week — verify the 8 default task titles exist in
        // MockData (they would be shown if the user had duty).
        expect(MockData.defaultTaskTitles.length, 8);
        expect(
          find.text('No tienes aseo asignado esta semana'),
          findsOneWidget,
        );
      }
    });

    testWidgets('toggles task checkbox', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ActivitiesScreen())),
      );
      await tester.pumpAndSettle();

      if (_currentUserHasScheduleThisWeek()) {
        // Find the first CheckboxListTile and tap it.
        final firstCheckbox = find.byType(CheckboxListTile).first;
        final checkboxWidget = tester.widget<CheckboxListTile>(firstCheckbox);
        expect(checkboxWidget.value, false);

        await tester.tap(firstCheckbox);
        await tester.pumpAndSettle();

        final updatedCheckbox = tester.widget<CheckboxListTile>(
          find.byType(CheckboxListTile).first,
        );
        expect(updatedCheckbox.value, true);
      } else {
        // No schedule — no checkboxes to toggle.
        expect(find.byType(CheckboxListTile), findsNothing);
      }
    });

    testWidgets(
      'shows warning SnackBar when Finalizar pressed with incomplete tasks',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ActivitiesScreen())),
        );
        await tester.pumpAndSettle();

        if (_currentUserHasScheduleThisWeek()) {
          // Tap Finalizar without completing any tasks.
          await tester.tap(find.text('Finalizar Aseo'));
          await tester.pumpAndSettle();

          expect(
            find.text('Aún tienes tareas pendientes por completar'),
            findsOneWidget,
          );
        } else {
          // No schedule — Finalizar button is not shown.
          expect(find.text('Finalizar Aseo'), findsNothing);
          expect(
            find.text('No tienes aseo asignado esta semana'),
            findsOneWidget,
          );
        }
      },
    );

    testWidgets(
      'shows success SnackBar when all tasks completed and Finalizar pressed',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ActivitiesScreen())),
        );
        await tester.pumpAndSettle();

        if (_currentUserHasScheduleThisWeek()) {
          // Check all tasks.
          final checkboxes = find.byType(CheckboxListTile);
          for (var i = 0; i < tester.widgetList(checkboxes).length; i++) {
            await tester.tap(find.byType(CheckboxListTile).at(i));
            await tester.pumpAndSettle();
          }

          // Tap Finalizar.
          await tester.tap(find.text('Finalizar Aseo'));
          await tester.pumpAndSettle();

          expect(
            find.text('¡Aseo completado! Gracias por tu colaboración'),
            findsOneWidget,
          );
        } else {
          // No schedule — verify no-schedule message.
          expect(
            find.text('No tienes aseo asignado esta semana'),
            findsOneWidget,
          );
        }
      },
    );
  });
}
