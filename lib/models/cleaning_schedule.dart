/// Represents a cleaning schedule entry assigned to a user for a given date.
class CleaningSchedule {
  final String id;
  final String userId;
  final DateTime date;
  final bool isCompleted;

  const CleaningSchedule({
    required this.id,
    required this.userId,
    required this.date,
    this.isCompleted = false,
  });
}
