import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_cleanapp/models/cleaning_schedule.dart';
import 'package:flutter_cleanapp/models/user_model.dart';

/// Represents a grouped period of schedules for the same user.
/// Replicates _PeriodEntry from calendar_screen.dart.
class PeriodEntry {
  PeriodEntry({required this.schedules, required this.user});
  final List<CleaningSchedule> schedules;
  final UserModel user;
}

/// Replicates the period grouping logic from CalendarScreen.build().
/// Groups consecutive same-user schedules into periods, splitting on
/// date gaps > 1 day.
List<PeriodEntry> groupIntoPeriods(
  List<CleaningSchedule> schedules,
  List<UserModel> users,
) {
  final sorted = List<CleaningSchedule>.from(schedules)
    ..sort((a, b) => a.date.compareTo(b.date));

  final periods = <PeriodEntry>[];
  for (final schedule in sorted) {
    final user = users.firstWhere(
      (u) => u.id == schedule.userId,
      orElse: () => const UserModel(id: '', name: '?', room: ''),
    );
    if (periods.isNotEmpty && periods.last.user.id == schedule.userId) {
      final lastDate = periods.last.schedules.last.date;
      final currentDate = schedule.date;
      final daysDiff =
          DateTime(currentDate.year, currentDate.month, currentDate.day)
              .difference(DateTime(lastDate.year, lastDate.month, lastDate.day))
              .inDays;
      if (daysDiff <= 1) {
        periods.last.schedules.add(schedule);
      } else {
        periods.add(PeriodEntry(schedules: [schedule], user: user));
      }
    } else {
      periods.add(PeriodEntry(schedules: [schedule], user: user));
    }
  }
  return periods;
}

CleaningSchedule _schedule(String id, String userId, DateTime date) {
  return CleaningSchedule(id: id, userId: userId, date: date);
}

const UserModel _userA = UserModel(id: 'userA', name: 'Alice', room: '1A');
const UserModel _userB = UserModel(id: 'userB', name: 'Bob', room: '1B');
const UserModel _userC = UserModel(id: 'userC', name: 'Carol', room: '1C');

void main() {
  group('groupIntoPeriods', () {
    test(
      'basic grouping — no swap, alternating users → 4 PeriodEntry objects',
      () {
        // A(Mar1-3), B(Mar8-10), A(Mar15-17), B(Mar22-24) — gaps between each
        final schedules = [
          _schedule('a1', 'userA', DateTime(2026, 3, 1)),
          _schedule('a2', 'userA', DateTime(2026, 3, 2)),
          _schedule('a3', 'userA', DateTime(2026, 3, 3)),
          _schedule('b1', 'userB', DateTime(2026, 3, 8)),
          _schedule('b2', 'userB', DateTime(2026, 3, 9)),
          _schedule('b3', 'userB', DateTime(2026, 3, 10)),
          _schedule('a4', 'userA', DateTime(2026, 3, 15)),
          _schedule('a5', 'userA', DateTime(2026, 3, 16)),
          _schedule('a6', 'userA', DateTime(2026, 3, 17)),
          _schedule('b4', 'userB', DateTime(2026, 3, 22)),
          _schedule('b5', 'userB', DateTime(2026, 3, 23)),
          _schedule('b6', 'userB', DateTime(2026, 3, 24)),
        ];
        final users = [_userA, _userB];

        final result = groupIntoPeriods(schedules, users);

        expect(result.length, 4);
        expect(result[0].user.id, 'userA');
        expect(result[0].schedules.length, 3);
        expect(result[1].user.id, 'userB');
        expect(result[1].schedules.length, 3);
        expect(result[2].user.id, 'userA');
        expect(result[2].schedules.length, 3);
        expect(result[3].user.id, 'userB');
        expect(result[3].schedules.length, 3);
      },
    );

    test('post-swap grouping — swapped first cycle → 4 separate PeriodEntry '
        'objects (not 3)', () {
      // After swap: B(Mar1-3), A(Mar8-10), A(Mar15-17), B(Mar22-24).
      // Despite a4-a6 (Mar8-10) and a7-a9 (Mar15-17) both being userA,
      // the date gap (Mar10→Mar15 = 5 days) causes them to be separate.
      final schedules = [
        _schedule('b1', 'userB', DateTime(2026, 3, 1)),
        _schedule('b2', 'userB', DateTime(2026, 3, 2)),
        _schedule('b3', 'userB', DateTime(2026, 3, 3)),
        _schedule('a1', 'userA', DateTime(2026, 3, 8)),
        _schedule('a2', 'userA', DateTime(2026, 3, 9)),
        _schedule('a3', 'userA', DateTime(2026, 3, 10)),
        _schedule('a4', 'userA', DateTime(2026, 3, 15)),
        _schedule('a5', 'userA', DateTime(2026, 3, 16)),
        _schedule('a6', 'userA', DateTime(2026, 3, 17)),
        _schedule('b4', 'userB', DateTime(2026, 3, 22)),
        _schedule('b5', 'userB', DateTime(2026, 3, 23)),
        _schedule('b6', 'userB', DateTime(2026, 3, 24)),
      ];
      final users = [_userA, _userB];

      final result = groupIntoPeriods(schedules, users);

      expect(
        result.length,
        4,
        reason: 'Mar10→Mar15 gap of 5 days must split the two userA periods',
      );
      expect(result[0].user.id, 'userB');
      expect(result[0].schedules.length, 3);
      expect(result[1].user.id, 'userA');
      expect(result[1].schedules.length, 3);
      expect(result[2].user.id, 'userA');
      expect(result[2].schedules.length, 3);
      expect(result[3].user.id, 'userB');
      expect(result[3].schedules.length, 3);
    });

    test(
      'consecutive same-user dates — no gap: Mar1, Mar2, Mar3 → 1 period',
      () {
        final schedules = [
          _schedule('a1', 'userA', DateTime(2026, 3, 1)),
          _schedule('a2', 'userA', DateTime(2026, 3, 2)),
          _schedule('a3', 'userA', DateTime(2026, 3, 3)),
        ];
        final users = [_userA];

        final result = groupIntoPeriods(schedules, users);

        expect(result.length, 1);
        expect(result[0].schedules.length, 3);
        expect(result[0].user.id, 'userA');
      },
    );

    test('same user with 1-day gap — Mar1, Mar2, Mar3 (diff=1) → 1 period '
        '(verifies <= 1 threshold)', () {
      // All consecutive days have diff=1, which satisfies daysDiff <= 1.
      final schedules = [
        _schedule('a1', 'userA', DateTime(2026, 3, 1)),
        _schedule('a2', 'userA', DateTime(2026, 3, 2)),
        _schedule('a3', 'userA', DateTime(2026, 3, 3)),
      ];
      final users = [_userA];

      final result = groupIntoPeriods(schedules, users);

      expect(result.length, 1);
      expect(result[0].schedules.length, 3);
    });

    test(
      'same user with 2-day gap — Mar1, Mar2, Mar4 → 2 PeriodEntry objects',
      () {
        // Mar2→Mar4 gap is 2 days, which exceeds the <= 1 threshold.
        final schedules = [
          _schedule('a1', 'userA', DateTime(2026, 3, 1)),
          _schedule('a2', 'userA', DateTime(2026, 3, 2)),
          _schedule('a3', 'userA', DateTime(2026, 3, 4)),
        ];
        final users = [_userA];

        final result = groupIntoPeriods(schedules, users);

        expect(
          result.length,
          2,
          reason: 'Mar2→Mar4 gap of 2 days must split into 2 periods',
        );
        expect(result[0].schedules.length, 2);
        expect(result[0].schedules.map((s) => s.id), containsAll(['a1', 'a2']));
        expect(result[1].schedules.length, 1);
        expect(result[1].schedules.first.id, 'a3');
      },
    );

    test('different users no gap — userA Mar1-3, userB Mar4-6 (adjacent) → '
        '2 PeriodEntry objects', () {
      // Even though Mar3→Mar4 is only 1 day apart, different users force
      // a new period.
      final schedules = [
        _schedule('a1', 'userA', DateTime(2026, 3, 1)),
        _schedule('a2', 'userA', DateTime(2026, 3, 2)),
        _schedule('a3', 'userA', DateTime(2026, 3, 3)),
        _schedule('b1', 'userB', DateTime(2026, 3, 4)),
        _schedule('b2', 'userB', DateTime(2026, 3, 5)),
        _schedule('b3', 'userB', DateTime(2026, 3, 6)),
      ];
      final users = [_userA, _userB];

      final result = groupIntoPeriods(schedules, users);

      expect(result.length, 2);
      expect(result[0].user.id, 'userA');
      expect(result[1].user.id, 'userB');
    });

    test(
      'post-swap with 3 users — swap A↔B first cycle → 6 separate periods',
      () {
        // userA, userB, userC. Swap A↔B first cycle.
        // Result: B(Mar1-3), A(Mar8-10), C(Mar15-17), A(Mar22-24),
        //         B(Mar29-31), C(Apr5-7) → 6 separate periods.
        final schedules = [
          _schedule('b1', 'userB', DateTime(2026, 3, 1)),
          _schedule('b2', 'userB', DateTime(2026, 3, 2)),
          _schedule('b3', 'userB', DateTime(2026, 3, 3)),
          _schedule('a1', 'userA', DateTime(2026, 3, 8)),
          _schedule('a2', 'userA', DateTime(2026, 3, 9)),
          _schedule('a3', 'userA', DateTime(2026, 3, 10)),
          _schedule('c1', 'userC', DateTime(2026, 3, 15)),
          _schedule('c2', 'userC', DateTime(2026, 3, 16)),
          _schedule('c3', 'userC', DateTime(2026, 3, 17)),
          _schedule('a4', 'userA', DateTime(2026, 3, 22)),
          _schedule('a5', 'userA', DateTime(2026, 3, 23)),
          _schedule('a6', 'userA', DateTime(2026, 3, 24)),
          _schedule('b4', 'userB', DateTime(2026, 3, 29)),
          _schedule('b5', 'userB', DateTime(2026, 3, 30)),
          _schedule('b6', 'userB', DateTime(2026, 3, 31)),
          _schedule('c4', 'userC', DateTime(2026, 4, 5)),
          _schedule('c5', 'userC', DateTime(2026, 4, 6)),
          _schedule('c6', 'userC', DateTime(2026, 4, 7)),
        ];
        final users = [_userA, _userB, _userC];

        final result = groupIntoPeriods(schedules, users);

        expect(result.length, 6);
        expect(result[0].user.id, 'userB');
        expect(result[1].user.id, 'userA');
        expect(result[2].user.id, 'userC');
        expect(result[3].user.id, 'userA');
        expect(result[4].user.id, 'userB');
        expect(result[5].user.id, 'userC');
      },
    );

    test('empty schedules → empty list', () {
      final result = groupIntoPeriods([], [_userA, _userB]);
      expect(result, isEmpty);
    });

    test('single schedule → 1 PeriodEntry with 1 schedule', () {
      final schedules = [_schedule('a1', 'userA', DateTime(2026, 3, 1))];
      final users = [_userA];

      final result = groupIntoPeriods(schedules, users);

      expect(result.length, 1);
      expect(result[0].schedules.length, 1);
      expect(result[0].schedules.first.id, 'a1');
      expect(result[0].user.id, 'userA');
    });
  });
}
