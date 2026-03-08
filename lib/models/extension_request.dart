/// Status of an extension request (prórroga).
enum ExtensionRequestStatus {
  pending,
  accepted,
  rejected;

  /// Returns the Spanish display label for this status.
  String get label => switch (this) {
    ExtensionRequestStatus.pending => 'Pendiente',
    ExtensionRequestStatus.accepted => 'Aceptada',
    ExtensionRequestStatus.rejected => 'Rechazada',
  };

  /// Parses a string value from the database into an [ExtensionRequestStatus].
  static ExtensionRequestStatus fromString(String s) => switch (s) {
    'pending' => ExtensionRequestStatus.pending,
    'accepted' => ExtensionRequestStatus.accepted,
    'rejected' => ExtensionRequestStatus.rejected,
    _ => throw ArgumentError('Unknown ExtensionRequestStatus: $s'),
  };
}

/// Model representing an extension request (prórroga) for a cleaning schedule.
class ExtensionRequest {
  /// Creates an [ExtensionRequest].
  const ExtensionRequest({
    required this.id,
    required this.scheduleId,
    required this.requesterId,
    required this.nextUserId,
    required this.status,
    required this.createdAt,
    this.resolvedAt,
  });

  /// Creates an [ExtensionRequest] from a Supabase JSON map.
  factory ExtensionRequest.fromJson(Map<String, dynamic> json) {
    return ExtensionRequest(
      id: json['id'] as String,
      scheduleId: json['schedule_id'] as String,
      requesterId: json['requester_id'] as String,
      nextUserId: json['next_user_id'] as String,
      status: ExtensionRequestStatus.fromString(json['status'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'] as String)
          : null,
    );
  }

  /// Unique identifier of this extension request.
  final String id;

  /// The cleaning schedule this request is for.
  final String scheduleId;

  /// The user who made the request.
  final String requesterId;

  /// The next user in the schedule (who would swap weeks).
  final String nextUserId;

  /// Current status of the request.
  final ExtensionRequestStatus status;

  /// When the request was created (server-generated).
  final DateTime createdAt;

  /// When the request was resolved (server-generated), or null if still pending.
  final DateTime? resolvedAt;

  /// Serializes this request for insertion into Supabase.
  ///
  /// Excludes server-generated fields: [id], [createdAt], [resolvedAt].
  Map<String, dynamic> toJson() => {
    'schedule_id': scheduleId,
    'requester_id': requesterId,
    'next_user_id': nextUserId,
    'status': status.name,
  };

  /// Returns a copy of this request with the given fields replaced.
  ExtensionRequest copyWith({
    ExtensionRequestStatus? status,
    DateTime? resolvedAt,
  }) {
    return ExtensionRequest(
      id: id,
      scheduleId: scheduleId,
      requesterId: requesterId,
      nextUserId: nextUserId,
      status: status ?? this.status,
      createdAt: createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }

  /// Returns true if this request is still pending.
  bool get isPending => status == ExtensionRequestStatus.pending;
}
