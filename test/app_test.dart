import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_cleanapp/app.dart';

void main() {
  group('CleanApp', () {
    testWidgets('renders NavigationBar with 4 destinations', (tester) async {
      await tester.pumpWidget(const CleanApp());
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationDestination), findsNWidgets(4));
      expect(find.text('Inicio'), findsOneWidget);
      expect(find.text('Actividades'), findsOneWidget);
      expect(find.text('Calendario'), findsOneWidget);
      expect(find.text('Comentarios'), findsOneWidget);
    });

    testWidgets('switches tabs when NavigationDestination is tapped', (
      tester,
    ) async {
      await tester.pumpWidget(const CleanApp());
      await tester.pumpAndSettle();

      // Tap the Actividades destination.
      await tester.tap(find.text('Actividades'));
      await tester.pumpAndSettle();

      // The Activities screen content should be visible — either the task list
      // header (when user has duty) or the no-schedule message.
      final hasTaskList = find
          .text('Actividades de Aseo')
          .evaluate()
          .isNotEmpty;
      final hasNoSchedule = find
          .text('No tienes aseo asignado esta semana')
          .evaluate()
          .isNotEmpty;
      expect(hasTaskList || hasNoSchedule, isTrue);
    });

    testWidgets('theme toggle button exists', (tester) async {
      await tester.pumpWidget(const CleanApp());
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (widget) => widget is IconButton && widget.tooltip == 'Cambiar tema',
        ),
        findsOneWidget,
      );
    });
  });
}
