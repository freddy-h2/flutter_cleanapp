/// The type of an announcement.
enum AnnouncementType {
  /// A general notice or information message.
  aviso,

  /// A reminder notification.
  recordatorio,

  /// An app update notification with an optional download link.
  update;

  /// Converts a string value from the database to an [AnnouncementType].
  ///
  /// Defaults to [AnnouncementType.aviso] for unknown values.
  static AnnouncementType fromString(String s) => switch (s) {
    'aviso' => AnnouncementType.aviso,
    'recordatorio' => AnnouncementType.recordatorio,
    'update' => AnnouncementType.update,
    _ => AnnouncementType.aviso,
  };
}

/// Model representing an announcement sent by an admin to all users.
class Announcement {
  /// Unique identifier for this announcement.
  final String id;

  /// The profile ID of the admin who created this announcement.
  final String senderId;

  /// Short title of the announcement.
  final String title;

  /// Full message body of the announcement.
  final String message;

  /// The type of announcement (aviso, recordatorio, or update).
  final AnnouncementType type;

  /// Optional download link, used when [type] is [AnnouncementType.update].
  final String? link;

  /// Whether this announcement is currently active and visible to users.
  final bool isActive;

  /// When this announcement was created.
  final DateTime createdAt;

  /// Creates an [Announcement] with the given fields.
  const Announcement({
    required this.id,
    required this.senderId,
    required this.title,
    required this.message,
    required this.type,
    this.link,
    this.isActive = true,
    required this.createdAt,
  });

  /// Deserializes an [Announcement] from a Supabase JSON map.
  factory Announcement.fromJson(Map<String, dynamic> json) => Announcement(
    id: json['id'] as String,
    senderId: json['sender_id'] as String,
    title: json['title'] as String,
    message: json['message'] as String,
    type: AnnouncementType.fromString(json['type'] as String),
    link: json['link'] as String?,
    isActive: json['is_active'] as bool? ?? true,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}
