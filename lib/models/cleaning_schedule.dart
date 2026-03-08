/// Represents a cleaning schedule entry assigned to a user for a given date.
class CleaningSchedule {
  final String id;
  final String userId;
  final DateTime date;
  final bool isCompleted;

  /// Server-managed timestamp; nullable for backward compatibility.
  final DateTime? updatedAt;

  const CleaningSchedule({
    required this.id,
    required this.userId,
    required this.date,
    this.isCompleted = false,
    this.updatedAt,
  });

  factory CleaningSchedule.fromJson(Map<String, dynamic> json) =>
      CleaningSchedule(
        id: json["id"] as String,
        userId: json["user_id"] as String,
        date: DateTime.parse(json["date"] as String),
        isCompleted: json["is_completed"] as bool? ?? false,
        updatedAt: json["updated_at"] == null
            ? null
            : DateTime.parse(json["updated_at"] as String),
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
    updatedAt: updatedAt,
  );
}
