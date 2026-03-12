import 'package:flutter_cleanapp/core/push_notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PushNotificationService', () {
    test('singleton instance is consistent', () {
      final a = PushNotificationService.instance;
      final b = PushNotificationService.instance;
      expect(identical(a, b), isTrue);
    });
  });
}
