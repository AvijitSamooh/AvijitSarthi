enum UserRole { user, admin, cityAdmin, superAdmin }

class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    this.photoUrl,
    this.preferredLanguage,
    this.cityIds = const [],
  });

  final String id;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final UserRole role;
  final String? preferredLanguage;
  final List<String> cityIds;

  bool get isAdmin => role == UserRole.admin || role == UserRole.cityAdmin || role == UserRole.superAdmin;
  bool get isCityAdmin => role == UserRole.cityAdmin;
  bool get isSuperAdmin => role == UserRole.superAdmin;
}
