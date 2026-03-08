/// An immutable data model for anonymous comments.
///
/// Comments are anonymous by design — no [senderId] is stored.
/// The [scheduleId] links the comment to a specific cleaning schedule,
/// and the recipient is implicitly the user assigned to that schedule.
class Comment {
  final String id;
  final String scheduleId;
  final String message;
  final DateTime createdAt;

  const Comment({
    required this.id,
    required this.scheduleId,
    required this.message,
    required this.createdAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
    id: json["id"] as String,
    scheduleId: json["schedule_id"] as String,
    message: json["message"] as String,
    createdAt: DateTime.parse(json["created_at"] as String),
  );

  /// Produces Supabase-compatible JSON.
  ///
  /// Excludes [id] and [createdAt] — those are server-generated.
  Map<String, dynamic> toJson() => {
    "schedule_id": scheduleId,
    "message": message,
  };
}
