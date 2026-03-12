import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_cleanapp/models/cleaning_schedule.dart';
import 'package:flutter_cleanapp/models/extension_request.dart';

// ---------------------------------------------------------------------------
// Standalone replicas of private CalendarScreen methods (for unit testing).
// These must stay in sync with the implementations in calendar_screen.dart.
// ---------------------------------------------------------------------------

/// Replicates `_CalendarScreenState._findPeriodScheduleIds`.
///
/// Returns the IDs of consecutive same-user schedules around [anchor].
/// Walks backward and forward from the anchor in the sorted [schedules] list,
/// stopping when the user changes, dates are not consecutive, the result
/// reaches [maxSize], or the date falls outside the allowed range.
Set<String> findPeriodScheduleIds(
  List<CleaningSchedule> schedules,
  CleaningSchedule anchor, {
  int? maxSize,
}) {
  final sorted = List<CleaningSchedule>.from(schedules)
    ..sort((a, b) => a.date.compareTo(b.date));
  final idx = sorted.indexWhere((s) => s.id == anchor.id);
  if (idx == -1) return {anchor.id};

  final anchorDate = DateTime(
    anchor.date.year,
    anchor.date.month,
    anchor.date.day,
  );

  // Define the maximum date range for this period.
  final maxDays = maxSize ?? 365; // fallback to large number if no cap
  final earliestDate = anchorDate.subtract(Duration(days: maxDays - 1));
  final latestDate = anchorDate.add(Duration(days: maxDays - 1));

  final ids = <String>{anchor.id};

  // Walk backward.
  for (var i = idx - 1; i >= 0; i--) {
    if (ids.length >= maxDays) break;
    if (sorted[i].userId != anchor.userId) break;
    final schedDate = DateTime(
      sorted[i].date.year,
      sorted[i].date.month,
      sorted[i].date.day,
    );
    if (schedDate.isBefore(earliestDate)) break;
    final diff = sorted[i + 1].date.difference(sorted[i].date).inDays;
    if (diff > 1) break;
    ids.add(sorted[i].id);
  }

  // Walk forward.
  for (var i = idx + 1; i < sorted.length; i++) {
    if (ids.length >= maxDays) break;
    if (sorted[i].userId != anchor.userId) break;
    final schedDate = DateTime(
      sorted[i].date.year,
      sorted[i].date.month,
      sorted[i].date.day,
    );
    if (schedDate.isAfter(latestDate)) break;
    final diff = sorted[i].date.difference(sorted[i - 1].date).inDays;
    if (diff > 1) break;
    ids.add(sorted[i].id);
  }

  return ids;
}

/// Replicates `_CalendarScreenState._findNextUserPeriodIds`.
///
/// Returns the IDs of the next user's period that immediately follows the
/// requester's period identified by [requesterPeriodIds].
Set<String> findNextUserPeriodIds(
  List<CleaningSchedule> schedules,
  Set<String> requesterPeriodIds,
  String nextUserId,
  String requesterId,
) {
  final sorted = List<CleaningSchedule>.from(schedules)
    ..sort((a, b) => a.date.compareTo(b.date));

  // Find the last schedule in the requester's period.
  DateTime? lastRequesterDate;
  for (final s in sorted) {
    if (requesterPeriodIds.contains(s.id)) {
      final d = DateTime(s.date.year, s.date.month, s.date.day);
      if (lastRequesterDate == null || d.isAfter(lastRequesterDate)) {
        lastRequesterDate = d;
      }
    }
  }
  if (lastRequesterDate == null) return {};

  // Find the first schedule after the requester's period end where
  // userId == requesterId. After the swap, the requester's userId moved to
  // the partner's original dates, so we filter by requesterId to skip any
  // uninvolved users between the two swap participants.
  final ids = <String>{};
  CleaningSchedule? periodAnchor;
  for (final s in sorted) {
    final d = DateTime(s.date.year, s.date.month, s.date.day);
    if (d.isAfter(lastRequesterDate) &&
        !requesterPeriodIds.contains(s.id) &&
        s.userId == requesterId) {
      periodAnchor = s;
      break;
    }
  }
  if (periodAnchor == null) return {};

  // Collect the consecutive same-user period starting at periodAnchor.
  final anchorIdx = sorted.indexWhere((s) => s.id == periodAnchor!.id);
  if (anchorIdx == -1) return {};

  const cleaningPeriodDays = 3; // mirrors SupabaseService.cleaningPeriodDays
  final anchorDate = DateTime(
    periodAnchor.date.year,
    periodAnchor.date.month,
    periodAnchor.date.day,
  );
  final latestDate = anchorDate.add(
    const Duration(days: cleaningPeriodDays - 1),
  );

  ids.add(periodAnchor.id);
  for (var i = anchorIdx + 1; i < sorted.length; i++) {
    if (ids.length >= cleaningPeriodDays) break;
    if (sorted[i].userId != periodAnchor.userId) break;
    final schedDate = DateTime(
      sorted[i].date.year,
      sorted[i].date.month,
      sorted[i].date.day,
    );
    if (schedDate.isAfter(latestDate)) break;
    final diff = sorted[i].date.difference(sorted[i - 1].date).inDays;
    if (diff > 1) break;
    ids.add(sorted[i].id);
  }

  return ids;
}

/// Replicates the request-matching logic from
/// `_CalendarScreenState._getRequestForSchedule`.
///
/// Returns the matching [ExtensionRequest] for [schedule], or null if none.
ExtensionRequest? getRequestForSchedule(
  CleaningSchedule schedule,
  List<CleaningSchedule> schedules,
  List<ExtensionRequest> requests,
) {
  for (final request in requests) {
    // Find the anchor schedule referenced by the request.
    final anchor = schedules
        .where((s) => s.id == request.scheduleId)
        .firstOrNull;
    if (anchor == null) continue;

    // Build the requester's period around the anchor.
    final requesterPeriodIds = findPeriodScheduleIds(
      schedules,
      anchor,
      maxSize: 3, // mirrors SupabaseService.cleaningPeriodDays
    );
    if (requesterPeriodIds.contains(schedule.id)) return request;

    // For accepted requests, also check the next user's period.
    if (request.status == ExtensionRequestStatus.accepted) {
      final nextUserPeriodIds = findNextUserPeriodIds(
        schedules,
        requesterPeriodIds,
        request.nextUserId,
        request.requesterId,
      );
      if (nextUserPeriodIds.contains(schedule.id)) return request;
    }
  }
  return null;
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

CleaningSchedule _schedule(String id, String userId, DateTime date) {
  return CleaningSchedule(id: id, userId: userId, date: date);
}

ExtensionRequest _request(
  String id,
  String scheduleId,
  String requesterId,
  String nextUserId,
  ExtensionRequestStatus status,
) {
  return ExtensionRequest(
    id: id,
    scheduleId: scheduleId,
    requesterId: requesterId,
    nextUserId: nextUserId,
    status: status,
    createdAt: DateTime.now(),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('findPeriodScheduleIds', () {
    test('basic 3-day period — anchor at middle returns all 3 IDs', () {
      final schedules = [
        _schedule('a1', 'userA', DateTime(2026, 3, 7)),
        _schedule('a2', 'userA', DateTime(2026, 3, 8)),
        _schedule('a3', 'userA', DateTime(2026, 3, 9)),
      ];
      final result = findPeriodScheduleIds(schedules, schedules[1], maxSize: 3);
      expect(result, {'a1', 'a2', 'a3'});
    });

    test(
      'maxSize prevents over-collection — 6 consecutive same-user schedules, '
      'anchor at Mar1, maxSize=3 → only {Mar1,Mar2,Mar3}',
      () {
        // Test case 3 from spec: maxSize prevents over-collection.
        final schedules = [
          _schedule('a1', 'userA', DateTime(2026, 3, 1)),
          _schedule('a2', 'userA', DateTime(2026, 3, 2)),
          _schedule('a3', 'userA', DateTime(2026, 3, 3)),
          _schedule('a4', 'userA', DateTime(2026, 3, 4)),
          _schedule('a5', 'userA', DateTime(2026, 3, 5)),
          _schedule('a6', 'userA', DateTime(2026, 3, 6)),
        ];
        final result = findPeriodScheduleIds(
          schedules,
          schedules[0], // anchor at Mar1
          maxSize: 3,
        );
        expect(result, {'a1', 'a2', 'a3'});
      },
    );

    test('anchor not in list — returns {anchor.id} as fallback', () {
      final schedules = [
        _schedule('s1', 'userA', DateTime(2026, 3, 7)),
        _schedule('s2', 'userA', DateTime(2026, 3, 8)),
      ];
      final orphan = _schedule('orphan', 'userA', DateTime(2026, 3, 9));
      final result = findPeriodScheduleIds(schedules, orphan, maxSize: 3);
      expect(result, {'orphan'});
    });
  });

  group('findNextUserPeriodIds', () {
    test('post-swap with adjacent periods — collects next period immediately '
        'after requester period, stops at userId change', () {
      // Test case 4 from spec: post-swap with adjacent periods.
      // After swap: B has Mar7-9 (was A's), A has Mar10-12 (was B's).
      // findNextUserPeriodIds should collect Mar7-9 (userB) and stop at
      // Mar10-12 (userA — different userId).
      final schedules = [
        // userA period (requester, pre-swap dates)
        _schedule('a1', 'userA', DateTime(2026, 3, 1)),
        _schedule('a2', 'userA', DateTime(2026, 3, 2)),
        _schedule('a3', 'userA', DateTime(2026, 3, 3)),
        // userB period (immediately after requester, no gap)
        _schedule('b1', 'userB', DateTime(2026, 3, 7)),
        _schedule('b2', 'userB', DateTime(2026, 3, 8)),
        _schedule('b3', 'userB', DateTime(2026, 3, 9)),
        // userA period 2 (adjacent to userB period, different userId)
        _schedule('a4', 'userA', DateTime(2026, 3, 10)),
        _schedule('a5', 'userA', DateTime(2026, 3, 11)),
        _schedule('a6', 'userA', DateTime(2026, 3, 12)),
      ];

      final requesterPeriodIds = {'a1', 'a2', 'a3'};
      final result = findNextUserPeriodIds(
        schedules,
        requesterPeriodIds,
        'userB',
        'userB',
      );

      // Should collect b1, b2, b3 — stops at a4 (different userId).
      expect(result, {'b1', 'b2', 'b3'});
      expect(result.contains('a4'), isFalse);
      expect(result.contains('a5'), isFalse);
      expect(result.contains('a6'), isFalse);
    });

    test('findPeriodScheduleIds with adjacent same-user periods — maxSize=3 '
        'prevents collecting Mar10-12 when anchor is in Mar7-9', () {
      // Test case 4 (findPeriodScheduleIds variant): after a swap, the
      // swapped user (B) may have adjacent periods with no gap.
      // maxSize=3 prevents over-collection into the adjacent period.
      final schedules = [
        // userB period 1 (Mar7-9)
        _schedule('b1', 'userB', DateTime(2026, 3, 7)),
        _schedule('b2', 'userB', DateTime(2026, 3, 8)),
        _schedule('b3', 'userB', DateTime(2026, 3, 9)),
        // userB period 2 (Mar10-12, adjacent, no gap)
        _schedule('b4', 'userB', DateTime(2026, 3, 10)),
        _schedule('b5', 'userB', DateTime(2026, 3, 11)),
        _schedule('b6', 'userB', DateTime(2026, 3, 12)),
      ];

      // Anchor at b1 (Mar7), maxSize=3 → only {b1, b2, b3}.
      final result = findPeriodScheduleIds(
        schedules,
        schedules[0], // b1
        maxSize: 3,
      );
      expect(result, {'b1', 'b2', 'b3'});
      expect(result.contains('b4'), isFalse);
      expect(result.contains('b5'), isFalse);
      expect(result.contains('b6'), isFalse);
    });

    test(
      'post-swap with adjacent periods \u2014 maxSize prevents over-collection '
      'into next same-user period',
      () {
        // After swap with adjacent periods (no gap):
        // userB: Mar1-3 (swapped), userA: Mar4-6 (swapped), userA: Mar7-9
        // (original)
        final schedules = [
          _schedule('a1', 'userB', DateTime(2026, 3, 1)),
          _schedule('a2', 'userB', DateTime(2026, 3, 2)),
          _schedule('a3', 'userB', DateTime(2026, 3, 3)),
          _schedule('b1', 'userA', DateTime(2026, 3, 4)),
          _schedule('b2', 'userA', DateTime(2026, 3, 5)),
          _schedule('b3', 'userA', DateTime(2026, 3, 6)),
          _schedule('a4', 'userA', DateTime(2026, 3, 7)),
          _schedule('a5', 'userA', DateTime(2026, 3, 8)),
          _schedule('a6', 'userA', DateTime(2026, 3, 9)),
        ];

        final requesterPeriodIds = {'a1', 'a2', 'a3'};
        final result = findNextUserPeriodIds(
          schedules,
          requesterPeriodIds,
          'userB',
          'userA',
        );

        // Should only collect b1, b2, b3 — NOT a4, a5, a6
        expect(result, {'b1', 'b2', 'b3'});
        expect(result.contains('a4'), isFalse);
      },
    );

    test(
      'no next period — requester period is the last, returns empty set',
      () {
        final schedules = [
          _schedule('a1', 'userA', DateTime(2026, 3, 7)),
          _schedule('a2', 'userA', DateTime(2026, 3, 8)),
          _schedule('a3', 'userA', DateTime(2026, 3, 9)),
        ];
        final requesterPeriodIds = {'a1', 'a2', 'a3'};
        final result = findNextUserPeriodIds(
          schedules,
          requesterPeriodIds,
          'userB',
          'userA',
        );
        expect(result, isEmpty);
      },
    );
  });

  group('getRequestForSchedule', () {
    test('pre-swap detection — pending request anchored at A:Mar8, all 3 '
        'A-schedules (Mar7-9) return the request', () {
      // Test case 1 from spec: pre-swap detection.
      final schedules = [
        _schedule('a1', 'userA', DateTime(2026, 3, 7)),
        _schedule('a2', 'userA', DateTime(2026, 3, 8)), // anchor
        _schedule('a3', 'userA', DateTime(2026, 3, 9)),
        _schedule('b1', 'userB', DateTime(2026, 3, 14)),
        _schedule('b2', 'userB', DateTime(2026, 3, 15)),
        _schedule('b3', 'userB', DateTime(2026, 3, 16)),
      ];
      final req = _request(
        'req1',
        'a2', // anchor at Mar8
        'userA',
        'userB',
        ExtensionRequestStatus.pending,
      );
      final requests = [req];

      // All 3 A-schedules should return the request.
      expect(
        getRequestForSchedule(schedules[0], schedules, requests),
        req,
        reason: 'a1 (Mar7) should match the pending request',
      );
      expect(
        getRequestForSchedule(schedules[1], schedules, requests),
        req,
        reason: 'a2 (Mar8, anchor) should match the pending request',
      );
      expect(
        getRequestForSchedule(schedules[2], schedules, requests),
        req,
        reason: 'a3 (Mar9) should match the pending request',
      );

      // B-schedules should NOT match a pending request (only requester period).
      expect(
        getRequestForSchedule(schedules[3], schedules, requests),
        isNull,
        reason: 'b1 should not match a pending request',
      );
    });

    test('post-swap detection — accepted request, both swapped periods return '
        'the request', () {
      // Test case 2 from spec: post-swap detection.
      // After swap: B has Mar7-9 (was A's), A has Mar14-16 (was B's).
      final schedules = [
        // Mar7-9 now belongs to userB (was userA's before swap)
        _schedule('a1', 'userB', DateTime(2026, 3, 7)),
        _schedule('a2', 'userB', DateTime(2026, 3, 8)),
        _schedule('a3', 'userB', DateTime(2026, 3, 9)),
        // Mar14-16 now belongs to userA (was userB's before swap)
        _schedule('b1', 'userA', DateTime(2026, 3, 14)),
        _schedule('b2', 'userA', DateTime(2026, 3, 15)),
        _schedule('b3', 'userA', DateTime(2026, 3, 16)),
      ];
      // The request's scheduleId is the original anchor (a2),
      // requesterId=userA, nextUserId=userB.
      final req = _request(
        'req1',
        'a2', // original anchor schedule ID
        'userA',
        'userB',
        ExtensionRequestStatus.accepted,
      );
      final requests = [req];

      // All 3 schedules in Mar7-9 (now userId=B) should return the request.
      expect(
        getRequestForSchedule(schedules[0], schedules, requests),
        req,
        reason: 'a1 (Mar7, now userB) should match accepted request',
      );
      expect(
        getRequestForSchedule(schedules[1], schedules, requests),
        req,
        reason: 'a2 (Mar8, anchor, now userB) should match accepted request',
      );
      expect(
        getRequestForSchedule(schedules[2], schedules, requests),
        req,
        reason: 'a3 (Mar9, now userB) should match accepted request',
      );

      // All 3 schedules in Mar14-16 (now userId=A) should also return the
      // request (next user's period).
      expect(
        getRequestForSchedule(schedules[3], schedules, requests),
        req,
        reason: 'b1 (Mar14, now userA) should match accepted request',
      );
      expect(
        getRequestForSchedule(schedules[4], schedules, requests),
        req,
        reason: 'b2 (Mar15, now userA) should match accepted request',
      );
      expect(
        getRequestForSchedule(schedules[5], schedules, requests),
        req,
        reason: 'b3 (Mar16, now userA) should match accepted request',
      );
    });

    test(
      'no matching request — schedule not in any request period returns null',
      () {
        // Test case 5 from spec: no matching request.
        final schedules = [
          _schedule('a1', 'userA', DateTime(2026, 3, 7)),
          _schedule('a2', 'userA', DateTime(2026, 3, 8)),
          _schedule('a3', 'userA', DateTime(2026, 3, 9)),
          _schedule('b1', 'userB', DateTime(2026, 3, 14)),
          _schedule('b2', 'userB', DateTime(2026, 3, 15)),
          _schedule('b3', 'userB', DateTime(2026, 3, 16)),
          // Unrelated schedule — not part of any request
          _schedule('c1', 'userC', DateTime(2026, 3, 21)),
        ];
        final req = _request(
          'req1',
          'a2',
          'userA',
          'userB',
          ExtensionRequestStatus.pending,
        );
        final requests = [req];

        // c1 is not in any request's period → null.
        expect(
          getRequestForSchedule(schedules[6], schedules, requests),
          isNull,
        );
      },
    );

    test('rejected request — schedule in rejected request period still returns '
        'the request (for display purposes)', () {
      // Test case 6 from spec: rejected request.
      final schedules = [
        _schedule('a1', 'userA', DateTime(2026, 3, 7)),
        _schedule('a2', 'userA', DateTime(2026, 3, 8)), // anchor
        _schedule('a3', 'userA', DateTime(2026, 3, 9)),
      ];
      final req = _request(
        'req1',
        'a2',
        'userA',
        'userB',
        ExtensionRequestStatus.rejected,
      );
      final requests = [req];

      // All 3 A-schedules should still return the rejected request.
      expect(
        getRequestForSchedule(schedules[0], schedules, requests),
        req,
        reason: 'a1 should return rejected request for display',
      );
      expect(
        getRequestForSchedule(schedules[1], schedules, requests),
        req,
        reason: 'a2 (anchor) should return rejected request for display',
      );
      expect(
        getRequestForSchedule(schedules[2], schedules, requests),
        req,
        reason: 'a3 should return rejected request for display',
      );
    });
  });
}
