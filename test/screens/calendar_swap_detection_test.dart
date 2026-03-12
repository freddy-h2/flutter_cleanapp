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

    // Test 1: non-adjacent swap skips uninvolved user
    test('non-adjacent swap — skips uninvolved userB, returns userA period '
        '(Mar 14-16)', () {
      // Post-swap state: A↔C swap, B is uninvolved in between.
      // C: Mar 1-3 (was A's, now userId=userC, nextUserId=userC)
      // B: Mar 7-9 (unchanged, uninvolved)
      // A: Mar 14-16 (was C's, now userId=userA, requesterId=userA)
      final schedules = [
        _schedule('c1', 'userC', DateTime(2026, 3, 1)),
        _schedule('c2', 'userC', DateTime(2026, 3, 2)),
        _schedule('c3', 'userC', DateTime(2026, 3, 3)),
        _schedule('b1', 'userB', DateTime(2026, 3, 7)),
        _schedule('b2', 'userB', DateTime(2026, 3, 8)),
        _schedule('b3', 'userB', DateTime(2026, 3, 9)),
        _schedule('a1', 'userA', DateTime(2026, 3, 14)),
        _schedule('a2', 'userA', DateTime(2026, 3, 15)),
        _schedule('a3', 'userA', DateTime(2026, 3, 16)),
      ];

      // requesterPeriodIds = schedules for Mar 1-3 (now userC)
      final requesterPeriodIds = {'c1', 'c2', 'c3'};
      final result = findNextUserPeriodIds(
        schedules,
        requesterPeriodIds,
        'userC', // nextUserId
        'userA', // requesterId — filter by this to skip userB
      );

      // Must return userA's period (Mar 14-16), NOT userB's (Mar 7-9).
      expect(result, {'a1', 'a2', 'a3'});
      expect(result.contains('b1'), isFalse, reason: 'b1 must be excluded');
      expect(result.contains('b2'), isFalse, reason: 'b2 must be excluded');
      expect(result.contains('b3'), isFalse, reason: 'b3 must be excluded');
    });

    // Test 4: adjacent swap still works (regression guard)
    test('adjacent swap regression — B immediately after A, returns B period '
        '(Mar 7-9)', () {
      // Post-swap state: A↔B adjacent swap.
      // B: Mar 1-3 (was A's, now userId=userB)
      // A: Mar 7-9 (was B's, now userId=userA)
      final schedules = [
        _schedule('b1', 'userB', DateTime(2026, 3, 1)),
        _schedule('b2', 'userB', DateTime(2026, 3, 2)),
        _schedule('b3', 'userB', DateTime(2026, 3, 3)),
        _schedule('a1', 'userA', DateTime(2026, 3, 7)),
        _schedule('a2', 'userA', DateTime(2026, 3, 8)),
        _schedule('a3', 'userA', DateTime(2026, 3, 9)),
      ];

      final requesterPeriodIds = {'b1', 'b2', 'b3'};
      final result = findNextUserPeriodIds(
        schedules,
        requesterPeriodIds,
        'userB', // nextUserId
        'userA', // requesterId
      );

      // Should return userA's period (Mar 7-9).
      expect(result, {'a1', 'a2', 'a3'});
    });
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

    // Test 2: non-adjacent accepted swap labels only involved periods
    test('non-adjacent accepted swap — only A and C periods labeled, B returns '
        'null', () {
      // Post-swap state: A↔C swap, B is uninvolved.
      // C: Mar 1-3 (was A's, anchor a2 is here, now userId=userC)
      // B: Mar 7-9 (unchanged, uninvolved)
      // A: Mar 14-16 (was C's, now userId=userA)
      final schedules = [
        _schedule('a1', 'userC', DateTime(2026, 3, 1)),
        _schedule('a2', 'userC', DateTime(2026, 3, 2)), // anchor
        _schedule('a3', 'userC', DateTime(2026, 3, 3)),
        _schedule('b1', 'userB', DateTime(2026, 3, 7)),
        _schedule('b2', 'userB', DateTime(2026, 3, 8)),
        _schedule('b3', 'userB', DateTime(2026, 3, 9)),
        _schedule('c1', 'userA', DateTime(2026, 3, 14)),
        _schedule('c2', 'userA', DateTime(2026, 3, 15)),
        _schedule('c3', 'userA', DateTime(2026, 3, 16)),
      ];
      final req = _request(
        'req1',
        'a2', // anchor in Mar 1-3 (now userC)
        'userA',
        'userC',
        ExtensionRequestStatus.accepted,
      );
      final requests = [req];

      // a1, a2, a3 (Mar 1-3, now userC) → return the request.
      expect(
        getRequestForSchedule(schedules[0], schedules, requests),
        req,
        reason: 'a1 (Mar1, now userC) should match accepted request',
      );
      expect(
        getRequestForSchedule(schedules[1], schedules, requests),
        req,
        reason: 'a2 (Mar2, anchor, now userC) should match accepted request',
      );
      expect(
        getRequestForSchedule(schedules[2], schedules, requests),
        req,
        reason: 'a3 (Mar3, now userC) should match accepted request',
      );

      // b1, b2, b3 (Mar 7-9, userB, uninvolved) → return null (bug fix).
      expect(
        getRequestForSchedule(schedules[3], schedules, requests),
        isNull,
        reason: 'b1 (Mar7, userB, uninvolved) must NOT match — bug fix',
      );
      expect(
        getRequestForSchedule(schedules[4], schedules, requests),
        isNull,
        reason: 'b2 (Mar8, userB, uninvolved) must NOT match — bug fix',
      );
      expect(
        getRequestForSchedule(schedules[5], schedules, requests),
        isNull,
        reason: 'b3 (Mar9, userB, uninvolved) must NOT match — bug fix',
      );

      // c1, c2, c3 (Mar 14-16, now userA) → return the request.
      expect(
        getRequestForSchedule(schedules[6], schedules, requests),
        req,
        reason: 'c1 (Mar14, now userA) should match accepted request',
      );
      expect(
        getRequestForSchedule(schedules[7], schedules, requests),
        req,
        reason: 'c2 (Mar15, now userA) should match accepted request',
      );
      expect(
        getRequestForSchedule(schedules[8], schedules, requests),
        req,
        reason: 'c3 (Mar16, now userA) should match accepted request',
      );
    });

    // Test 3: non-adjacent pending request only labels requester period
    test('non-adjacent pending request — only requester period (A) labeled, '
        'B and C return null', () {
      // Pre-swap state: A wants to swap with C, B is uninvolved.
      // A: Mar 1-3 (requester, anchor a2)
      // B: Mar 7-9 (uninvolved)
      // C: Mar 14-16 (target, not yet swapped)
      final schedules = [
        _schedule('a1', 'userA', DateTime(2026, 3, 1)),
        _schedule('a2', 'userA', DateTime(2026, 3, 2)), // anchor
        _schedule('a3', 'userA', DateTime(2026, 3, 3)),
        _schedule('b1', 'userB', DateTime(2026, 3, 7)),
        _schedule('b2', 'userB', DateTime(2026, 3, 8)),
        _schedule('b3', 'userB', DateTime(2026, 3, 9)),
        _schedule('c1', 'userC', DateTime(2026, 3, 14)),
        _schedule('c2', 'userC', DateTime(2026, 3, 15)),
        _schedule('c3', 'userC', DateTime(2026, 3, 16)),
      ];
      final req = _request(
        'req1',
        'a2',
        'userA',
        'userC',
        ExtensionRequestStatus.pending,
      );
      final requests = [req];

      // a1, a2, a3 (Mar 1-3, userA) → return the request.
      expect(
        getRequestForSchedule(schedules[0], schedules, requests),
        req,
        reason: 'a1 (Mar1, userA) should match pending request',
      );
      expect(
        getRequestForSchedule(schedules[1], schedules, requests),
        req,
        reason: 'a2 (Mar2, anchor) should match pending request',
      );
      expect(
        getRequestForSchedule(schedules[2], schedules, requests),
        req,
        reason: 'a3 (Mar3, userA) should match pending request',
      );

      // b1, b2, b3 (Mar 7-9, userB) → return null.
      expect(
        getRequestForSchedule(schedules[3], schedules, requests),
        isNull,
        reason: 'b1 (Mar7, userB) must NOT match pending request',
      );
      expect(
        getRequestForSchedule(schedules[4], schedules, requests),
        isNull,
        reason: 'b2 (Mar8, userB) must NOT match pending request',
      );
      expect(
        getRequestForSchedule(schedules[5], schedules, requests),
        isNull,
        reason: 'b3 (Mar9, userB) must NOT match pending request',
      );

      // c1, c2, c3 (Mar 14-16, userC) → return null (pending doesn't show
      // on target).
      expect(
        getRequestForSchedule(schedules[6], schedules, requests),
        isNull,
        reason: 'c1 (Mar14, userC) must NOT match pending request',
      );
      expect(
        getRequestForSchedule(schedules[7], schedules, requests),
        isNull,
        reason: 'c2 (Mar15, userC) must NOT match pending request',
      );
      expect(
        getRequestForSchedule(schedules[8], schedules, requests),
        isNull,
        reason: 'c3 (Mar16, userC) must NOT match pending request',
      );
    });

    // Test 5: 4 users, swap between 1st and 4th
    test('4-user schedule — swap between 1st and 4th, B and C return null', () {
      // Post-swap state: A↔D swap, B and C are uninvolved.
      // D: Mar 1-3 (was A's, now userId=userD)
      // B: Mar 7-9 (unchanged)
      // C: Mar 14-16 (unchanged)
      // A: Mar 21-23 (was D's, now userId=userA)
      final schedules = [
        _schedule('a1', 'userD', DateTime(2026, 3, 1)),
        _schedule('a2', 'userD', DateTime(2026, 3, 2)), // anchor
        _schedule('a3', 'userD', DateTime(2026, 3, 3)),
        _schedule('b1', 'userB', DateTime(2026, 3, 7)),
        _schedule('b2', 'userB', DateTime(2026, 3, 8)),
        _schedule('b3', 'userB', DateTime(2026, 3, 9)),
        _schedule('c1', 'userC', DateTime(2026, 3, 14)),
        _schedule('c2', 'userC', DateTime(2026, 3, 15)),
        _schedule('c3', 'userC', DateTime(2026, 3, 16)),
        _schedule('d1', 'userA', DateTime(2026, 3, 21)),
        _schedule('d2', 'userA', DateTime(2026, 3, 22)),
        _schedule('d3', 'userA', DateTime(2026, 3, 23)),
      ];
      final req = _request(
        'req1',
        'a2', // anchor in Mar 1-3 (now userD)
        'userA',
        'userD',
        ExtensionRequestStatus.accepted,
      );
      final requests = [req];

      // A's original period (Mar 1-3, now userD) → return request.
      expect(
        getRequestForSchedule(schedules[0], schedules, requests),
        req,
        reason: 'a1 (Mar1, now userD) should match accepted request',
      );
      expect(
        getRequestForSchedule(schedules[1], schedules, requests),
        req,
        reason: 'a2 (Mar2, anchor, now userD) should match accepted request',
      );
      expect(
        getRequestForSchedule(schedules[2], schedules, requests),
        req,
        reason: 'a3 (Mar3, now userD) should match accepted request',
      );

      // B's period (Mar 7-9) → return null.
      expect(
        getRequestForSchedule(schedules[3], schedules, requests),
        isNull,
        reason: 'b1 (Mar7, userB) must NOT match — uninvolved',
      );
      expect(
        getRequestForSchedule(schedules[4], schedules, requests),
        isNull,
        reason: 'b2 (Mar8, userB) must NOT match — uninvolved',
      );
      expect(
        getRequestForSchedule(schedules[5], schedules, requests),
        isNull,
        reason: 'b3 (Mar9, userB) must NOT match — uninvolved',
      );

      // C's period (Mar 14-16) → return null.
      expect(
        getRequestForSchedule(schedules[6], schedules, requests),
        isNull,
        reason: 'c1 (Mar14, userC) must NOT match — uninvolved',
      );
      expect(
        getRequestForSchedule(schedules[7], schedules, requests),
        isNull,
        reason: 'c2 (Mar15, userC) must NOT match — uninvolved',
      );
      expect(
        getRequestForSchedule(schedules[8], schedules, requests),
        isNull,
        reason: 'c3 (Mar16, userC) must NOT match — uninvolved',
      );

      // D's original period (Mar 21-23, now userA) → return request.
      expect(
        getRequestForSchedule(schedules[9], schedules, requests),
        req,
        reason: 'd1 (Mar21, now userA) should match accepted request',
      );
      expect(
        getRequestForSchedule(schedules[10], schedules, requests),
        req,
        reason: 'd2 (Mar22, now userA) should match accepted request',
      );
      expect(
        getRequestForSchedule(schedules[11], schedules, requests),
        req,
        reason: 'd3 (Mar23, now userA) should match accepted request',
      );
    });

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
