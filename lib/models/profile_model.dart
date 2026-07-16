class ProfileModel {
  final String id;
  final String? name;
  final String? email;
  final String? phone;
  final String? photoUrl;
  final DateTime? createdAt;

  const ProfileModel({
    required this.id,
    this.name,
    this.email,
    this.phone,
    this.photoUrl,
    this.createdAt,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String,
      name: json['name'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      photoUrl: json['photo_url'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  String get displayName => name ?? email ?? 'Unknown';
}
