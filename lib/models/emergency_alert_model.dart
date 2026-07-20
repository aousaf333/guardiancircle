class EmergencyAlertModel {
  final String id;
  final String familyId;
  final String senderId;
  final double latitude;
  final double longitude;
  final String status;
  final DateTime createdAt;
  final DateTime? cancelledAt;

  const EmergencyAlertModel({
    required this.id,
    required this.familyId,
    required this.senderId,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.createdAt,
    this.cancelledAt,
  });

  bool get isActive => status == 'active';
  bool get isCancelled => status == 'cancelled';

  Duration get elapsed => DateTime.now().difference(createdAt);

  factory EmergencyAlertModel.fromJson(Map<String, dynamic> json) {
    return EmergencyAlertModel(
      id: json['id'] as String,
      familyId: json['family_id'] as String,
      senderId: json['sender_id'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      cancelledAt: json['cancelled_at'] != null
          ? DateTime.parse(json['cancelled_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'family_id': familyId,
      'sender_id': senderId,
      'latitude': latitude,
      'longitude': longitude,
      'status': status,
      'created_at': createdAt.toUtc().toIso8601String(),
      'cancelled_at': cancelledAt?.toUtc().toIso8601String(),
    };
  }
}
