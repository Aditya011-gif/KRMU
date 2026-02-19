/// User data model.
class UserModel {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? state;
  final String? district;
  final double? farmSize;
  final String role;
  final DateTime? createdAt;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.state,
    this.district,
    this.farmSize,
    this.role = 'farmer',
    this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'],
      state: json['state'],
      district: json['district'],
      farmSize: json['farm_size']?.toDouble(),
      role: json['role'] ?? 'farmer',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'phone': phone,
    'state': state,
    'district': district,
    'farm_size': farmSize,
    'role': role,
  };

  bool get isAdmin => role == 'admin';
  bool get isFarmer => role == 'farmer';
}
