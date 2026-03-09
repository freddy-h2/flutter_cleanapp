/// A single schedule assignment produced by the cycle generator.
class CycleScheduleEntry {
  const CycleScheduleEntry({
    required this.userId,
    required this.userName,
    required this.date,
    required this.cycleNumber,
  });

  /// The user assigned to this date.
  final String userId;

  /// Display name (for preview purposes).
  final String userName;

  /// The specific date of this schedule entry.
  final DateTime date;

  /// Which cycle this entry belongs to (1-based).
  final int cycleNumber;
}

/// Generates cleaning schedule entries based on cycle parameters.
class CycleGenerator {
  CycleGenerator._();

  /// The number of days between the start of one user's period and the next.
  ///
  /// Each user starts their cleaning period 7 days after the previous user.
  static const int daysBetweenUsers = 7;

  /// Generates a flat list of [CycleScheduleEntry] for the given parameters.
  ///
  /// Parameters:
  /// - [users] — Ordered list of (userId, userName) pairs. The order determines
  ///   the rotation sequence.
  /// - [startDate] — The first day of the first user's first cleaning period.
  /// - [periodDays] — Number of consecutive cleaning days per user (default 3).
  /// - [numberOfCycles] — How many times to repeat the full user rotation.
  ///
  /// Algorithm:
  /// For each cycle (1..numberOfCycles):
  ///   For each user (in order):
  ///     The user's period start = startDate
  ///       + Duration(days: (cycleIndex * users.length + userIndex) * daysBetweenUsers)
  ///     Create [periodDays] entries: start, start+1, ..., start+(periodDays-1)
  ///
  /// Returns entries sorted by date ascending.
  static List<CycleScheduleEntry> generate({
    required List<({String id, String name})> users,
    required DateTime startDate,
    int periodDays = 3,
    int numberOfCycles = 1,
  }) {
    if (users.isEmpty || periodDays <= 0 || numberOfCycles <= 0) {
      return [];
    }

    final entries = <CycleScheduleEntry>[];

    for (var cycleIndex = 0; cycleIndex < numberOfCycles; cycleIndex++) {
      for (var userIndex = 0; userIndex < users.length; userIndex++) {
        final user = users[userIndex];
        final offsetDays =
            (cycleIndex * users.length + userIndex) * daysBetweenUsers;
        final periodStart = startDate.add(Duration(days: offsetDays));

        for (var day = 0; day < periodDays; day++) {
          entries.add(
            CycleScheduleEntry(
              userId: user.id,
              userName: user.name,
              date: periodStart.add(Duration(days: day)),
              cycleNumber: cycleIndex + 1,
            ),
          );
        }
      }
    }

    entries.sort((a, b) => a.date.compareTo(b.date));
    return entries;
  }
}
