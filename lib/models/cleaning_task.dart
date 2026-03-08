/// Represents one checklist item in a cleaning session.
class CleaningTask {
  final String id;
  final String scheduleId;
  final String title;
  final bool isCompleted;

  const CleaningTask({
    required this.id,
    required this.scheduleId,
    required this.title,
    this.isCompleted = false,
  });

  /// Returns a copy of this task with [isCompleted] optionally overridden.
  CleaningTask copyWith({bool? isCompleted}) => CleaningTask(
    id: id,
    scheduleId: scheduleId,
    title: title,
    isCompleted: isCompleted ?? this.isCompleted,
  );
}
