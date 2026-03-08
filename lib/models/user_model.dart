/// User roles in the application.
enum UserRole { user, admin }

/// Represents a resident user of the apartment building.
class UserModel {
  final String id;
  final String name;

  /// Apartment identifier, e.g. "Depto 3A".
  final String apartment;

  final UserRole role;

  const UserModel({
    required this.id,
    required this.name,
    required this.apartment,
    this.role = UserRole.user,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: json["id"] as String,
    name: json["name"] as String,
    apartment: json["apartment"] as String,
    role: json["role"] == "admin" ? UserRole.admin : UserRole.user,
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "name": name,
    "apartment": apartment,
    "role": role == UserRole.admin ? "admin" : "user",
  };

  /// Returns true if this user has admin privileges.
  bool get isAdmin => role == UserRole.admin;
}
