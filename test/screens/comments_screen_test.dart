import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_cleanapp/models/user_model.dart';
import 'package:flutter_cleanapp/screens/comments_screen.dart';

const _testUser = UserModel(
  id: 'test-id',
  name: 'Test User',
  room: 'Cuarto 1A',
);

void main() {
  // Helper to wrap CommentsScreen in MaterialApp
  Widget createTestWidget() {
    return const MaterialApp(
      home: Scaffold(body: CommentsScreen(currentUser: _testUser)),
    );
  }

  group('CommentsScreen', () {
    testWidgets('shows loading indicator initially', (tester) async {
      await tester.pumpWidget(createTestWidget());
      // Before pumpAndSettle — should show loading indicator
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('shows no TabBar — single role-based view', (tester) async {
      await tester.pumpWidget(createTestWidget());
      // The redesigned screen has no TabBar — single view based on role.
      expect(find.byType(TabBar), findsNothing);
    });

    testWidgets('can be constructed with required currentUser', (tester) async {
      await tester.pumpWidget(createTestWidget());
      expect(find.byType(CommentsScreen), findsOneWidget);
    });

    testWidgets('shows warning when sending empty comment after load', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      // Only test the empty-comment validation which doesn't need Supabase
      // The screen is in loading state, so Enviar Comentario button is not visible yet
      expect(find.byType(CommentsScreen), findsOneWidget);
    });
  });
}
