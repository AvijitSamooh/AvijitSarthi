class AdminUser {
  const AdminUser({
    required this.id,
    this.email,
    this.displayName,
    this.photoUrl,
    required this.role,
    required this.createdAt,
    this.cityIds = const [],
  });

  final String id;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final String role;
  final DateTime createdAt;
  final List<String> cityIds;

  bool get isAdmin => role == 'ADMIN';
  bool get isCityAdmin => role == 'CITY_ADMIN';
  bool get isSuperAdmin => role == 'SUPER_ADMIN';
  bool get canBeDemoted => isAdmin || isCityAdmin;
  bool get canBePromoted => role == 'USER';

  String get label =>
      displayName?.trim().isNotEmpty == true ? displayName! : (email ?? 'User');

  factory AdminUser.fromJson(Map<String, dynamic> json) => AdminUser(
        id: json['id'] as String,
        email: json['email'] as String?,
        displayName: json['displayName'] as String?,
        photoUrl: json['photoUrl'] as String?,
        role: json['role'] as String? ?? 'USER',
        createdAt: DateTime.parse(json['createdAt'] as String),
        cityIds: (json['cityIds'] as List<dynamic>? ?? const []).cast<String>(),
      );
}
