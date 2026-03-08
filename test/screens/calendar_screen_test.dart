import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_cleanapp/screens/calendar_screen.dart';
import 'package:flutter_cleanapp/data/mock_data.dart';

void main() {
  group('CalendarScreen', () {
    testWidgets('shows Calendario de Aseo header', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: CalendarScreen())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Calendario de Aseo'), findsOneWidget);
    });

    testWidgets('shows schedule entries', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: CalendarScreen())),
      );
      await tester.pumpAndSettle();

      // At least one user name from MockData should appear in the list.
      final userNames = MockData.users.map((u) => u.name).toList();
      final anyNameFound = userNames.any(
        (name) => find.text(name).evaluate().isNotEmpty,
      );
      expect(anyNameFound, isTrue);
    });

    testWidgets('shows Esta semana chip for current week', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: CalendarScreen())),
      );
      await tester.pumpAndSettle();

      // The current week entry should have an "Esta semana" chip.
      expect(find.text('Esta semana'), findsOneWidget);
    });
  });
}
