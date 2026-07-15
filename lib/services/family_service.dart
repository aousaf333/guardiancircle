import 'dart:math';
import 'package:guardiancircle/models/family_model.dart';
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

    final all = <String, FamilyModel>{};
    for (final row in [...owned as List, ...joinedFamilies]) {
      final model = FamilyModel.fromJson(row);
      all[model.id] = model;
    }

    return all.values.toList();
  }

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

    return FamilyModel.fromJson(data);
  }

  Future<FamilyModel> joinFamily(String inviteCode) async {
    final userId = _supabase.auth.currentUser!.id;

    final rows = await _supabase
        .from('families')
        .select()
        .eq('invite_code', inviteCode.trim().toUpperCase());

    if (rows.isEmpty) {
      throw const FamilyServiceException('No family found with that invite code.');
    }

    final family = FamilyModel.fromJson(rows.first);

    final existing = await _supabase
        .from('family_members')
        .select('id')
        .eq('family_id', family.id)
        .eq('user_id', userId);

    if ((existing as List).isNotEmpty) {
      throw const FamilyServiceException('You are already a member of this family.');
    }

    await _supabase.from('family_members').insert({
      'family_id': family.id,
      'user_id': userId,
      'role': 'member',
    });

    return family;
  }
}

class FamilyServiceException implements Exception {
  final String message;
  const FamilyServiceException(this.message);

  @override
  String toString() => message;
}
