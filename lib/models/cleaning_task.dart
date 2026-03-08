/// Represents one checklist item in a cleaning session.
class CleaningTask {
  final String id;
  final String title;
  final int sortOrder;
  final bool isActive;

  /// Local-only UI state — not persisted to the database.
  final bool isCompleted;

  /// Deprecated: kept for backward compatibility with MockData.
  ///
  /// Tasks are now global checklist items, not per-schedule.
  final String scheduleId;

  /// Server-managed timestamp; nullable for backward compatibility.
  final DateTime? updatedAt;

  const CleaningTask({
    required this.id,
    required this.title,
    this.sortOrder = 0,
    this.isActive = true,
    this.isCompleted = false,
    this.scheduleId = '',
    this.updatedAt,
  });

  factory CleaningTask.fromJson(Map<String, dynamic> json) => CleaningTask(
    id: json["id"] as String,
    title: json["title"] as String,
    sortOrder: json["sort_order"] as int? ?? 0,
    isActive: json["is_active"] as bool? ?? true,
    updatedAt: json["updated_at"] == null
        ? null
        : DateTime.parse(json["updated_at"] as String),
  );

  Map<String, dynamic> toJson() => {
    "title": title,
    "sort_order": sortOrder,
    "is_active": isActive,
  };

  /// Returns a copy of this task with the given fields optionally overridden.
  CleaningTask copyWith({
    bool? isCompleted,
    String? title,
    int? sortOrder,
    bool? isActive,
  }) => CleaningTask(
    id: id,
    scheduleId: scheduleId,
    title: title ?? this.title,
    sortOrder: sortOrder ?? this.sortOrder,
    isActive: isActive ?? this.isActive,
    isCompleted: isCompleted ?? this.isCompleted,
    updatedAt: updatedAt,
  );
}
