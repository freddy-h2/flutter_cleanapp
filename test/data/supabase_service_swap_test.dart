import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_cleanapp/models/cleaning_schedule.dart';

/// Replicates the _findPeriodSchedules logic from SupabaseService
/// for unit testing purposes.
List<CleaningSchedule> findPeriodSchedules(
  List<CleaningSchedule> sortedSchedules,
  CleaningSchedule anchor, {
  int? maxSize,
}) {
  final anchorIndex = sortedSchedules.indexWhere((s) => s.id == anchor.id);
  if (anchorIndex == -1) return [anchor];

  final userId = anchor.userId;
  final result = <CleaningSchedule>[anchor];

  // Walk backward
  for (var i = anchorIndex - 1; i >= 0; i--) {
    if (sortedSchedules[i].userId != userId) break;
    final diff = sortedSchedules[i + 1].date
        .difference(sortedSchedules[i].date)
        .inDays;
    if (diff > 1) break;
    result.insert(0, sortedSchedules[i]);
    if (maxSize != null && result.length >= maxSize) break;
  }

  // Walk forward
  for (var i = anchorIndex + 1; i < sortedSchedules.length; i++) {
    if (maxSize != null && result.length >= maxSize) break;
    if (sortedSchedules[i].userId != userId) break;
    final diff = sortedSchedules[i].date
        .difference(sortedSchedules[i - 1].date)
        .inDays;
    if (diff > 1) break;
    result.add(sortedSchedules[i]);
  }

  return result;
}

/// Helper to create a CleaningSchedule for tests.
CleaningSchedule _schedule(String id, String userId, DateTime date) {
  return CleaningSchedule(id: id, userId: userId, date: date);
}

void main() {
  group('findPeriodSchedules', () {
    test('basic 3-day period — anchor is first day, finds all 3 days', () {
      final schedules = [
        _schedule('s1', 'userA', DateTime(2026, 3, 7)),
        _schedule('s2', 'userA', DateTime(2026, 3, 8)),
        _schedule('s3', 'userA', DateTime(2026, 3, 9)),
      ];
      final anchor = schedules[0];
      final result = findPeriodSchedules(schedules, anchor);
      expect(result.map((s) => s.id).toList(), ['s1', 's2', 's3']);
    });

    test('anchor is middle day — finds all 3 consecutive days', () {
      final schedules = [
        _schedule('s1', 'userA', DateTime(2026, 3, 7)),
        _schedule('s2', 'userA', DateTime(2026, 3, 8)),
        _schedule('s3', 'userA', DateTime(2026, 3, 9)),
      ];
      final anchor = schedules[1]; // middle day
      final result = findPeriodSchedules(schedules, anchor);
      expect(result.map((s) => s.id).toList(), ['s1', 's2', 's3']);
    });

    test('anchor is last day — finds all 3 consecutive days', () {
      final schedules = [
        _schedule('s1', 'userA', DateTime(2026, 3, 7)),
        _schedule('s2', 'userA', DateTime(2026, 3, 8)),
        _schedule('s3', 'userA', DateTime(2026, 3, 9)),
      ];
      final anchor = schedules[2]; // last day
      final result = findPeriodSchedules(schedules, anchor);
      expect(result.map((s) => s.id).toList(), ['s1', 's2', 's3']);
    });

    test('single day period — returns just that one schedule', () {
      final schedules = [_schedule('s1', 'userA', DateTime(2026, 3, 7))];
      final anchor = schedules[0];
      final result = findPeriodSchedules(schedules, anchor);
      expect(result.map((s) => s.id).toList(), ['s1']);
    });

    test(
      'two adjacent periods different users — anchor in A returns only A days',
      () {
        final schedules = [
          _schedule('a1', 'userA', DateTime(2026, 3, 7)),
          _schedule('a2', 'userA', DateTime(2026, 3, 8)),
          _schedule('a3', 'userA', DateTime(2026, 3, 9)),
          _schedule('b1', 'userB', DateTime(2026, 3, 10)),
          _schedule('b2', 'userB', DateTime(2026, 3, 11)),
          _schedule('b3', 'userB', DateTime(2026, 3, 12)),
        ];
        final anchor = schedules[1]; // userA middle day
        final result = findPeriodSchedules(schedules, anchor);
        expect(result.map((s) => s.id).toList(), ['a1', 'a2', 'a3']);
      },
    );

    test(
      'gap between same-user schedules — anchor in first group returns only first group',
      () {
        final schedules = [
          _schedule('a1', 'userA', DateTime(2026, 3, 1)),
          _schedule('a2', 'userA', DateTime(2026, 3, 2)),
          _schedule('a3', 'userA', DateTime(2026, 3, 3)),
          // Gap: next userA schedule is 7 days later
          _schedule('a4', 'userA', DateTime(2026, 3, 10)),
          _schedule('a5', 'userA', DateTime(2026, 3, 11)),
          _schedule('a6', 'userA', DateTime(2026, 3, 12)),
        ];
        final anchor = schedules[1]; // a2 in first group
        final result = findPeriodSchedules(schedules, anchor);
        expect(result.map((s) => s.id).toList(), ['a1', 'a2', 'a3']);
      },
    );

    test('anchor not in list — returns [anchor] as fallback', () {
      final schedules = [
        _schedule('s1', 'userA', DateTime(2026, 3, 7)),
        _schedule('s2', 'userA', DateTime(2026, 3, 8)),
      ];
      final orphan = _schedule('orphan', 'userA', DateTime(2026, 3, 9));
      final result = findPeriodSchedules(schedules, orphan);
      expect(result.length, 1);
      expect(result.first.id, 'orphan');
    });

    test(
      'mixed users interleaved — anchor in A period returns only A days',
      () {
        final schedules = [
          _schedule('a1', 'userA', DateTime(2026, 3, 7)),
          _schedule('a2', 'userA', DateTime(2026, 3, 8)),
          _schedule('a3', 'userA', DateTime(2026, 3, 9)),
          _schedule('b1', 'userB', DateTime(2026, 3, 14)),
          _schedule('b2', 'userB', DateTime(2026, 3, 15)),
          _schedule('b3', 'userB', DateTime(2026, 3, 16)),
        ];
        final anchor = schedules[1]; // a2 = userA Mar 8
        final result = findPeriodSchedules(schedules, anchor);
        expect(result.map((s) => s.id).toList(), ['a1', 'a2', 'a3']);
      },
    );

    test(
      'full swap scenario — both periods found and user_ids swapped correctly',
      () {
        // Requester (userA) has 3 days, next user (userB) has 3 days after.
        final schedules = [
          _schedule('a1', 'userA', DateTime(2026, 3, 7)),
          _schedule('a2', 'userA', DateTime(2026, 3, 8)),
          _schedule('a3', 'userA', DateTime(2026, 3, 9)),
          _schedule('b1', 'userB', DateTime(2026, 3, 14)),
          _schedule('b2', 'userB', DateTime(2026, 3, 15)),
          _schedule('b3', 'userB', DateTime(2026, 3, 16)),
        ];

        // Find requester's period using anchor a2
        final requesterAnchor = schedules[1];
        final requesterPeriod = findPeriodSchedules(schedules, requesterAnchor);
        expect(requesterPeriod.map((s) => s.id).toList(), ['a1', 'a2', 'a3']);

        // Find next user's period using anchor b1
        final nextUserAnchor = schedules[3];
        final nextUserPeriod = findPeriodSchedules(schedules, nextUserAnchor);
        expect(nextUserPeriod.map((s) => s.id).toList(), ['b1', 'b2', 'b3']);

        // Simulate swap: requester's period gets nextUserId, next user's gets requesterId
        final swappedRequesterPeriod = requesterPeriod
            .map((s) => s.copyWith(userId: 'userB'))
            .toList();
        final swappedNextUserPeriod = nextUserPeriod
            .map((s) => s.copyWith(userId: 'userA'))
            .toList();

        // Verify all requester's days now belong to userB
        expect(
          swappedRequesterPeriod.every((s) => s.userId == 'userB'),
          isTrue,
        );
        // Verify all next user's days now belong to userA
        expect(swappedNextUserPeriod.every((s) => s.userId == 'userA'), isTrue);
        // Verify dates are unchanged
        expect(
          swappedRequesterPeriod.map((s) => s.date).toList(),
          requesterPeriod.map((s) => s.date).toList(),
        );
        expect(
          swappedNextUserPeriod.map((s) => s.date).toList(),
          nextUserPeriod.map((s) => s.date).toList(),
        );
      },
    );

    test('unequal period lengths — both periods found correctly', () {
      // Requester (userA) has 3 days, next user (userB) has 2 days.
      final schedules = [
        _schedule('a1', 'userA', DateTime(2026, 3, 7)),
        _schedule('a2', 'userA', DateTime(2026, 3, 8)),
        _schedule('a3', 'userA', DateTime(2026, 3, 9)),
        _schedule('b1', 'userB', DateTime(2026, 3, 14)),
        _schedule('b2', 'userB', DateTime(2026, 3, 15)),
      ];

      final requesterPeriod = findPeriodSchedules(schedules, schedules[0]);
      expect(requesterPeriod.length, 3);
      expect(requesterPeriod.map((s) => s.id).toList(), ['a1', 'a2', 'a3']);

      final nextUserPeriod = findPeriodSchedules(schedules, schedules[3]);
      expect(nextUserPeriod.length, 2);
      expect(nextUserPeriod.map((s) => s.id).toList(), ['b1', 'b2']);
    });

    test('no next user period — only requester period is found, no crash', () {
      // Only requester's schedules exist; no next user schedules.
      final schedules = [
        _schedule('a1', 'userA', DateTime(2026, 3, 7)),
        _schedule('a2', 'userA', DateTime(2026, 3, 8)),
        _schedule('a3', 'userA', DateTime(2026, 3, 9)),
      ];

      final requesterPeriod = findPeriodSchedules(schedules, schedules[1]);
      expect(requesterPeriod.map((s) => s.id).toList(), ['a1', 'a2', 'a3']);

      // Simulate looking for next user period — no anchor found
      const nextUserId = 'userB';
      final periodEndDate = requesterPeriod.last.date;
      CleaningSchedule? nextAnchor;
      for (final s in schedules) {
        if (s.userId == nextUserId && s.date.isAfter(periodEndDate)) {
          nextAnchor = s;
          break;
        }
      }

      // No next user period found — nextAnchor is null, no crash
      expect(nextAnchor, isNull);
    });

    test('maxSize caps result — 5 consecutive same-user schedules, maxSize=3, '
        'anchor at middle returns 3', () {
      final schedules = [
        _schedule('s1', 'userA', DateTime(2026, 3, 1)),
        _schedule('s2', 'userA', DateTime(2026, 3, 2)),
        _schedule('s3', 'userA', DateTime(2026, 3, 3)), // anchor (middle)
        _schedule('s4', 'userA', DateTime(2026, 3, 4)),
        _schedule('s5', 'userA', DateTime(2026, 3, 5)),
      ];
      final anchor = schedules[2]; // s3 at middle
      final result = findPeriodSchedules(schedules, anchor, maxSize: 3);
      expect(result.length, 3);
    });

    test(
      'maxSize null behaves as before — no cap, returns all consecutive',
      () {
        final schedules = [
          _schedule('s1', 'userA', DateTime(2026, 3, 1)),
          _schedule('s2', 'userA', DateTime(2026, 3, 2)),
          _schedule('s3', 'userA', DateTime(2026, 3, 3)),
          _schedule('s4', 'userA', DateTime(2026, 3, 4)),
          _schedule('s5', 'userA', DateTime(2026, 3, 5)),
        ];
        final anchor = schedules[2]; // s3 at middle
        final result = findPeriodSchedules(schedules, anchor);
        expect(result.map((s) => s.id).toList(), [
          's1',
          's2',
          's3',
          's4',
          's5',
        ]);
      },
    );

    test(
      'maxSize larger than period — period has 3 entries, maxSize=5 returns 3',
      () {
        final schedules = [
          _schedule('s1', 'userA', DateTime(2026, 3, 1)),
          _schedule('s2', 'userA', DateTime(2026, 3, 2)),
          _schedule('s3', 'userA', DateTime(2026, 3, 3)),
        ];
        final anchor = schedules[1]; // s2 at middle
        final result = findPeriodSchedules(schedules, anchor, maxSize: 5);
        expect(result.map((s) => s.id).toList(), ['s1', 's2', 's3']);
      },
    );
  });
}
