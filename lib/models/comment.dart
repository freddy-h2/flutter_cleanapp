/// An immutable data model for comments with optional threading support.
///
/// Original comments are anonymous by design — [senderId] is null.
/// Replies from the responsible user have [senderId] set to their user ID.
/// The [scheduleId] links the comment to a specific cleaning schedule.
/// The [parentId] links a reply to its parent comment (null for top-level).
class Comment {
  final String id;
  final String scheduleId;
  final String message;
  final DateTime createdAt;

  /// The user who sent this comment, or null if anonymous.
  final String? senderId;

  /// The parent comment ID if this is a reply, or null if top-level.
  final String? parentId;

  const Comment({
    required this.id,
    required this.scheduleId,
    required this.message,
    required this.createdAt,
    this.senderId,
    this.parentId,
  });

  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
    id: json['id'] as String,
    scheduleId: json['schedule_id'] as String,
    message: json['message'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    senderId: json['sender_id'] as String?,
    parentId: json['parent_id'] as String?,
  );

  /// Produces Supabase-compatible JSON.
  ///
  /// Excludes [id] and [createdAt] — those are server-generated.
  /// Conditionally includes [senderId] and [parentId] only when non-null,
  /// preserving backward compatibility with existing sendComment calls.
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'schedule_id': scheduleId,
      'message': message,
    };
    if (senderId != null) json['sender_id'] = senderId;
    if (parentId != null) json['parent_id'] = parentId;
    return json;
  }

  /// Whether this comment is a reply to another comment.
  bool get isReply => parentId != null;

  /// Whether this comment is anonymous (no sender).
  bool get isAnonymous => senderId == null;
}
