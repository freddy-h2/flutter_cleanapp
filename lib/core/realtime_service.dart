import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_cleanapp/core/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Manages Supabase Realtime channel subscriptions and exposes
/// broadcast streams that fire whenever the corresponding table changes.
///
/// Usage:
/// ```dart
/// // Subscribe once (e.g. in app.dart initState):
/// RealtimeService.instance.subscribe();
///
/// // Listen in a screen:
/// _sub = RealtimeService.instance.onSchedulesChanged.listen((_) {
///   if (mounted) _loadData();
/// });
///
/// // Cancel in dispose():
/// _sub.cancel();
///
/// // Dispose the service when the app is torn down:
/// RealtimeService.instance.dispose();
/// ```
///
/// ### Supabase setup
/// The following SQL must be executed once in the Supabase SQL editor to
/// enable row-level change events for the relevant tables:
/// ```sql
/// -- Enable realtime for tables (run in Supabase SQL editor)
/// ALTER PUBLICATION supabase_realtime ADD TABLE schedules;
/// ALTER PUBLICATION supabase_realtime ADD TABLE tasks;
/// ALTER PUBLICATION supabase_realtime ADD TABLE comments;
/// ALTER PUBLICATION supabase_realtime ADD TABLE extension_requests;
/// ```
class RealtimeService {
  RealtimeService._();

  /// The singleton instance.
  static final RealtimeService instance = RealtimeService._();

  RealtimeChannel? _channel;

  final _schedulesController = StreamController<void>.broadcast();
  final _tasksController = StreamController<void>.broadcast();
  final _commentsController = StreamController<void>.broadcast();
  final _extensionsController = StreamController<void>.broadcast();

  /// Fires whenever a row in the `schedules` table is inserted, updated,
  /// or deleted.
  Stream<void> get onSchedulesChanged => _schedulesController.stream;

  /// Fires whenever a row in the `tasks` table is inserted, updated,
  /// or deleted.
  Stream<void> get onTasksChanged => _tasksController.stream;

  /// Fires whenever a row in the `comments` table is inserted, updated,
  /// or deleted.
  Stream<void> get onCommentsChanged => _commentsController.stream;

  /// Fires whenever a row in the `extension_requests` table is inserted,
  /// updated, or deleted.
  Stream<void> get onExtensionsChanged => _extensionsController.stream;

  /// Opens a single Supabase Realtime channel that listens to all four
  /// tables. Safe to call multiple times — the previous channel is
  /// unsubscribed first.
  void subscribe() {
    _channel?.unsubscribe();
    _channel = SupabaseConfig.client
        .channel('app_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'schedules',
          callback: (payload) {
            debugPrint('RealtimeService: schedules changed');
            _schedulesController.add(null);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'tasks',
          callback: (payload) {
            debugPrint('RealtimeService: tasks changed');
            _tasksController.add(null);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'comments',
          callback: (payload) {
            debugPrint('RealtimeService: comments changed');
            _commentsController.add(null);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'extension_requests',
          callback: (payload) {
            debugPrint('RealtimeService: extension_requests changed');
            _extensionsController.add(null);
          },
        )
        .subscribe();
  }

  /// Unsubscribes from the Realtime channel without closing the streams.
  void unsubscribe() {
    _channel?.unsubscribe();
    _channel = null;
  }

  /// Unsubscribes from the channel and closes all stream controllers.
  /// Call this when the app is permanently torn down.
  void dispose() {
    unsubscribe();
    _schedulesController.close();
    _tasksController.close();
    _commentsController.close();
    _extensionsController.close();
  }
}
