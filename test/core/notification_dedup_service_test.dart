import 'package:flutter_cleanapp/core/notification_dedup_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('NotificationDedupService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('shouldNotify returns true for new event key', () async {
      final result = await NotificationDedupService.instance.shouldNotify(
        'test:1',
      );
      expect(result, isTrue);
    });

    test('shouldNotify returns false for duplicate event key', () async {
      await NotificationDedupService.instance.shouldNotify('test:1');
      final result = await NotificationDedupService.instance.shouldNotify(
        'test:1',
      );
      expect(result, isFalse);
    });

    test('different event keys are not considered duplicates', () async {
      await NotificationDedupService.instance.shouldNotify('test:1');
      final result = await NotificationDedupService.instance.shouldNotify(
        'test:2',
      );
      expect(result, isTrue);
    });

    test('clear removes all dedup entries', () async {
      await NotificationDedupService.instance.shouldNotify('test:1');
      await NotificationDedupService.instance.clear();
      final result = await NotificationDedupService.instance.shouldNotify(
        'test:1',
      );
      expect(result, isTrue);
    });

    test('expired entries are cleaned up', () async {
      // This test verifies the TTL mechanism.
      // We can test by manipulating the stored data directly.
      final prefs = await SharedPreferences.getInstance();
      final expiredTimestamp =
          DateTime.now().millisecondsSinceEpoch -
          (31 * 60 * 1000); // 31 min ago
      await prefs.setStringList('notification_dedup_keys', [
        'test:old|$expiredTimestamp',
      ]);

      // Should return true because the old entry is expired
      final result = await NotificationDedupService.instance.shouldNotify(
        'test:old',
      );
      expect(result, isTrue);
    });
  });
}
