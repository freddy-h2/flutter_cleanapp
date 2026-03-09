import 'package:flutter_cleanapp/utils/cycle_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CycleGenerator', () {
    final users = [
      (id: 'user-a', name: 'Alice'),
      (id: 'user-b', name: 'Bob'),
      (id: 'user-c', name: 'Charlie'),
    ];

    final startDate = DateTime(2026, 3, 7); // March 7, 2026

    test(
      '1. Basic 3-user, 1-cycle, 3-day period produces 9 entries with correct dates',
      () {
        final entries = CycleGenerator.generate(
          users: users,
          startDate: startDate,
          periodDays: 3,
          numberOfCycles: 1,
        );

        expect(entries.length, 9);

        // Alice: Mar 7, 8, 9
        expect(entries[0].userId, 'user-a');
        expect(entries[0].date, DateTime(2026, 3, 7));
        expect(entries[1].userId, 'user-a');
        expect(entries[1].date, DateTime(2026, 3, 8));
        expect(entries[2].userId, 'user-a');
        expect(entries[2].date, DateTime(2026, 3, 9));

        // Bob: Mar 14, 15, 16
        expect(entries[3].userId, 'user-b');
        expect(entries[3].date, DateTime(2026, 3, 14));
        expect(entries[4].userId, 'user-b');
        expect(entries[4].date, DateTime(2026, 3, 15));
        expect(entries[5].userId, 'user-b');
        expect(entries[5].date, DateTime(2026, 3, 16));

        // Charlie: Mar 21, 22, 23
        expect(entries[6].userId, 'user-c');
        expect(entries[6].date, DateTime(2026, 3, 21));
        expect(entries[7].userId, 'user-c');
        expect(entries[7].date, DateTime(2026, 3, 22));
        expect(entries[8].userId, 'user-c');
        expect(entries[8].date, DateTime(2026, 3, 23));
      },
    );

    test(
      '2. 3-user, 2-cycle, 3-day period produces 18 entries with correct dates',
      () {
        final entries = CycleGenerator.generate(
          users: users,
          startDate: startDate,
          periodDays: 3,
          numberOfCycles: 2,
        );

        expect(entries.length, 18);

        // Cycle 2 - Alice: Mar 28, 29, 30
        expect(entries[9].userId, 'user-a');
        expect(entries[9].date, DateTime(2026, 3, 28));
        expect(entries[10].userId, 'user-a');
        expect(entries[10].date, DateTime(2026, 3, 29));
        expect(entries[11].userId, 'user-a');
        expect(entries[11].date, DateTime(2026, 3, 30));

        // Cycle 2 - Bob: Apr 4, 5, 6
        expect(entries[12].userId, 'user-b');
        expect(entries[12].date, DateTime(2026, 4, 4));
        expect(entries[13].userId, 'user-b');
        expect(entries[13].date, DateTime(2026, 4, 5));
        expect(entries[14].userId, 'user-b');
        expect(entries[14].date, DateTime(2026, 4, 6));

        // Cycle 2 - Charlie: Apr 11, 12, 13
        expect(entries[15].userId, 'user-c');
        expect(entries[15].date, DateTime(2026, 4, 11));
        expect(entries[16].userId, 'user-c');
        expect(entries[16].date, DateTime(2026, 4, 12));
        expect(entries[17].userId, 'user-c');
        expect(entries[17].date, DateTime(2026, 4, 13));
      },
    );

    test('3. Single user, 1 cycle produces 3 entries', () {
      final singleUser = [(id: 'user-a', name: 'Alice')];
      final entries = CycleGenerator.generate(
        users: singleUser,
        startDate: startDate,
        periodDays: 3,
        numberOfCycles: 1,
      );

      expect(entries.length, 3);
      expect(entries[0].userId, 'user-a');
      expect(entries[0].date, DateTime(2026, 3, 7));
      expect(entries[1].date, DateTime(2026, 3, 8));
      expect(entries[2].date, DateTime(2026, 3, 9));
    });

    test('4. Empty users list returns empty result', () {
      final entries = CycleGenerator.generate(users: [], startDate: startDate);

      expect(entries, isEmpty);
    });

    test('5. numberOfCycles = 0 returns empty result', () {
      final entries = CycleGenerator.generate(
        users: users,
        startDate: startDate,
        numberOfCycles: 0,
      );

      expect(entries, isEmpty);
    });

    test('6. periodDays = 0 returns empty result', () {
      final entries = CycleGenerator.generate(
        users: users,
        startDate: startDate,
        periodDays: 0,
      );

      expect(entries, isEmpty);
    });

    test('7. periodDays = 1 produces one entry per user per cycle', () {
      final entries = CycleGenerator.generate(
        users: users,
        startDate: startDate,
        periodDays: 1,
        numberOfCycles: 1,
      );

      expect(entries.length, 3);
      expect(entries[0].date, DateTime(2026, 3, 7));
      expect(entries[1].date, DateTime(2026, 3, 14));
      expect(entries[2].date, DateTime(2026, 3, 21));
    });

    test('8. Custom periodDays = 5 produces correct consecutive dates', () {
      final singleUser = [(id: 'user-a', name: 'Alice')];
      final entries = CycleGenerator.generate(
        users: singleUser,
        startDate: startDate,
        periodDays: 5,
        numberOfCycles: 1,
      );

      expect(entries.length, 5);
      for (var i = 0; i < 5; i++) {
        expect(entries[i].date, startDate.add(Duration(days: i)));
      }
    });

    test('9. cycleNumber is correctly assigned (1-based)', () {
      final entries = CycleGenerator.generate(
        users: users,
        startDate: startDate,
        periodDays: 1,
        numberOfCycles: 2,
      );

      // First 3 entries are cycle 1
      for (var i = 0; i < 3; i++) {
        expect(entries[i].cycleNumber, 1);
      }
      // Next 3 entries are cycle 2
      for (var i = 3; i < 6; i++) {
        expect(entries[i].cycleNumber, 2);
      }
    });

    test('10. Entries are sorted by date ascending', () {
      final entries = CycleGenerator.generate(
        users: users,
        startDate: startDate,
        periodDays: 3,
        numberOfCycles: 2,
      );

      for (var i = 1; i < entries.length; i++) {
        expect(
          entries[i].date.isAfter(entries[i - 1].date) ||
              entries[i].date.isAtSameMomentAs(entries[i - 1].date),
          isTrue,
          reason:
              'Entry $i (${entries[i].date}) should be >= entry ${i - 1} (${entries[i - 1].date})',
        );
      }
    });

    test('11. daysBetweenUsers constant is 7', () {
      expect(CycleGenerator.daysBetweenUsers, 7);
    });

    test('12. userName is correctly assigned from user record', () {
      final entries = CycleGenerator.generate(
        users: users,
        startDate: startDate,
        periodDays: 1,
        numberOfCycles: 1,
      );

      expect(entries[0].userName, 'Alice');
      expect(entries[1].userName, 'Bob');
      expect(entries[2].userName, 'Charlie');
    });
  });
}
