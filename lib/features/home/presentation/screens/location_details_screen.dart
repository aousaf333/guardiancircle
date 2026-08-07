import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:guardiancircle/core/theme/app_theme.dart';
import 'package:guardiancircle/models/family_member_location.dart';
import 'package:guardiancircle/models/self_location_info.dart';
import 'package:guardiancircle/services/activity_service.dart';
import 'package:guardiancircle/services/family_location_cache_service.dart';
import 'package:guardiancircle/services/family_service.dart';
import 'package:guardiancircle/services/location_tracking_service.dart';
import 'package:guardiancircle/services/supabase_service.dart';
import 'package:guardiancircle/shared/widgets/glass_card.dart';
import 'package:guardiancircle/shared/widgets/slide_in_animation.dart';

class LocationDetailsScreen extends StatefulWidget {
  const LocationDetailsScreen({super.key});

  @override
  State<LocationDetailsScreen> createState() => _LocationDetailsScreenState();
}

class _LocationDetailsScreenState extends State<LocationDetailsScreen> {
  static const List<Color> _memberColors = [
    Color(0xFF3B82F6),
    Color(0xFFEC4899),
    Color(0xFF8B5CF6),
    Color(0xFFF59E0B),
    Color(0xFF06B6D4),
    Color(0xFFEF4444),
    Color(0xFF14B8A6),
    Color(0xFF10B981),
  ];

  SelfLocationInfo? _selfLocation;
  bool _locationLoading = true;
  List<FamilyMemberLocation> _nearbyMembers = [];
  bool _nearbyLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLocation();
    _loadNearbyFamily();
  }

  Future<void> _loadLocation() async {
    final info = await LocationTrackingService.instance.loadSelfLocationInfo();
    if (!mounted) return;
    setState(() {
      _selfLocation = info;
      _locationLoading = false;
    });
  }

  Future<void> _loadNearbyFamily() async {
    String? familyId;
    List<FamilyMemberLocation> members = [];
    try {
      final families = await FamilyService.defaultClient().fetchFamilies();
      if (families.isNotEmpty) {
        familyId = families.first.id;
        members = await _fetchMemberLocations(familyId);
        if (members.isNotEmpty) {
          FamilyLocationCacheService.instance
              .saveFamilyMemberLocations(familyId, members);
        }
      }
    } catch (_) {
      if (familyId != null) {
        members = FamilyLocationCacheService.instance
            .loadCachedFamilyMemberLocations(familyId);
      }
    }

    if (!mounted) return;
    setState(() {
      _nearbyMembers = members;
      _nearbyLoading = false;
    });
  }

  Future<List<FamilyMemberLocation>> _fetchMemberLocations(
    String familyId,
  ) async {
    final supabase = SupabaseService.client;
    final currentUserId = supabase.auth.currentUser?.id;

    final memberRows = await supabase
        .from('family_members')
        .select('user_id, role')
        .eq('family_id', familyId);
    final memberList = List<Map<String, dynamic>>.from(memberRows as List);
    if (memberList.isEmpty) return [];

    final userIds = memberList.map((r) => r['user_id'] as String).toList();

    final locationMap = <String, Map<String, dynamic>>{};
    try {
      final locationRows = await supabase
          .from('user_locations')
          .select('user_id, latitude, longitude, updated_at')
          .inFilter('user_id', userIds);
      final locList = List<Map<String, dynamic>>.from(locationRows as List);
      for (final row in locList) {
        locationMap[row['user_id'] as String] = row;
      }
    } catch (_) {}

    final profileMap = <String, Map<String, dynamic>>{};
    try {
      final profileRows = await supabase
          .from('profiles')
          .select('id, name, photo_url')
          .inFilter('id', userIds);
      final pList = List<Map<String, dynamic>>.from(profileRows as List);
      for (final row in pList) {
        profileMap[row['id'] as String] = row;
      }
    } catch (_) {}

    final privacyHidden = <String, bool>{};
    try {
      final privacyRows = await supabase
          .from('privacy_settings')
          .select('user_id, invisible_mode')
          .inFilter('user_id', userIds);
      final pList = List<Map<String, dynamic>>.from(privacyRows as List);
      for (final row in pList) {
        privacyHidden[row['user_id'] as String] =
            row['invisible_mode'] as bool? ?? false;
      }
    } catch (_) {}

    final result = <FamilyMemberLocation>[];
    for (var i = 0; i < memberList.length; i++) {
      final m = memberList[i];
      final uid = m['user_id'] as String;
      if (uid == currentUserId) continue;
      if (privacyHidden[uid] == true) continue;
      final loc = locationMap[uid];
      if (loc == null) continue;
      final lat = loc['latitude'];
      final lng = loc['longitude'];
      if (lat == null || lng == null) continue;
      final profile = profileMap[uid];
      final isOwner = m['role'] == 'owner';
      result.add(FamilyMemberLocation(
        userId: uid,
        name: profile?['name'] as String? ?? 'Unknown',
        role: isOwner ? 'Owner' : (m['role'] as String? ?? 'Member'),
        photoUrl: profile?['photo_url'] as String?,
        color: _memberColors[i % _memberColors.length],
        latitude: (lat as num).toDouble(),
        longitude: (lng as num).toDouble(),
        lastUpdated: loc['updated_at'] != null
            ? DateTime.parse(loc['updated_at'] as String)
            : DateTime.now(),
      ));
    }
    return result;
  }

  List<_NearbyFamilyMember> get _nearbyFamilyList {
    final self = _selfLocation;
    return _nearbyMembers
        .where((m) => !m.isLocationHidden)
        .map((m) => _NearbyFamilyMember(
              m.name,
              m.role,
              m.color,
              self != null
                  ? Geolocator.distanceBetween(
                      self.position.latitude,
                      self.position.longitude,
                      m.latitude,
                      m.longitude,
                    )
                  : null,
            ))
        .toList()
      ..sort((a, b) {
        final da = a.distanceMeters;
        final db = b.distanceMeters;
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return da.compareTo(db);
      });
  }

  String _formatDistance(double meters) {
    if (meters < 161) return '<0.1 mi';
    return '${(meters / 1609.344).toStringAsFixed(1)} mi';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final ext = theme.extension<AppThemeExtension>();

    final String addressValue;
    final String areaValue;
    final String coordinatesValue;
    final String updatedValue;
    final String accuracyValue;
    if (_locationLoading) {
      addressValue = 'Loading…';
      areaValue = 'Loading…';
      coordinatesValue = 'Loading…';
      updatedValue = 'Loading…';
      accuracyValue = 'Loading…';
    } else if (_selfLocation == null) {
      addressValue = 'Location unavailable';
      areaValue = 'Location unavailable';
      coordinatesValue = 'Location unavailable';
      updatedValue = 'Location unavailable';
      accuracyValue = 'Location unavailable';
    } else {
      final self = _selfLocation!;
      addressValue = self.address;
      areaValue = self.area;
      coordinatesValue = self.coordinates;
      updatedValue = 'Updated ${formatActivityTime(self.position.timestamp)}';
      accuracyValue = self.accuracyLabel;
    }

    final String statusLabel;
    final Color statusColor;
    if (_locationLoading) {
      statusLabel = 'Loading';
      statusColor = cs.onSurface;
    } else if (_selfLocation == null) {
      statusLabel = 'Unavailable';
      statusColor = AppTheme.danger;
    } else if (_selfLocation!.fromCache) {
      statusLabel = 'Cached';
      statusColor = AppTheme.warning;
    } else {
      statusLabel = 'Live';
      statusColor = AppTheme.success;
    }

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: ext?.backgroundGradient ??
                (isDark
                    ? [const Color(0xFF0A0F1E), const Color(0xFF060A14)]
                    : [const Color(0xFFF8FAFC), const Color(0xFFEFF6FF)]),
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                const SizedBox(height: 12),
                FadeIn(
                  duration: const Duration(milliseconds: 400),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : Colors.black.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: cs.outline.withValues(alpha: 0.3),
                              width: 0.5,
                            ),
                          ),
                          child: Icon(
                            Icons.chevron_left_rounded,
                            color: cs.onSurface,
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Location Details',
                        style: theme.textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                FadeIn(
                  delay: const Duration(milliseconds: 100),
                  duration: const Duration(milliseconds: 500),
                  beginOffset: const Offset(0, 0.1),
                  child: _MapPreview(
                    isDark: isDark,
                    cs: cs,
                    theme: theme,
                    statusLabel: statusLabel,
                    statusColor: statusColor,
                  ),
                ),
                const SizedBox(height: 20),
                FadeIn(
                  delay: const Duration(milliseconds: 200),
                  duration: const Duration(milliseconds: 500),
                  beginOffset: const Offset(0, 0.08),
                  child: GlassCard(
                    child: Column(
                      children: [
                        _DetailRow(
                          icon: Icons.place_rounded,
                          label: 'Address',
                          value: addressValue,
                          color: cs.primary,
                        ),
                        Divider(color: cs.outline.withValues(alpha: 0.2)),
                        _DetailRow(
                          icon: Icons.location_city_rounded,
                          label: 'Area',
                          value: areaValue,
                          color: cs.secondary,
                        ),
                        Divider(color: cs.outline.withValues(alpha: 0.2)),
                        _DetailRow(
                          icon: Icons.map_rounded,
                          label: 'Coordinates',
                          value: coordinatesValue,
                          color: AppTheme.tertiary,
                        ),
                        Divider(color: cs.outline.withValues(alpha: 0.2)),
                        _DetailRow(
                          icon: Icons.access_time_rounded,
                          label: 'Last Updated',
                          value: updatedValue,
                          color: AppTheme.warning,
                        ),
                        Divider(color: cs.outline.withValues(alpha: 0.2)),
                        _DetailRow(
                          icon: Icons.speed_rounded,
                          label: 'Accuracy',
                          value: accuracyValue,
                          color: AppTheme.success,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FadeIn(
                  delay: const Duration(milliseconds: 300),
                  duration: const Duration(milliseconds: 500),
                  beginOffset: const Offset(0, 0.08),
                  child: GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nearby Family',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _buildNearbyFamily(theme, cs),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNearbyFamily(ThemeData theme, ColorScheme cs) {
    if (_nearbyLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: cs.primary,
            ),
          ),
        ),
      );
    }

    final nearby = _nearbyFamilyList;
    if (nearby.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            Icon(
              Icons.people_outline_rounded,
              size: 26,
              color: cs.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 10),
            Text(
              'No nearby family members found.',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: cs.onSurface.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Family member locations will appear here.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.35),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < nearby.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _NearbyMember(
            name: nearby[i].name,
            relation: nearby[i].relation,
            color: nearby[i].color,
            distance: nearby[i].distanceMeters != null
                ? _formatDistance(nearby[i].distanceMeters!)
                : '--',
          ),
        ],
      ],
    );
  }
}

class _NearbyFamilyMember {
  final String name;
  final String relation;
  final Color color;
  final double? distanceMeters;

  const _NearbyFamilyMember(
    this.name,
    this.relation,
    this.color,
    this.distanceMeters,
  );
}

class _MapPreview extends StatelessWidget {
  final bool isDark;
  final ColorScheme cs;
  final ThemeData theme;
  final String statusLabel;
  final Color statusColor;

  const _MapPreview({
    required this.isDark,
    required this.cs,
    required this.theme,
    required this.statusLabel,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1A2744), const Color(0xFF0F1B33)]
              : [const Color(0xFFE8F0FE), const Color(0xFFD4E4FA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: cs.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: cs.primary.withValues(alpha: 0.4),
                        blurRadius: 24,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.person_pin_circle_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E293B)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Text(
                    'You',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 12,
            left: 12,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 14,
                        color: statusColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.35),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NearbyMember extends StatelessWidget {
  final String name;
  final String relation;
  final Color color;
  final String distance;

  const _NearbyMember({
    required this.name,
    required this.relation,
    required this.color,
    required this.distance,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withValues(alpha: 0.6)],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text(
              name.characters.first,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                  fontSize: 14,
                ),
              ),
              Text(
                relation,
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.4),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Icon(
          Icons.location_on_rounded,
          size: 14,
          color: cs.primary.withValues(alpha: 0.5),
        ),
        const SizedBox(width: 4),
        Text(
          distance,
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.5),
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
