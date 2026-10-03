class StaffUser {
  final String id;
  final String fullName;
  final String? email;
  final String role;
  final List<String> customPermissions;
  final bool isActive;
  final DateTime? createdAt;

  StaffUser({
    required this.id,
    required this.fullName,
    this.email,
    required this.role,
    this.customPermissions = const [],
    required this.isActive,
    this.createdAt,
  });

  factory StaffUser.fromJson(Map<String, dynamic> json) {
    return StaffUser(
      id: json['id']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? 'Personel',
      email: json['email']?.toString(),
      role: json['role']?.toString() ?? 'WAITER',
      customPermissions: (json['customPermissions'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      isActive: json['isActive'] as bool? ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'email': email,
      'role': role,
      'customPermissions': customPermissions,
      'isActive': isActive,
    };
  }
}
