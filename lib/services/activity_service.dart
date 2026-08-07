import 'package:guardiancircle/services/family_service.dart';
import 'package:guardiancircle/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Types of real family activity that can be shown in the activity/history
/// screens. Each value maps to a real event stored in Supabase; nothing here
/// is fabricated.
enum FamilyActivityType { sosCreated, sosCancelled, memberJoined }

/// A single activity event derived from real data in Supabase.
///
/// Events are never inserted: they are read from existing application records
/// such as `emergency_alerts` (SOS created/cancelled) and `family_members`
/// (member joined).
class FamilyActivityEvent {
  final FamilyActivityType type;
  final String memberId;
  final String memberName;
  final DateTime timestamp;
  final String detail;

  const FamilyActivityEvent({
    required this.type,
    required this.memberId,
    required this.memberName,
    required this.timestamp,
    required this.detail,
  });
}

/// Reads real family activity from Supabase for the Activity History feature.
///
/// This service never writes or seeds data. When Supabase is unreachable it
/// returns an empty list so the UI can show a truthful empty state instead of
/// any placeholder content.
class ActivityService {
  final SupabaseClient _client;

  ActivityService(this._client);

  factory ActivityService.defaultClient() => ActivityService(SupabaseService.client);

  /// Builds the family activity feed from real application events:
  ///
  /// - SOS created / SOS cancelled, from `emergency_alerts`
  /// - Member joined, from `family_members.joined_at`
  ///
  /// Events are returned newest-first.
  Future<List<FamilyActivityEvent>> fetchActivityEvents() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final events = <FamilyActivityEvent>[];
    final memberNameById = <String, String>{};
    final joinedById = <String, DateTime>{};

    try {
      final familyService = FamilyService(_client);
      final families = await familyService.fetchFamilies();
      if (families.isEmpty) return [];

      final familyIds = families.map((f) => f.id).toList();

      // --- Member joined events (real data from family_members.joined_at) ---
      try {
        for (final family in families) {
          final members = await familyService.fetchFamilyMembers(family.id);
          for (final member in members) {
            final memberId = member['user_id'] as String?;
            if (memberId == null) continue;

            final profile = member['profile'] as Map<String, dynamic>?;
            memberNameById.putIfAbsent(memberId, () => _displayName(profile));

            final joinedAt = DateTime.tryParse(member['joined_at'] as String? ?? '');
            if (joinedAt != null) {
              joinedById.putIfAbsent(memberId, () => joinedAt);
            }
          }
        }
      } catch (e) {
        print('[Activity] Failed to load family members: $e');
      }

      for (final entry in joinedById.entries) {
        events.add(FamilyActivityEvent(
          type: FamilyActivityType.memberJoined,
          memberId: entry.key,
          memberName: memberNameById[entry.key] ?? 'Family member',
          timestamp: entry.value,
          detail: 'Joined your family circle',
        ));
      }

      // --- SOS events (real data from emergency_alerts) ---
      try {
        final rows = await _client
            .from('emergency_alerts')
            .select('id, family_id, sender_id, status, created_at, cancelled_at')
            .inFilter('family_id', familyIds);

        final alerts = List<Map<String, dynamic>>.from(rows as List);

        // Resolve sender names for senders not already known from family members.
        final unknownSenderIds = alerts
            .map((r) => r['sender_id'] as String?)
            .where((id) => id != null && !memberNameById.containsKey(id))
            .toSet();
        if (unknownSenderIds.isNotEmpty) {
          try {
            final profileRows = await _client
                .from('profiles')
                .select('id, name, email')
                .inFilter('id', unknownSenderIds.toList());
            for (final row in (profileRows as List)) {
              memberNameById[row['id'] as String] = _displayName(row);
            }
          } catch (e) {
            print('[Activity] Failed to load alert sender profiles: $e');
          }
        }

        for (final row in alerts) {
          final senderId = row['sender_id'] as String?;
          if (senderId == null) continue;

          final createdAt = DateTime.tryParse(row['created_at'] as String? ?? '');
          final cancelledAt = DateTime.tryParse(row['cancelled_at'] as String? ?? '');
          final status = row['status'] as String?;
          final name = memberNameById[senderId] ?? 'Family member';

          if (createdAt != null) {
            events.add(FamilyActivityEvent(
              type: FamilyActivityType.sosCreated,
              memberId: senderId,
              memberName: name,
              timestamp: createdAt,
              detail: 'Sent an SOS alert to all family members',
            ));
          }

          if (status == 'cancelled' && cancelledAt != null) {
            events.add(FamilyActivityEvent(
              type: FamilyActivityType.sosCancelled,
              memberId: senderId,
              memberName: name,
              timestamp: cancelledAt,
              detail: 'Cancelled their SOS alert',
            ));
          }
        }
      } catch (e) {
        print('[Activity] Failed to load SOS alerts: $e');
      }

      events.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return events;
    } catch (e) {
      print('[Activity] Failed to load family activity: $e');
      return [];
    }
  }

  static String _displayName(Map<String, dynamic>? profile) {
    if (profile == null) return 'Family member';
    final name = profile['name'] as String?;
    if (name != null && name.trim().isNotEmpty) return name;
    final email = profile['email'] as String?;
    if (email != null && email.isNotEmpty) return email.split('@').first;
    return 'Family member';
  }
}

/// Formats [timestamp] as a compact relative time string, e.g. "just now",
/// "5m ago", "3h ago" or "2d ago". Older events fall back to a short date.
String formatActivityTime(DateTime timestamp) {
  final now = DateTime.now();
  final diff = now.difference(timestamp);

  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return formatActivityDate(timestamp);
}

/// Formats [timestamp] as a short date, e.g. "Aug 5" or "Aug 5, 2025".
String formatActivityDate(DateTime timestamp) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final local = timestamp.toLocal();
  final month = months[local.month - 1];
  if (local.year == DateTime.now().year) {
    return '$month ${local.day}';
  }
  return '$month ${local.day}, ${local.year}';
}

/// Labels [timestamp] for use as a date-group header: "Today", "Yesterday",
/// or a short date for anything older.
String formatActivityDayLabel(DateTime timestamp) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final local = timestamp.toLocal();
  final day = DateTime(local.year, local.month, local.day);

  if (day == today) return 'Today';
  if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
  return formatActivityDate(timestamp);
}

/// Whether [timestamp] falls on the same calendar day as [now].
bool isSameActivityDay(DateTime timestamp, DateTime now) {
  final a = DateTime(now.year, now.month, now.day);
  final local = timestamp.toLocal();
  final b = DateTime(local.year, local.month, local.day);
  return a == b;
}
