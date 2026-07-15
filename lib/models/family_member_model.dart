class FamilyMemberModel {
  final String id;
  final String familyId;
  final String userId;
  final String role;
  final DateTime joinedAt;

  const FamilyMemberModel({
    required this.id,
    required this.familyId,
    required this.userId,
    required this.role,
    required this.joinedAt,
  });

  FamilyMemberModel copyWith({
    String? id,
    String? familyId,
    String? userId,
    String? role,
    DateTime? joinedAt,
  }) {
    return FamilyMemberModel(
      id: id ?? this.id,
      familyId: familyId ?? this.familyId,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }

  factory FamilyMemberModel.fromJson(Map<String, dynamic> json) {
    return FamilyMemberModel(
      id: json['id'] as String,
      familyId: json['family_id'] as String,
      userId: json['user_id'] as String,
      role: json['role'] as String,
      joinedAt: DateTime.parse(json['joined_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'family_id': familyId,
      'user_id': userId,
      'role': role,
      'joined_at': joinedAt.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FamilyMemberModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          familyId == other.familyId &&
          userId == other.userId &&
          role == other.role &&
          joinedAt == other.joinedAt;

  @override
  int get hashCode =>
      Object.hash(id, familyId, userId, role, joinedAt);

  @override
  String toString() =>
      'FamilyMemberModel(id: $id, familyId: $familyId, userId: $userId, role: $role, joinedAt: $joinedAt)';
}
