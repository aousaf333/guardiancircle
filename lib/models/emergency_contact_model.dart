class EmergencyContactModel {
  final String id;
  final String userId;
  final String name;
  final String phone;
  final String relationship;
  final DateTime? createdAt;

  const EmergencyContactModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.phone,
    required this.relationship,
    this.createdAt,
  });

  factory EmergencyContactModel.fromJson(Map<String, dynamic> json) {
    return EmergencyContactModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String? ?? '',
      relationship: json['relationship'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phone,
        'relationship': relationship,
      };

  String get initial => name.isNotEmpty ? name[0].toUpperCase() : '?';
}
