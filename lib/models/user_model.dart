/// User roles in the application.
enum UserRole { user, admin }

/// Represents a resident user of the apartment building.
class UserModel {
  final String id;
  final String name;

  /// Room identifier, e.g. "Cuarto 3A".
  final String room;

  final UserRole role;

  /// ARGB32 integer representing the user's chosen color, or null for default.
  final int? colorValue;

  const UserModel({
    required this.id,
    required this.name,
    required this.room,
    this.role = UserRole.user,
    this.colorValue,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: json["id"] as String,
    name: json["name"] as String,
    room: json["room"] as String,
    role: json["role"] == "admin" ? UserRole.admin : UserRole.user,
    colorValue: json["color"] as int?,
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "name": name,
    "room": room,
    "role": role == UserRole.admin ? "admin" : "user",
    "color": colorValue,
  };

  /// Returns true if this user has admin privileges.
  bool get isAdmin => role == UserRole.admin;
}
