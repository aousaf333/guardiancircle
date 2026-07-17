import 'package:flutter/material.dart';

class FamilyMemberLocation {
  final String userId;
  final String name;
  final String role;
  final String? photoUrl;
  final Color color;
  final double latitude;
  final double longitude;
  final DateTime lastUpdated;
  final double? battery;

  const FamilyMemberLocation({
    required this.userId,
    required this.name,
    required this.role,
    this.photoUrl,
    required this.color,
    required this.latitude,
    required this.longitude,
    required this.lastUpdated,
    this.battery,
  });

  FamilyMemberLocation copyWith({
    String? userId,
    String? name,
    String? role,
    String? photoUrl,
    Color? color,
    double? latitude,
    double? longitude,
    DateTime? lastUpdated,
    double? battery,
  }) {
    return FamilyMemberLocation(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      role: role ?? this.role,
      photoUrl: photoUrl ?? this.photoUrl,
      color: color ?? this.color,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      battery: battery ?? this.battery,
    );
  }
}
