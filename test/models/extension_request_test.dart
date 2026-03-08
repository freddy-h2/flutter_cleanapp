import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_cleanapp/models/extension_request.dart';

void main() {
  group('ExtensionRequestStatus', () {
    test('fromString parses all values', () {
      expect(
        ExtensionRequestStatus.fromString('pending'),
        ExtensionRequestStatus.pending,
      );
      expect(
        ExtensionRequestStatus.fromString('accepted'),
        ExtensionRequestStatus.accepted,
      );
      expect(
        ExtensionRequestStatus.fromString('rejected'),
        ExtensionRequestStatus.rejected,
      );
    });

    test('label returns Spanish text', () {
      expect(ExtensionRequestStatus.pending.label, 'Pendiente');
      expect(ExtensionRequestStatus.accepted.label, 'Aceptada');
      expect(ExtensionRequestStatus.rejected.label, 'Rechazada');
    });
  });

  group('ExtensionRequest', () {
    final sampleJson = {
      'id': 'req-1',
      'schedule_id': 'sched-1',
      'requester_id': 'user-1',
      'next_user_id': 'user-2',
      'status': 'pending',
      'created_at': '2026-03-08T10:00:00.000Z',
      'resolved_at': '2026-03-09T12:00:00.000Z',
    };

    test('fromJson maps all fields correctly', () {
      final request = ExtensionRequest.fromJson(sampleJson);

      expect(request.id, 'req-1');
      expect(request.scheduleId, 'sched-1');
      expect(request.requesterId, 'user-1');
      expect(request.nextUserId, 'user-2');
      expect(request.status, ExtensionRequestStatus.pending);
      expect(request.createdAt, DateTime.parse('2026-03-08T10:00:00.000Z'));
      expect(request.resolvedAt, DateTime.parse('2026-03-09T12:00:00.000Z'));
    });

    test('fromJson handles null resolvedAt', () {
      final json = Map<String, dynamic>.from(sampleJson)
        ..['resolved_at'] = null;
      final request = ExtensionRequest.fromJson(json);

      expect(request.resolvedAt, isNull);
    });

    test('toJson produces correct keys', () {
      final request = ExtensionRequest.fromJson(sampleJson);
      final json = request.toJson();

      expect(json.keys.toSet(), {
        'schedule_id',
        'requester_id',
        'next_user_id',
        'status',
      });
      expect(json.containsKey('id'), isFalse);
      expect(json.containsKey('created_at'), isFalse);
      expect(json.containsKey('resolved_at'), isFalse);
    });

    test('copyWith overrides status', () {
      final original = ExtensionRequest.fromJson(sampleJson);
      final updated = original.copyWith(
        status: ExtensionRequestStatus.accepted,
      );

      expect(updated.status, ExtensionRequestStatus.accepted);
      expect(updated.id, original.id);
      expect(updated.scheduleId, original.scheduleId);
      expect(updated.requesterId, original.requesterId);
      expect(updated.nextUserId, original.nextUserId);
      expect(updated.createdAt, original.createdAt);
    });

    test('isPending returns true only for pending', () {
      final pending = ExtensionRequest.fromJson(sampleJson);
      final accepted = pending.copyWith(
        status: ExtensionRequestStatus.accepted,
      );
      final rejected = pending.copyWith(
        status: ExtensionRequestStatus.rejected,
      );

      expect(pending.isPending, isTrue);
      expect(accepted.isPending, isFalse);
      expect(rejected.isPending, isFalse);
    });
  });
}
