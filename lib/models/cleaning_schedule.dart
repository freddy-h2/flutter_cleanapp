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

  factory CleaningSchedule.fromJson(Map<String, dynamic> json) =>
      CleaningSchedule(
        id: json["id"] as String,
        userId: json["user_id"] as String,
        date: DateTime.parse(json["date"] as String),
        isCompleted: json["is_completed"] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
    "user_id": userId,
    "date": date.toIso8601String().split("T").first,
    "is_completed": isCompleted,
  };

  /// Returns a copy of this schedule with the given fields overridden.
  CleaningSchedule copyWith({
    bool? isCompleted,
    DateTime? date,
    String? userId,
  }) => CleaningSchedule(
    id: id,
    userId: userId ?? this.userId,
    date: date ?? this.date,
    isCompleted: isCompleted ?? this.isCompleted,
  );
}
