import 'dart:math';
import 'dart:typed_data';
import 'package:guardiancircle/models/family_model.dart';
import 'package:guardiancircle/models/profile_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FamilyService {
  final SupabaseClient _client;

  FamilyService(this._client);

  factory FamilyService.defaultClient() =>
      FamilyService(Supabase.instance.client);

  SupabaseClient get _supabase => _client;

  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    return List.generate(8, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  Future<String> generateAndSaveInviteCode(String familyId) async {
    final code = _generateInviteCode();
    await _supabase
        .from('families')
        .update({'invite_code': code})
        .eq('id', familyId);
    return code;
  }

  // ---------------------------------------------------------------------------
  // Create Family
  // ---------------------------------------------------------------------------

  Future<FamilyModel> createFamily(String name) async {
    final userId = _supabase.auth.currentUser!.id;

    final data = await _supabase
        .from('families')
        .insert({
          'name': name,
          'created_by': userId,
          'invite_code': _generateInviteCode(),
        })
        .select()
        .single();

    // Insert creator as owner – only ONE row, no duplicates.
    await _supabase.from('family_members').insert({
      'family_id': data['id'] as String,
      'user_id': userId,
      'role': 'owner',
    });

    print('[FamilyService] createFamily: id=${data['id']}, '
        'created_by=$userId, role=owner');

    return FamilyModel.fromJson(data);
  }

  // ---------------------------------------------------------------------------
  // Join Family
  // ---------------------------------------------------------------------------

  Future<FamilyModel> joinFamily(String inviteCode) async {
    final userId = _supabase.auth.currentUser!.id;
    final trimmed = inviteCode.trim();

    print('[FamilyService] joinFamily: invite_code="$trimmed"');

    final row = await _supabase
        .from('families')
        .select()
        .eq('invite_code', trimmed)
        .maybeSingle();

    if (row == null) {
      throw const FamilyServiceException(
        'No family found with that invite code.',
      );
    }

    final family = FamilyModel.fromJson(row);

    // Duplicate protection: check if already a member.
    final existing = await _supabase
        .from('family_members')
        .select('id')
        .eq('family_id', family.id)
        .eq('user_id', userId)
        .maybeSingle();

    if (existing != null) {
      throw const FamilyServiceException(
        'Already joined this family.',
      );
    }

    await _supabase.from('family_members').insert({
      'family_id': family.id,
      'user_id': userId,
      'role': 'member',
    });

    print('[FamilyService] joinFamily: family_id=${family.id}, '
        'user_id=$userId, role=member');

    return family;
  }

  // ---------------------------------------------------------------------------
  // Fetch Families
  // ---------------------------------------------------------------------------

  Future<List<FamilyModel>> fetchFamilies() async {
    final userId = _supabase.auth.currentUser!.id;

    final owned = await _supabase
        .from('families')
        .select()
        .eq('created_by', userId)
        .order('created_at', ascending: false);

    final joinedRows = await _supabase
        .from('family_members')
        .select('family_id')
        .eq('user_id', userId);

    final joinedIds =
        (joinedRows as List).map((r) => r['family_id'] as String).toSet();

    final joinedFamilies = joinedIds.isEmpty
        ? <Map<String, dynamic>>[]
        : await _supabase
            .from('families')
            .select()
            .inFilter('id', joinedIds.toList())
            .order('created_at', ascending: false);

    // Merge owned + joined, deduplicate by id.
    final all = <String, FamilyModel>{};
    for (final row in [...owned as List, ...joinedFamilies]) {
      final model = FamilyModel.fromJson(row);
      all[model.id] = model;
    }

    print('[FamilyService] fetchFamilies: ${all.length} families');
    return all.values.toList();
  }

  // ---------------------------------------------------------------------------
  // Fetch Family Members
  //
  // 1. Load ALL rows where family_members.family_id == passed familyId.
  //    Never filter by user_id. Never use .single / .maybeSingle / .first / .limit(1).
  // 2. Fetch ALL matching profiles where profiles.id IN (all user_ids).
  // 3. Merge in Dart: attach profile to each family_member row.
  // 4. Build member list from every merged record.
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> fetchFamilyMembers(
    String familyId,
  ) async {
    // Load ALL rows where family_id == familyId.
    final memberRows = await _supabase
        .from('family_members')
        .select('id, family_id, user_id, role, joined_at')
        .eq('family_id', familyId)
        .order('joined_at', ascending: true);

    final members = List<Map<String, dynamic>>.from(memberRows);
    print('[FamilyService] Family member rows loaded: ${members.length}');

    if (members.isEmpty) return [];

    // Extract all user_ids and fetch all matching profiles.
    final userIds = members.map((r) => r['user_id'] as String).toList();
    print('[FamilyService] User IDs loaded: $userIds');

    final profileRows = await _supabase
        .from('profiles')
        .select('id, name, email, photo_url')
        .inFilter('id', userIds);

    print('[FamilyService] Profiles loaded: ${(profileRows as List).length}');

    final profileMap = <String, Map<String, dynamic>>{};
    for (final row in (profileRows as List)) {
      profileMap[row['id'] as String] = row;
    }

    // Merge in Dart: attach profile to each family_member row.
    final result = members.map((m) {
      return {...m, 'profile': profileMap[m['user_id']]};
    }).toList();

    print('[FamilyService] Members displayed: ${result.length}');
    return result;
  }

  // ---------------------------------------------------------------------------
  // Parse profile from merged row
  // ---------------------------------------------------------------------------

  ProfileModel? parseProfile(Map<String, dynamic> row) {
    final profile = row['profile'];
    if (profile == null || profile is! Map<String, dynamic>) return null;
    return ProfileModel.fromJson(profile);
  }

  // ---------------------------------------------------------------------------
  // Repair existing bad data (runs once on screen open)
  //
  // For every family:
  //   - Delete duplicate rows per user_id (keep earliest).
  //   - Set role = "owner" where user_id = families.created_by.
  //   - Insert creator row if missing.
  // ---------------------------------------------------------------------------

  Future<void> repairFamilyMemberships() async {
    print('[FamilyService] repairFamilyMemberships: start');

    final familyRows = await _supabase
        .from('families')
        .select('id, created_by');

    for (final family in (familyRows as List)) {
      final familyId = family['id'] as String;
      final createdBy = family['created_by'] as String;

      final memberRows = await _supabase
          .from('family_members')
          .select('id, user_id, role, joined_at')
          .eq('family_id', familyId)
          .order('joined_at', ascending: true);

      final members = List<Map<String, dynamic>>.from(memberRows);

      // --- Deduplicate: keep earliest row per user_id, delete rest ---
      final seen = <String>{};
      final idsToDelete = <String>[];
      for (final m in members) {
        final uid = m['user_id'] as String;
        if (seen.contains(uid)) {
          idsToDelete.add(m['id'] as String);
        } else {
          seen.add(uid);
        }
      }

      if (idsToDelete.isNotEmpty) {
        print('[FamilyService]   repair: deleting ${idsToDelete.length} '
            'duplicate(s) in family $familyId');
        for (var i = 0; i < idsToDelete.length; i += 50) {
          final end = (i + 50 > idsToDelete.length)
              ? idsToDelete.length
              : i + 50;
          await _supabase
              .from('family_members')
              .delete()
              .inFilter('id', idsToDelete.sublist(i, end));
        }
      }

      // --- Set creator role to "owner" ---
      await _supabase
          .from('family_members')
          .update({'role': 'owner'})
          .eq('family_id', familyId)
          .eq('user_id', createdBy);

      // --- Insert creator row if missing ---
      final creatorRows = await _supabase
          .from('family_members')
          .select('id')
          .eq('family_id', familyId)
          .eq('user_id', createdBy);

      if ((creatorRows as List).isEmpty) {
        print('[FamilyService]   repair: inserting missing owner '
            'user_id=$createdBy in family $familyId');
        await _supabase.from('family_members').insert({
          'family_id': familyId,
          'user_id': createdBy,
          'role': 'owner',
        });
      }
    }

    print('[FamilyService] repairFamilyMemberships: done');
  }

  // ---------------------------------------------------------------------------
  // Profile
  // ---------------------------------------------------------------------------

  Future<ProfileModel?> fetchProfile(String userId) async {
    final rows = await _supabase
        .from('profiles')
        .select('id, name, email, phone, photo_url, created_at')
        .eq('id', userId);

    final list = rows as List;
    if (list.isEmpty) return null;
    return ProfileModel.fromJson(list.first as Map<String, dynamic>);
  }

  Future<void> updateProfile({
    required String userId,
    required String name,
    String? phone,
    String? photoUrl,
  }) async {
    final updates = <String, dynamic>{
      'name': name,
      'phone': phone,
      'photo_url': photoUrl,
    };

    await _supabase
        .from('profiles')
        .update(updates)
        .eq('id', userId);
  }

  Future<String> uploadAvatar({
    required String userId,
    required Uint8List bytes,
  }) async {
    await _supabase.storage.from('profile-images').uploadBinary(
          '$userId/avatar.jpg',
          bytes,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'image/jpeg',
          ),
        );
    final url = _supabase.storage.from('profile-images').getPublicUrl('$userId/avatar.jpg');
    return url;
  }
}

class FamilyServiceException implements Exception {
  final String message;
  const FamilyServiceException(this.message);

  @override
  String toString() => message;
}
