/// Model representing anonymous app feedback submitted by a user.
class FeedbackModel {
  /// Unique identifier for this feedback entry.
  final String id;

  /// The feedback message text.
  final String message;

  /// When this feedback was created.
  final DateTime createdAt;

  /// Creates a [FeedbackModel] with the given fields.
  const FeedbackModel({
    required this.id,
    required this.message,
    required this.createdAt,
  });

  /// Deserializes a [FeedbackModel] from a Supabase JSON map.
  factory FeedbackModel.fromJson(Map<String, dynamic> json) => FeedbackModel(
    id: json['id'] as String,
    message: json['message'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}
