import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_cleanapp/screens/comments_screen.dart';

void main() {
  // Helper to wrap CommentsScreen in MaterialApp
  Widget createTestWidget() {
    return const MaterialApp(home: Scaffold(body: CommentsScreen()));
  }

  group('CommentsScreen', () {
    testWidgets('shows TabBar with Enviar and Recibir tabs', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();
      expect(find.text('Enviar'), findsOneWidget);
      expect(find.text('Recibir'), findsOneWidget);
      expect(find.byType(TabBar), findsOneWidget);
    });

    testWidgets('Enviar tab shows header and text field', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();
      expect(find.text('Enviar Comentario Anónimo'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Enviar Comentario'), findsOneWidget);
    });

    testWidgets('shows warning when sending empty comment', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enviar Comentario'));
      await tester.pumpAndSettle();
      expect(
        find.text('Escribe un comentario antes de enviar'),
        findsOneWidget,
      );
    });

    testWidgets('sends comment and shows confirmation', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Test comment');
      await tester.tap(find.text('Enviar Comentario'));
      await tester.pumpAndSettle();
      // Should show success snackbar or no-responsible snackbar depending on schedule
      final hasSentConfirmation = find
          .text('¡Comentario enviado de forma anónima!')
          .evaluate()
          .isNotEmpty;
      final hasNoResponsible = find
          .text('No hay responsable asignado esta semana')
          .evaluate()
          .isNotEmpty;
      expect(hasSentConfirmation || hasNoResponsible, isTrue);
    });

    testWidgets('Recibir tab shows appropriate content', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();
      // Switch to Recibir tab
      await tester.tap(find.text('Recibir'));
      await tester.pumpAndSettle();
      // Should show either the inbox (if user is responsible) or the locked state
      final hasInbox = find.text('Buzón de Comentarios').evaluate().isNotEmpty;
      final hasLocked = find.text('Buzón no disponible').evaluate().isNotEmpty;
      expect(hasInbox || hasLocked, isTrue);
    });
  });
}
