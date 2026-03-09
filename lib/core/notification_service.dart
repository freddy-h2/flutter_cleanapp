import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Singleton service for managing local notifications.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Initialize the notification plugin. Safe to call multiple times.
  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings);
    _initialized = true;
  }

  /// Request notification permissions on Android 13+.
  Future<void> requestPermissions() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      await android.requestNotificationsPermission();
    }
  }

  /// Show an immediate notification.
  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'limpy_general',
      'Limpy Notificaciones',
      channelDescription: 'Notificaciones generales de Limpy',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);
    await _plugin.show(id, title, body, details);
  }

  /// Schedule a notification at a specific time.
  ///
  /// Uses a delayed [Future] for simplicity. For exact scheduling,
  /// use zonedSchedule in a future task.
  Future<void> scheduleAt({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    final delay = scheduledDate.difference(DateTime.now());
    if (delay.isNegative) return;
    Future.delayed(delay, () => show(id: id, title: title, body: body));
  }

  /// Cancel a specific notification by [id].
  Future<void> cancel(int id) async {
    await _plugin.cancel(id);
  }

  /// Cancel all pending notifications.
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  /// Notification ID base for cleaning period countdown notifications.
  static const int _cleaningBaseId = 1000;

  /// Notification ID base for anonymous comment notifications.
  static const int _commentBaseId = 2000;

  /// Notification ID base for prorroga (extension request) notifications.
  static const int _prorrogaBaseId = 3000;

  /// Notification ID base for announcement notifications.
  static const int _announcementBaseId = 4000;

  /// Show a notification for a new anonymous comment received by the
  /// responsible user.
  ///
  /// [commentIndex] is used to generate a unique notification ID so that
  /// multiple comment notifications can coexist.
  Future<void> notifyNewComment({required int commentIndex}) async {
    await show(
      id: _commentBaseId + (commentIndex % 100),
      title: 'Limpy - Nuevo Comentario',
      body: 'Has recibido un comentario anonimo sobre tu aseo',
    );
  }

  /// Show a notification for an incoming prorroga request.
  ///
  /// [requesterName] is the display name of the user who sent the request.
  Future<void> notifyProrrogaReceived({required String requesterName}) async {
    await show(
      id: _prorrogaBaseId,
      title: 'Limpy - Solicitud de Prorroga',
      body: '$requesterName solicita que tomes su turno de aseo',
    );
  }

  /// Show a notification when the current user's prorroga request is accepted.
  Future<void> notifyProrrogaAccepted() async {
    await show(
      id: _prorrogaBaseId + 1,
      title: 'Limpy - Prorroga Aceptada',
      body: 'Tu solicitud de prorroga ha sido aceptada',
    );
  }

  /// Show a notification when the current user's prorroga request is rejected.
  Future<void> notifyProrrogaRejected() async {
    await show(
      id: _prorrogaBaseId + 2,
      title: 'Limpy - Prorroga Rechazada',
      body: 'Tu solicitud de prorroga ha sido rechazada',
    );
  }

  /// Show a notification for a new announcement.
  ///
  /// [title] is the announcement title and [body] is the announcement message.
  Future<void> notifyAnnouncement({
    required String title,
    required String body,
  }) async {
    await show(id: _announcementBaseId, title: 'Limpy - $title', body: body);
  }

  /// Schedule countdown notifications for a cleaning period.
  ///
  /// [periodStartDate] is the first day of the cleaning period.
  /// [periodEndDate] is the last day of the cleaning period.
  /// [periodDays] is the total period length (default 3), used only to
  /// determine how many notification IDs to cancel upfront.
  ///
  /// Only schedules notifications for days >= today AND <= [periodEndDate].
  /// Past days are skipped. Remaining-days count is computed from
  /// [periodEndDate] so it reflects the actual days left in the period.
  ///
  /// Cancels any existing cleaning notifications before scheduling new ones.
  Future<void> scheduleCleaningCountdown({
    required DateTime periodStartDate,
    required DateTime periodEndDate,
    int periodDays = 3,
  }) async {
    // Cancel any existing cleaning notifications first.
    for (var i = 0; i < periodDays; i++) {
      await cancel(_cleaningBaseId + i);
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final periodEnd = DateTime(
      periodEndDate.year,
      periodEndDate.month,
      periodEndDate.day,
    );

    for (var i = 0; i < periodDays; i++) {
      final day = DateTime(
        periodStartDate.year,
        periodStartDate.month,
        periodStartDate.day + i,
        8,
        0,
      ); // 8 AM
      final dayOnly = DateTime(day.year, day.month, day.day);

      // Skip days before today.
      if (dayOnly.isBefore(today)) continue;
      // Skip days after period end.
      if (dayOnly.isAfter(periodEnd)) continue;

      final remaining = periodEnd.difference(dayOnly).inDays + 1;

      final isToday = dayOnly == today;
      final body = remaining == 1
          ? 'Te queda 1 dia disponible para hacer el aseo'
          : remaining == periodDays
          ? 'Tienes $remaining dias disponibles para hacer el aseo'
          : 'Te quedan $remaining dias disponibles para hacer el aseo';

      if (isToday) {
        await show(
          id: _cleaningBaseId + i,
          title: 'Limpy - Periodo de Aseo',
          body: body,
        );
      } else {
        await scheduleAt(
          id: _cleaningBaseId + i,
          title: 'Limpy - Periodo de Aseo',
          body: body,
          scheduledDate: day,
        );
      }
    }
  }
}
