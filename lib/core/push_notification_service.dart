import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_cleanapp/core/notification_dedup_service.dart';
import 'package:flutter_cleanapp/core/notification_service.dart';

/// Top-level background message handler. MUST be a top-level function.
/// Called by FCM when a data message arrives and the app is in background/killed.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await NotificationService.instance.initialize();
  await PushNotificationService._handleMessage(message, isBackground: true);
}

/// Manages FCM push notification lifecycle: initialization, token management,
/// and message handling.
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  String? _currentToken;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundMessageSub;

  /// Callback to register/update token in backend. Set by the caller (app.dart).
  Future<void> Function(String token)? onTokenRefresh;

  /// Callback to deactivate token in backend. Set by the caller (app.dart).
  Future<void> Function(String token)? onTokenDeactivate;

  /// Initialize Firebase and set up FCM message handlers.
  /// Call once in main() AFTER Firebase.initializeApp().
  Future<void> initialize() async {
    // Set up background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Request permission (Android 13+ requires runtime permission)
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('FCM permission status: ${settings.authorizationStatus}');

    // Listen for foreground messages
    _foregroundMessageSub = FirebaseMessaging.onMessage.listen((message) {
      _handleMessage(message, isBackground: false);
    });

    // Listen for token refresh
    _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((
      newToken,
    ) async {
      debugPrint('FCM token refreshed');
      _currentToken = newToken;
      await onTokenRefresh?.call(newToken);
    });
  }

  /// Get the current FCM token. Returns null if not available.
  Future<String?> getToken() async {
    _currentToken = await FirebaseMessaging.instance.getToken();
    return _currentToken;
  }

  /// Deactivate the current token (call on logout).
  Future<void> deactivateToken() async {
    if (_currentToken != null) {
      await onTokenDeactivate?.call(_currentToken!);
    }
    // Do NOT delete the token from FCM — just deactivate in backend.
    // This avoids re-registration issues on next login.
    _currentToken = null;
  }

  /// Clean up subscriptions.
  void dispose() {
    _tokenRefreshSub?.cancel();
    _foregroundMessageSub?.cancel();
  }

  /// Handle an incoming FCM message (both foreground and background).
  static Future<void> _handleMessage(
    RemoteMessage message, {
    required bool isBackground,
  }) async {
    final data = message.data;
    final type = data['type'] as String?;

    debugPrint('FCM message received: type=$type, isBackground=$isBackground');

    // If the message has a notification payload, Android will auto-display it
    // when in background/killed. We only need to manually show for:
    // 1. Data-only messages in background
    // 2. Any message in foreground
    if (message.notification != null && !isBackground) {
      // Foreground: show via flutter_local_notifications
      final dedupKey = 'fcm:${message.messageId ?? type ?? 'unknown'}';
      if (await NotificationDedupService.instance.shouldNotify(dedupKey)) {
        await NotificationService.instance.show(
          id: _notificationIdForType(type),
          title: message.notification!.title ?? 'Limpy',
          body: message.notification!.body ?? '',
        );
      }
      return;
    }

    // Data-only message handling
    switch (type) {
      case 'announcement':
        final announcementId =
            data['announcement_id'] ?? data['title'] ?? 'unknown';
        if (await NotificationDedupService.instance.shouldNotify(
          'announcement:$announcementId',
        )) {
          await NotificationService.instance.notifyAnnouncement(
            title: data['title'] ?? 'Nuevo Anuncio',
            body: data['message'] ?? '',
          );
        }
      case 'extension_request':
        final status = data['status'] ?? 'pending';
        final requestId = data['request_id'] ?? 'unknown';
        if (status == 'pending') {
          if (await NotificationDedupService.instance.shouldNotify(
            'extension_request:$requestId:pending',
          )) {
            await NotificationService.instance.notifyProrrogaReceived(
              requesterName: data['requester_name'] ?? 'Un vecino',
            );
          }
        } else if (status == 'accepted') {
          if (await NotificationDedupService.instance.shouldNotify(
            'extension_request:$requestId:accepted',
          )) {
            await NotificationService.instance.notifyProrrogaAccepted();
          }
        } else if (status == 'rejected') {
          if (await NotificationDedupService.instance.shouldNotify(
            'extension_request:$requestId:rejected',
          )) {
            await NotificationService.instance.notifyProrrogaRejected();
          }
        }
      case 'comment':
        final commentId = data['comment_id'] ?? 'unknown';
        if (await NotificationDedupService.instance.shouldNotify(
          'comment:$commentId',
        )) {
          await NotificationService.instance.notifyNewComment(commentIndex: 0);
        }
      default:
        debugPrint('FCM: unknown message type: $type');
    }
  }

  /// Generate a notification ID based on event type to avoid collisions
  /// with existing notification IDs in NotificationService.
  static int _notificationIdForType(String? type) {
    return switch (type) {
      'announcement' => 5000,
      'extension_request' => 5100,
      'comment' => 5200,
      _ => 5900,
    };
  }
}
