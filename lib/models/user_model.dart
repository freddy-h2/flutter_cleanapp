/// User roles in the application.
enum UserRole { user, admin }

/// Represents a resident user of the apartment building.
class UserModel {
  final String id;
  final String name;

  /// Room identifier, e.g. "Cuarto 3A".
  final String room;

  final UserRole role;

  const UserModel({
    required this.id,
    required this.name,
    required this.room,
    this.role = UserRole.user,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: json["id"] as String,
    name: json["name"] as String,
    room: json["room"] as String,
    role: json["role"] == "admin" ? UserRole.admin : UserRole.user,
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "name": name,
    "room": room,
    "role": role == UserRole.admin ? "admin" : "user",
  };

  /// Returns true if this user has admin privileges.
  bool get isAdmin => role == UserRole.admin;
}
