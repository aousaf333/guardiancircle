import 'dart:async';

import 'package:guardiancircle/models/emergency_contact_model.dart';
import 'package:guardiancircle/services/connectivity_service.dart';
import 'package:guardiancircle/services/local_storage_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class EmergencyContactService {
  static const int maxContacts = 5;

  static const String _cacheBoxName = 'cached_emergency_contacts';
  static const String _queueBoxName = 'emergency_contact_queue';

  final SupabaseClient _client;

  EmergencyContactService(this._client);

  factory EmergencyContactService.defaultClient() =>
      EmergencyContactService(Supabase.instance.client);

  String get _userId => _supabase.auth.currentUser?.id ?? '';

  SupabaseClient get _supabase => _client;

  // ---------------------------------------------------------------------------
  // Phone validation helpers
  // ---------------------------------------------------------------------------

  static String normalizePhone(String phone) =>
      phone.replaceAll(RegExp(r'[^\d]'), '');

  static bool isValidPhoneNumber(String phone) {
    final digits = normalizePhone(phone);
    return digits.length >= 7 && digits.length <= 15;
  }

  // ---------------------------------------------------------------------------
  // Connectivity + offline auto-sync
  // ---------------------------------------------------------------------------

  static final ConnectivityService _sharedConnectivity = ConnectivityService();
  static bool _connectivityInitialized = false;

  static StreamSubscription<bool>? _offlineSyncSubscription;
  static bool _offlineSyncWasOnline = false;
  static bool _offlineSyncRunning = false;

  /// Starts listening for connectivity changes and automatically syncs any
  /// queued emergency contact changes once internet is restored.
  ///
  /// Safe to call more than once; subsequent calls are no-ops.
  static Future<void> startOfflineSync() async {
    if (_offlineSyncSubscription != null) return;

    if (!_connectivityInitialized) {
      await _sharedConnectivity.initialize();
      _connectivityInitialized = true;
    }

    _offlineSyncWasOnline = _sharedConnectivity.isCurrentlyOnline;
    _offlineSyncSubscription =
        _sharedConnectivity.isOnline.listen(_onConnectivityChanged);
    print('[EmergencyContacts] Listening for connectivity changes');
  }

  static void _onConnectivityChanged(bool online) {
    if (online && !_offlineSyncWasOnline) {
      syncPendingChanges();
    }
    _offlineSyncWasOnline = online;
  }

  static Future<void> syncPendingChanges() async {
    if (_offlineSyncRunning) return;
    _offlineSyncRunning = true;

    try {
      final box = LocalStorageService.instance.box(_queueBoxName);
      if (box == null) return;

      final entries = <dynamic, Map<dynamic, dynamic>>{};
      box.toMap().forEach((key, value) {
        if (value is Map) entries[key] = value;
      });

      if (entries.isEmpty) return;

      print('[EmergencyContacts] Found ${entries.length} queued changes');

      final service = EmergencyContactService.defaultClient();

      for (final entry in entries.entries) {
        final type = entry.value['type'] as String? ?? '';
        print('[EmergencyContacts] Syncing change: $type');
        try {
          if (type == 'emergency_contact_add') {
            await service._addContactOnline(
              name: entry.value['name'] as String? ?? '',
              phone: entry.value['phone'] as String? ?? '',
              relationship: entry.value['relationship'] as String? ?? '',
            );
          } else if (type == 'emergency_contact_update') {
            await service._updateContactOnline(
              contactId: entry.value['id'] as String? ?? '',
              name: entry.value['name'] as String? ?? '',
              phone: entry.value['phone'] as String? ?? '',
              relationship: entry.value['relationship'] as String? ?? '',
            );
          } else if (type == 'emergency_contact_delete') {
            await service._deleteContactOnline(
              entry.value['id'] as String? ?? '',
            );
          }
          await box.delete(entry.key);
          print('[EmergencyContacts] Sync successful');
        } catch (e) {
          print('[EmergencyContacts] Sync failed, keeping change queued: $e');
        }
      }

      await service._refreshCache();
      print('[EmergencyContacts] Contacts synced');
    } finally {
      _offlineSyncRunning = false;
    }
  }

  Future<bool> _isOnline() async {
    if (!_connectivityInitialized) {
      await _sharedConnectivity.initialize();
      _connectivityInitialized = true;
    }
    return _sharedConnectivity.isCurrentlyOnline;
  }

  // ---------------------------------------------------------------------------
  // Local cache
  // ---------------------------------------------------------------------------

  Box<dynamic>? get _cacheBox =>
      LocalStorageService.instance.box(_cacheBoxName);

  Box<dynamic>? get _queueBox => LocalStorageService.instance.box(_queueBoxName);

  Future<void> _saveCache(List<EmergencyContactModel> contacts) async {
    final box = _cacheBox;
    if (box == null) return;
    await box.clear();
    for (final contact in contacts) {
      await box.put(contact.id, contact.toCacheJson());
    }
  }

  List<EmergencyContactModel> _loadCache() {
    final box = _cacheBox;
    if (box == null) return [];
    return box.values
        .whereType<Map>()
        .map(
          (e) =>
              EmergencyContactModel.fromJson(Map<String, dynamic>.from(e)),
        )
        .toList();
  }

  Future<void> _upsertCache(EmergencyContactModel contact) async {
    final box = _cacheBox;
    if (box == null) return;
    await box.put(contact.id, contact.toCacheJson());
  }

  Future<void> _removeFromCache(String contactId) async {
    final box = _cacheBox;
    if (box == null) return;
    await box.delete(contactId);
  }

  Future<void> _refreshCache() async {
    final userId = _userId;
    if (userId.isEmpty) return;
    try {
      final rows = await _supabase
          .from('emergency_contacts')
          .select('id, user_id, name, phone, relationship, created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final contacts = (rows as List)
          .map(
            (r) =>
                EmergencyContactModel.fromJson(r as Map<String, dynamic>),
          )
          .toList();
      await _saveCache(contacts);
    } catch (e) {
      print('[EmergencyContacts] Cache refresh failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Fetch contacts
  // ---------------------------------------------------------------------------

  Future<List<EmergencyContactModel>> fetchContacts() async {
    final userId = _userId;
    if (userId.isEmpty) return _loadCache();

    if (!await _isOnline()) {
      print('[EmergencyContacts] Offline, loading from cache');
      print('[EmergencyContacts] Loaded from cache');
      return _loadCache();
    }

    try {
      final rows = await _supabase
          .from('emergency_contacts')
          .select('id, user_id, name, phone, relationship, created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final contacts = (rows as List)
          .map(
            (r) =>
                EmergencyContactModel.fromJson(r as Map<String, dynamic>),
          )
          .toList();
      await _saveCache(contacts);
      print('[EmergencyContacts] Contacts synced');
      return contacts;
    } catch (e) {
      print('[EmergencyContacts] Fetch failed, using cache');
      print('[EmergencyContacts] Loaded from cache');
      return _loadCache();
    }
  }

  // ---------------------------------------------------------------------------
  // Validation
  // ---------------------------------------------------------------------------

  void _validateContact({required String name, required String phone}) {
    if (name.trim().isEmpty) {
      throw const EmergencyContactException('Name is required.');
    }
    if (phone.trim().isEmpty) {
      throw const EmergencyContactException('Phone number is required.');
    }
    if (!isValidPhoneNumber(phone)) {
      throw const EmergencyContactException(
        'Please enter a valid phone number.',
      );
    }
  }

  void _validateNoDuplicate(
    String phone,
    List<EmergencyContactModel> contacts, {
    String? exceptId,
  }) {
    final normalized = normalizePhone(phone);
    for (final contact in contacts) {
      if (contact.id == exceptId) continue;
      if (normalizePhone(contact.phone) == normalized) {
        throw const EmergencyContactException(
          'This phone number is already in use.',
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Add contact
  // ---------------------------------------------------------------------------

  Future<EmergencyContactModel> addContact({
    required String name,
    required String phone,
    required String relationship,
  }) async {
    final userId = _userId;
    if (userId.isEmpty) {
      throw const EmergencyContactException('User not authenticated.');
    }

    _validateContact(name: name, phone: phone);

    final current = await fetchContacts();
    if (current.length >= maxContacts) {
      throw const EmergencyContactException(
        'Maximum of $maxContacts emergency contacts allowed.',
      );
    }
    _validateNoDuplicate(phone, current);

    final cleanName = name.trim();
    final cleanPhone = phone.trim();
    final cleanRelation = relationship.trim();

    if (!await _isOnline()) {
      print('[EmergencyContacts] Offline, queuing add');
      final contact = EmergencyContactModel(
        id: const Uuid().v4(),
        userId: userId,
        name: cleanName,
        phone: cleanPhone,
        relationship: cleanRelation,
        createdAt: DateTime.now(),
      );
      await _upsertCache(contact);
      await _enqueueChange({
        'type': 'emergency_contact_add',
        'name': cleanName,
        'phone': cleanPhone,
        'relationship': cleanRelation,
      });
      print('[EmergencyContacts] Contact added');
      return contact;
    }

    try {
      final data = await _supabase
          .from('emergency_contacts')
          .insert({
            'user_id': userId,
            'name': cleanName,
            'phone': cleanPhone,
            'relationship': cleanRelation,
          })
          .select('id, user_id, name, phone, relationship, created_at')
          .single();

      final contact = EmergencyContactModel.fromJson(data);
      await _upsertCache(contact);
      print('[EmergencyContacts] Contact added');
      return contact;
    } catch (e) {
      print('[EmergencyContacts] Add failed, queuing offline: $e');
      final contact = EmergencyContactModel(
        id: const Uuid().v4(),
        userId: userId,
        name: cleanName,
        phone: cleanPhone,
        relationship: cleanRelation,
        createdAt: DateTime.now(),
      );
      await _upsertCache(contact);
      await _enqueueChange({
        'type': 'emergency_contact_add',
        'name': cleanName,
        'phone': cleanPhone,
        'relationship': cleanRelation,
      });
      print('[EmergencyContacts] Contact added');
      return contact;
    }
  }

  // ---------------------------------------------------------------------------
  // Update contact
  // ---------------------------------------------------------------------------

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

    _validateContact(name: name, phone: phone);

    final current = await fetchContacts();
    _validateNoDuplicate(phone, current, exceptId: contactId);

    final existing = current.where((c) => c.id == contactId).firstOrNull;

    final cleanName = name.trim();
    final cleanPhone = phone.trim();
    final cleanRelation = relationship.trim();

    if (!await _isOnline()) {
      print('[EmergencyContacts] Offline, queuing update');
      final updated = EmergencyContactModel(
        id: contactId,
        userId: existing?.userId ?? userId,
        name: cleanName,
        phone: cleanPhone,
        relationship: cleanRelation,
        createdAt: existing?.createdAt,
      );
      await _upsertCache(updated);
      await _enqueueChange({
        'type': 'emergency_contact_update',
        'id': contactId,
        'name': cleanName,
        'phone': cleanPhone,
        'relationship': cleanRelation,
      });
      print('[EmergencyContacts] Contact updated');
      return updated;
    }

    try {
      final data = await _supabase
          .from('emergency_contacts')
          .update({
            'name': cleanName,
            'phone': cleanPhone,
            'relationship': cleanRelation,
          })
          .eq('id', contactId)
          .eq('user_id', userId)
          .select('id, user_id, name, phone, relationship, created_at')
          .single();

      final contact = EmergencyContactModel.fromJson(data);
      await _upsertCache(contact);
      print('[EmergencyContacts] Contact updated');
      return contact;
    } catch (e) {
      print('[EmergencyContacts] Update failed, queuing offline: $e');
      final updated = EmergencyContactModel(
        id: contactId,
        userId: existing?.userId ?? userId,
        name: cleanName,
        phone: cleanPhone,
        relationship: cleanRelation,
        createdAt: existing?.createdAt,
      );
      await _upsertCache(updated);
      await _enqueueChange({
        'type': 'emergency_contact_update',
        'id': contactId,
        'name': cleanName,
        'phone': cleanPhone,
        'relationship': cleanRelation,
      });
      print('[EmergencyContacts] Contact updated');
      return updated;
    }
  }

  // ---------------------------------------------------------------------------
  // Delete contact
  // ---------------------------------------------------------------------------

  Future<void> deleteContact(String contactId) async {
    final userId = _userId;
    if (userId.isEmpty) {
      throw const EmergencyContactException('User not authenticated.');
    }

    if (!await _isOnline()) {
      print('[EmergencyContacts] Offline, queuing delete');
      await _removeFromCache(contactId);
      await _enqueueChange({
        'type': 'emergency_contact_delete',
        'id': contactId,
      });
      print('[EmergencyContacts] Contact deleted');
      return;
    }

    try {
      await _supabase
          .from('emergency_contacts')
          .delete()
          .eq('id', contactId)
          .eq('user_id', userId);
      await _removeFromCache(contactId);
      print('[EmergencyContacts] Contact deleted');
    } catch (e) {
      print('[EmergencyContacts] Delete failed, queuing offline: $e');
      await _removeFromCache(contactId);
      await _enqueueChange({
        'type': 'emergency_contact_delete',
        'id': contactId,
      });
      print('[EmergencyContacts] Contact deleted');
    }
  }

  // ---------------------------------------------------------------------------
  // Direct online operations (used by offline sync replay)
  // ---------------------------------------------------------------------------

  Future<void> _addContactOnline({
    required String name,
    required String phone,
    required String relationship,
  }) async {
    final userId = _userId;
    if (userId.isEmpty) return;
    try {
      await _supabase.from('emergency_contacts').insert({
        'user_id': userId,
        'name': name,
        'phone': phone,
        'relationship': relationship,
      });
    } catch (e) {
      print('[EmergencyContacts] Online add failed: $e');
      rethrow;
    }
  }

  Future<void> _updateContactOnline({
    required String contactId,
    required String name,
    required String phone,
    required String relationship,
  }) async {
    final userId = _userId;
    if (userId.isEmpty) return;
    try {
      await _supabase
          .from('emergency_contacts')
          .update({
            'name': name,
            'phone': phone,
            'relationship': relationship,
          })
          .eq('id', contactId)
          .eq('user_id', userId);
    } catch (e) {
      print('[EmergencyContacts] Online update failed: $e');
      rethrow;
    }
  }

  Future<void> _deleteContactOnline(String contactId) async {
    final userId = _userId;
    if (userId.isEmpty) return;
    try {
      await _supabase
          .from('emergency_contacts')
          .delete()
          .eq('id', contactId)
          .eq('user_id', userId);
    } catch (e) {
      print('[EmergencyContacts] Online delete failed: $e');
      rethrow;
    }
  }

  Future<void> _enqueueChange(Map<String, dynamic> change) async {
    final box = _queueBox;
    if (box == null) return;
    try {
      await box.add({
        ...change,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      });
      print('[EmergencyContacts] Queued change: ${change['type']}');
    } catch (e) {
      print('[EmergencyContacts] Failed to queue change: $e');
    }
  }
}

class EmergencyContactException implements Exception {
  final String message;
  const EmergencyContactException(this.message);

  @override
  String toString() => message;
}
