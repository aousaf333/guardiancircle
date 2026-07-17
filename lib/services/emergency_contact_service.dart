import 'package:guardiancircle/models/emergency_contact_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EmergencyContactService {
  final SupabaseClient _client;

  EmergencyContactService(this._client);

  factory EmergencyContactService.defaultClient() =>
      EmergencyContactService(Supabase.instance.client);

  String get _userId => _supabase.auth.currentUser?.id ?? '';

  SupabaseClient get _supabase => _client;

  Future<List<EmergencyContactModel>> fetchContacts() async {
    final userId = _userId;
    if (userId.isEmpty) return [];

    final rows = await _supabase
        .from('emergency_contacts')
        .select('id, user_id, name, phone, relationship, created_at')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (rows as List)
        .map((r) => EmergencyContactModel.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<EmergencyContactModel> addContact({
    required String name,
    required String phone,
    required String relationship,
  }) async {
    final userId = _userId;
    if (userId.isEmpty) {
      throw const EmergencyContactException('User not authenticated.');
    }

    if (name.trim().isEmpty) {
      throw const EmergencyContactException('Name is required.');
    }

    if (phone.trim().isEmpty) {
      throw const EmergencyContactException('Phone number is required.');
    }

    final data = await _supabase
        .from('emergency_contacts')
        .insert({
          'user_id': userId,
          'name': name.trim(),
          'phone': phone.trim(),
          'relationship': relationship.trim(),
        })
        .select('id, user_id, name, phone, relationship, created_at')
        .single();

    return EmergencyContactModel.fromJson(data);
  }

  Future<EmergencyContactModel> updateContact({
    required String contactId,
    required String name,
    required String phone,
    required String relationship,
  }) async {
    final userId = _userId;
    if (userId.isEmpty) {
      throw const EmergencyContactException('User not authenticated.');
    }

    if (name.trim().isEmpty) {
      throw const EmergencyContactException('Name is required.');
    }

    if (phone.trim().isEmpty) {
      throw const EmergencyContactException('Phone number is required.');
    }

    final data = await _supabase
        .from('emergency_contacts')
        .update({
          'name': name.trim(),
          'phone': phone.trim(),
          'relationship': relationship.trim(),
        })
        .eq('id', contactId)
        .eq('user_id', userId)
        .select('id, user_id, name, phone, relationship, created_at')
        .single();

    return EmergencyContactModel.fromJson(data);
  }

  Future<void> deleteContact(String contactId) async {
    final userId = _userId;
    if (userId.isEmpty) {
      throw const EmergencyContactException('User not authenticated.');
    }

    await _supabase
        .from('emergency_contacts')
        .delete()
        .eq('id', contactId)
        .eq('user_id', userId);
  }
}

class EmergencyContactException implements Exception {
  final String message;
  const EmergencyContactException(this.message);

  @override
  String toString() => message;
}
