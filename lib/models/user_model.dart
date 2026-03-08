/// Represents a resident user of the apartment building.
class UserModel {
  final String id;
  final String name;

  /// Apartment identifier, e.g. "Depto 3A".
  final String apartment;

  const UserModel({
    required this.id,
    required this.name,
    required this.apartment,
  });
}
