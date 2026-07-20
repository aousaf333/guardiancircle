import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:guardiancircle/core/theme/app_theme.dart';
import 'package:guardiancircle/models/family_model.dart';
import 'package:guardiancircle/models/family_member_location.dart';
import 'package:guardiancircle/services/family_service.dart';
import 'package:guardiancircle/services/location_tracking_service.dart';
import 'package:guardiancircle/services/supabase_service.dart';
import 'package:guardiancircle/services/emergency_alert_service.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final LocationTrackingService _trackingService = LocationTrackingService();

  LatLng? _currentPosition;
  bool _isLoading = true;
  bool _mapReady = false;
  bool _isTracking = false;
  bool _hasCenteredOnce = false;
  String? _errorMessage;
  bool _permissionDenied = false;
  bool _gpsDisabled = false;

  List<FamilyModel> _families = [];
  String? _selectedFamilyId;
  List<FamilyMemberLocation> _familyMembers = [];
  RealtimeChannel? _realtimeSubscription;
  String? _selectedMemberId;
  int _familyLoadGeneration = 0;
  DateTime? _lastMapHistoryUpdate;
  double _lastMapHistoryLat = 0;
  double _lastMapHistoryLng = 0;

  static const _defaultCenter = LatLng(20.0, 0.0);
  static const _defaultZoom = 2.0;
  static const double _historyMinDistanceMeters = 25;
  static const Duration _historyMinTimeBetweenUpdates = Duration(minutes: 2);

  static const List<Color> _markerColors = [
    Color(0xFF3B82F6),
    Color(0xFFEC4899),
    Color(0xFF8B5CF6),
    Color(0xFFF59E0B),
    Color(0xFF06B6D4),
    Color(0xFFEF4444),
    Color(0xFF14B8A6),
    Color(0xFFF97316),
    Color(0xFF6366F1),
    Color(0xFF84CC16),
  ];

  @override
  void initState() {
    super.initState();
    _fetchFamilies();
  }

  @override
  void dispose() {
    _cancelRealtimeSubscription();
    _trackingService.dispose();
    super.dispose();
  }

  void _onMapReady() {
    _mapReady = true;
    _initTracking();
  }

  Future<void> _initTracking() async {
    if (!_mapReady) return;
    print('[Map] _initTracking: start');

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _permissionDenied = false;
      _gpsDisabled = false;
    });

    final hasPermission = await _trackingService.checkAndRequestPermission();
    print('[Map] _initTracking: hasPermission=$hasPermission');

    if (!hasPermission) {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      print('[Map] _initTracking: serviceEnabled=$serviceEnabled');
      if (mounted) {
        setState(() {
          if (!serviceEnabled) {
            _gpsDisabled = true;
          } else {
            _permissionDenied = true;
          }
          _isLoading = false;
        });
      }
      await _loadFamilyMembers();
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (!mounted) return;

      final latLng = LatLng(position.latitude, position.longitude);
      print('[Map] _initTracking: immediate position=$latLng');

      setState(() {
        _currentPosition = latLng;
        _isLoading = false;
        _isTracking = true;
      });

      _mapController.move(latLng, _mapController.camera.zoom);
      _hasCenteredOnce = true;

      await _forceUpsertCurrentLocation(position);
      await _loadFamilyMembers();
    } catch (e) {
      print('[Map] _initTracking: getCurrentPosition FAILED: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      await _loadFamilyMembers();
    }

    _startListening();
  }

  void _startListening() {
    print('[Map] _startListening: starting GPS stream');
    _trackingService.stopTracking();
    _hasCenteredOnce = false;

    _trackingService.startTracking((Position position) {
      if (!mounted) return;

      final latLng = LatLng(position.latitude, position.longitude);

      setState(() {
        _currentPosition = latLng;
        _isLoading = false;
        _isTracking = true;
      });

      if (!_hasCenteredOnce && _mapReady) {
        _hasCenteredOnce = true;
        _mapController.move(latLng, _mapController.camera.zoom);
      }
    });
  }

  void _locateMe() {
    HapticFeedback.mediumImpact();
    if (_currentPosition != null) {
      _mapController.move(_currentPosition!, _mapController.camera.zoom);
    }
  }

  Future<void> _forceUpsertCurrentLocation(Position position) async {
    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) {
        print('[Map] _forceUpsert: no current user, aborting');
        return;
      }

      await SupabaseService.client.from('user_locations').upsert(
        {
          'user_id': userId,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy': position.accuracy,
          'speed': position.speed,
          'heading': position.heading,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'user_id',
      );
      print('[Map] _forceUpsert: success for userId=$userId');

      await _saveLocationHistory(userId, position);
    } catch (e) {
      print('[Map] _forceUpsert: FAILED: $e');
    }
  }

  Future<void> _saveLocationHistory(String userId, Position position) async {
    try {
      final now = DateTime.now();
      final distance = Geolocator.distanceBetween(
        _lastMapHistoryLat,
        _lastMapHistoryLng,
        position.latitude,
        position.longitude,
      );
      final timeSinceLastHistory = _lastMapHistoryUpdate != null
          ? now.difference(_lastMapHistoryUpdate!)
          : _historyMinTimeBetweenUpdates;
      final shouldSaveHistory =
          distance >= _historyMinDistanceMeters || timeSinceLastHistory >= _historyMinTimeBetweenUpdates;
      if (!shouldSaveHistory) return;

      _lastMapHistoryLat = position.latitude;
      _lastMapHistoryLng = position.longitude;
      _lastMapHistoryUpdate = now;

      print('[Map] History Saved: userId=$userId, '
          'lat=${position.latitude}, lng=${position.longitude}');
      await SupabaseService.client.from('location_history').insert({
        'user_id': userId,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'speed': position.speed,
        'heading': position.heading,
        'recorded_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Family data loading
  // ---------------------------------------------------------------------------

  Future<void> _fetchFamilies() async {
    print('[Map] _fetchFamilies: start');
    try {
      final familyService = FamilyService.defaultClient();
      final families = await familyService.fetchFamilies();
      print('[Map] _fetchFamilies: loaded ${families.length} families');
      if (!mounted) return;

      setState(() {
        _families = families;
        if (_selectedFamilyId == null && families.isNotEmpty) {
          _selectedFamilyId = families.first.id;
          print('[Map] _fetchFamilies: auto-selected familyId=$_selectedFamilyId');
        }
      });

      if (_selectedFamilyId != null) {
        await _loadFamilyMembers();
      } else {
        print('[Map] _fetchFamilies: no families, skipping member load');
      }
    } catch (e, st) {
      print('[Map] _fetchFamilies: ERROR=$e');
      print('[Map] _fetchFamilies: $st');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadFamilyMembers() async {
    final familyId = _selectedFamilyId;
    if (familyId == null) {
      print('[Map] _loadFamilyMembers: no selectedFamilyId, abort');
      return;
    }

    final generation = ++_familyLoadGeneration;
    final supabase = SupabaseService.client;
    final currentUserId = supabase.auth.currentUser?.id;
    print('[Map] ========================================');
    print('[Map] _loadFamilyMembers: START');
    print('[Map]   familyId=$familyId');
    print('[Map]   currentUserId=$currentUserId');
    print('[Map]   gen=$generation');

    try {
      // --- Step 1: family_members ---
      List<Map<String, dynamic>> memberList = [];
      try {
        final memberRows = await supabase
            .from('family_members')
            .select('user_id, role')
            .eq('family_id', familyId);
        memberList = List<Map<String, dynamic>>.from(memberRows);
        print('[Map] Step1 family_members: ${memberList.length} rows');
        for (final row in memberList) {
          print('[Map]   member: user_id=${row["user_id"]}, role=${row["role"]}');
        }
      } catch (e) {
        print('[Map] Step1 family_members FAILED: $e');
      }

      if (memberList.isEmpty) {
        print('[Map] Step1: ZERO members for familyId=$familyId → no markers');
        _cancelRealtimeSubscription();
        if (mounted && generation == _familyLoadGeneration) {
          setState(() => _familyMembers = []);
        }
        return;
      }

      final userIds = memberList.map((r) => r['user_id'] as String).toList();
      print('[Map]   userIds=$userIds');

      // --- Step 2: user_locations ---
      final locationMap = <String, Map<String, dynamic>>{};
      try {
        final locationRows = await supabase
            .from('user_locations')
            .select('user_id, latitude, longitude, updated_at')
            .inFilter('user_id', userIds);
        final locList = List<Map<String, dynamic>>.from(locationRows as List);
        print('[Map] Step2 user_locations: ${locList.length} rows');
        for (final row in locList) {
          print('[Map]   loc: user_id=${row["user_id"]}, '
              'lat=${row["latitude"]}, lng=${row["longitude"]}, '
              'updated_at=${row["updated_at"]}');
          locationMap[row['user_id'] as String] = row;
        }
      } catch (e) {
        print('[Map] Step2 user_locations FAILED: $e');
      }
      print('[Map]   locationMap has ${locationMap.length} entries '
          'for ${userIds.length} userIds');

      // --- Step 3: profiles ---
      final profileMap = <String, Map<String, dynamic>>{};
      try {
        final profileRows = await supabase
            .from('profiles')
            .select('id, name, photo_url')
            .inFilter('id', userIds);
        final pList = List<Map<String, dynamic>>.from(profileRows as List);
        print('[Map] Step3 profiles: ${pList.length} rows');
        for (final row in pList) {
          print('[Map]   profile: id=${row["id"]}, name=${row["name"]}');
          profileMap[row['id'] as String] = row;
        }
      } catch (e) {
        print('[Map] Step3 profiles FAILED: $e');
      }
      print('[Map]   profileMap has ${profileMap.length} entries');

      // --- Step 4: merge ---
      final family = _families.cast<FamilyModel?>().firstWhere(
            (f) => f?.id == familyId,
            orElse: () => null,
          );
      final createdBy = family?.createdBy;

      final members = <FamilyMemberLocation>[];
      final skipped = <String>[];

      for (var i = 0; i < memberList.length; i++) {
        final m = memberList[i];
        final uid = m['user_id'] as String;
        final loc = locationMap[uid];

        if (loc == null) {
          final reason = 'no location in locationMap for $uid';
          skipped.add(reason);
          print('[Map]   SKIP $uid: $reason');
          continue;
        }

        final locLat = loc['latitude'];
        final locLng = loc['longitude'];
        if (locLat == null || locLng == null) {
          final reason = 'null lat/lng for $uid (lat=$locLat, lng=$locLng)';
          skipped.add(reason);
          print('[Map]   SKIP $uid: $reason');
          continue;
        }

        final profile = profileMap[uid];
        final name = profile?['name'] as String? ?? 'Unknown';
        final photoUrl = profile?['photo_url'] as String?;
        final isOwner = m['role'] == 'owner' || uid == createdBy;
        final role = isOwner ? 'Owner' : (m['role'] as String? ?? 'Member');

        final memberLoc = FamilyMemberLocation(
          userId: uid,
          name: name,
          role: role,
          photoUrl: photoUrl,
          color: uid == currentUserId
              ? const Color(0xFF10B981)
              : _markerColors[i % _markerColors.length],
          latitude: (locLat as num).toDouble(),
          longitude: (locLng as num).toDouble(),
          lastUpdated: loc['updated_at'] != null
              ? DateTime.parse(loc['updated_at'] as String)
              : DateTime.now(),
          battery: loc['battery'] != null
              ? (loc['battery'] as num).toDouble()
              : null,
        );
        members.add(memberLoc);
        print('[Map]   MARKER $uid: name=$name, role=$role, '
            'lat=${memberLoc.latitude}, lng=${memberLoc.longitude}');
      }

      print('[Map] ---- SUMMARY gen=$generation ----');
      print('[Map]   totalMembers=${memberList.length}');
      print('[Map]   membersWithLocation=${members.length}');
      print('[Map]   skipped=${skipped.length}: $skipped');
      print('[Map]   MARKERS CREATED=${members.length}');

      if (members.isEmpty) {
        print('[Map] *** NO MARKERS *** reasons:');
        if (locationMap.isEmpty) {
          print('[Map]   → locationMap is EMPTY – user_locations query returned 0 rows');
        }
        if (profileMap.isEmpty) {
          print('[Map]   → profileMap is EMPTY – profiles query returned 0 rows');
        }
        print('[Map]   → ${skipped.length} members skipped');
      }

      _cancelRealtimeSubscription();

      if (mounted && generation == _familyLoadGeneration) {
        setState(() => _familyMembers = members);
        print('[Map] setState: _familyMembers updated with ${members.length} markers');
        _subscribeToRealtime(familyId, userIds, currentUserId);
      } else {
        print('[Map] STALE gen=$generation (current=$_familyLoadGeneration) – state NOT updated');
      }

      print('[Map] ========================================');
    } catch (e, st) {
      print('[Map] _loadFamilyMembers: FATAL ERROR=$e');
      print('[Map] _loadFamilyMembers: $st');
      if (mounted && generation == _familyLoadGeneration) {
        setState(() => _familyMembers = []);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Supabase Realtime
  // ---------------------------------------------------------------------------

  void _subscribeToRealtime(
    String familyId,
    List<String> userIds,
    String? currentUserId,
  ) {
    _cancelRealtimeSubscription();

    _realtimeSubscription = SupabaseService.client
        .channel('family-locations-$familyId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_locations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.inFilter,
            column: 'user_id',
            value: userIds,
          ),
          callback: (payload) => _handleRealtimeUpdate(payload, currentUserId),
        )
        .subscribe();
  }

  void _handleRealtimeUpdate(
    PostgresChangePayload payload,
    String? currentUserId,
  ) {
    final newRecord = payload.newRecord;
    if (newRecord.isEmpty) return;

    final userId = newRecord['user_id'] as String?;
    if (userId == null) return;

    final lat = newRecord['latitude'];
    final lng = newRecord['longitude'];
    if (lat == null || lng == null) return;

    final updatedAtStr = newRecord['updated_at'] as String?;
    if (updatedAtStr == null) return;

    final memberIndex = _familyMembers.indexWhere((m) => m.userId == userId);

    if (memberIndex == -1) return;

    final member = _familyMembers[memberIndex];
    final updated = member.copyWith(
      latitude: (lat as num).toDouble(),
      longitude: (lng as num).toDouble(),
      lastUpdated: DateTime.parse(updatedAtStr),
      battery: newRecord['battery'] != null
          ? (newRecord['battery'] as num).toDouble()
          : member.battery,
    );

    if (mounted) {
      setState(() {
        _familyMembers[memberIndex] = updated;
      });
    }
  }

  void _cancelRealtimeSubscription() {
    if (_realtimeSubscription != null) {
      SupabaseService.client.removeChannel(_realtimeSubscription!);
      _realtimeSubscription = null;
    }
  }

  // ---------------------------------------------------------------------------
  // Family selector
  // ---------------------------------------------------------------------------

  void _showFamilySelector() {
    if (_families.length <= 1) return;
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final cs = theme.colorScheme;
        final isDark = theme.brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF111827) : Colors.white,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Select Family',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              ..._families.map(
                (f) {
                  final isSelected = f.id == _selectedFamilyId;
                  return Material(
                    color: Colors.transparent,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? cs.primary.withValues(alpha: 0.15)
                              : cs.surfaceContainerHighest
                                  .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            f.name.characters.first.toUpperCase(),
                            style: TextStyle(
                              color:
                                  isSelected ? cs.primary : cs.onSurface,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      title: Text(
                        f.name,
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check_circle_rounded,
                              color: cs.primary, size: 20)
                          : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        _selectFamily(f.id);
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _selectFamily(String familyId) {
    if (familyId == _selectedFamilyId) return;
    setState(() {
      _selectedFamilyId = familyId;
      _familyMembers = [];
    });
    _loadFamilyMembers();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: _buildMapWidget(),
          ),
          if (_isLoading)
            Positioned.fill(
              child: _buildLoadingOverlay(isDark, cs),
            ),
          if (!_isLoading &&
              (_permissionDenied || _gpsDisabled || _errorMessage != null))
            Positioned.fill(
              child: _buildErrorOverlay(theme, cs, isDark),
            ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildTopBar(theme, cs, isDark),
          ),
          if (_currentPosition != null)
            Positioned(
              right: 16,
              bottom: 100,
              child: _buildLocateMeFab(cs, isDark),
            ),
          if (_selectedMemberId != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 70,
              left: 0,
              right: 0,
              child: Center(
                child: _buildMemberPopup(_selectedMemberId!),
              ),
            ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 70,
            left: 16,
            right: 16,
            child: _SosAlertOverlay(),
          ),
        ],
      ),
    );
  }

  Widget _buildMapWidget() {
    final center = _currentPosition ?? _defaultCenter;
    final zoom = _currentPosition != null ? 16.0 : _defaultZoom;

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: zoom,
        maxZoom: 19,
        minZoom: 3,
        onMapReady: _onMapReady,
        onTap: (_, _) {
          if (_selectedMemberId != null) {
            setState(() => _selectedMemberId = null);
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.guardiancircle.app',
          maxZoom: 19,
          errorImage: null,
        ),
        MarkerLayer(markers: _buildAllMarkers()),
      ],
    );
  }

  List<Marker> _buildAllMarkers() {
    final markers = <Marker>[];

    for (final member in _familyMembers) {
      final isCurrentUser = member.userId ==
          SupabaseService.client.auth.currentUser?.id;
      markers.add(
        Marker(
          key: ValueKey(member.userId),
          point: LatLng(member.latitude, member.longitude),
          width: 52,
          height: 68,
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() {
                _selectedMemberId =
                    _selectedMemberId == member.userId ? null : member.userId;
              });
            },
            child: _FamilyMemberMarker(
              name: member.name,
              photoUrl: member.photoUrl,
              color: member.color,
              isCurrentUser: isCurrentUser,
            ),
          ),
        ),
      );
    }

    return markers;
  }

  Widget _buildMemberPopup(String memberId) {
    final member =
        _familyMembers.where((m) => m.userId == memberId).firstOrNull;
    if (member == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final initials = member.name.characters
        .take(2)
        .join()
        .toUpperCase();

    return GestureDetector(
      onTap: () {},
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: member.color.withValues(alpha: 0.15),
                  backgroundImage: member.photoUrl != null
                      ? NetworkImage(member.photoUrl!)
                      : null,
                  child: member.photoUrl == null
                      ? Text(
                          initials,
                          style: TextStyle(
                            color: member.color,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: member.role == 'Owner'
                              ? AppTheme.primary.withValues(alpha: 0.1)
                              : cs.surfaceContainerHighest
                                  .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          member.role,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: member.role == 'Owner'
                                ? AppTheme.primary
                                : cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  _PopupInfoItem(
                    icon: Icons.access_time_rounded,
                    label: _formatTimeAgo(member.lastUpdated),
                    cs: cs,
                  ),
                  const SizedBox(width: 12),
                  _PopupInfoItem(
                    icon: Icons.battery_std_rounded,
                    label: member.battery != null
                        ? '${member.battery!.round()}%'
                        : '--',
                    cs: cs,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  // ---------------------------------------------------------------------------
  // Overlays
  // ---------------------------------------------------------------------------

  Widget _buildLoadingOverlay(bool isDark, ColorScheme cs) {
    return Container(
      color: isDark
          ? const Color(0xFF0A0F1E).withValues(alpha: 0.7)
          : Colors.white.withValues(alpha: 0.7),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Getting your location...',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.6),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorOverlay(ThemeData theme, ColorScheme cs, bool isDark) {
    if (_gpsDisabled) {
      return _buildStatusCard(
        theme: theme,
        cs: cs,
        isDark: isDark,
        icon: Icons.location_off_rounded,
        iconColor: AppTheme.warning,
        title: 'Location Services Disabled',
        subtitle: 'Please enable GPS to show your position on the map.',
        buttonLabel: 'Enable Location',
        onPressed: () => Geolocator.openLocationSettings(),
        secondaryLabel: 'Retry',
        onSecondary: _initTracking,
      );
    }

    if (_permissionDenied) {
      return _buildStatusCard(
        theme: theme,
        cs: cs,
        isDark: isDark,
        icon: Icons.location_disabled_rounded,
        iconColor: AppTheme.danger,
        title: 'Location Permission Required',
        subtitle:
            'Grant location permission to display your position on the map.',
        buttonLabel: 'Grant Permission',
        onPressed: () => Geolocator.openAppSettings(),
        secondaryLabel: 'Retry',
        onSecondary: _initTracking,
      );
    }

    if (_errorMessage != null) {
      return _buildStatusCard(
        theme: theme,
        cs: cs,
        isDark: isDark,
        icon: Icons.error_outline_rounded,
        iconColor: AppTheme.danger,
        title: 'Location Error',
        subtitle: _errorMessage!,
        buttonLabel: 'Retry',
        onPressed: _initTracking,
        secondaryLabel: 'Dismiss',
        onSecondary: _initTracking,
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildStatusCard({
    required ThemeData theme,
    required ColorScheme cs,
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String buttonLabel,
    required VoidCallback onPressed,
    required String secondaryLabel,
    required VoidCallback onSecondary,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: cs.surface.withValues(alpha: isDark ? 0.85 : 0.92),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: cs.outline.withValues(alpha: 0.2),
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
                    blurRadius: 40,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 32, color: iconColor),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.5),
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: onPressed,
                      style: FilledButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        buttonLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: onSecondary,
                      child: Text(
                        secondaryLabel,
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.5),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(ThemeData theme, ColorScheme cs, bool isDark) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.white.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06),
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black
                        .withValues(alpha: isDark ? 0.3 : 0.06),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.map_rounded,
                      color: cs.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Live Map',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                            ),
                            if (_isTracking) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981)
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF10B981),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'LIVE',
                                      style: TextStyle(
                                        color: const Color(0xFF10B981),
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          _currentPosition != null
                              ? _familyMembers.isNotEmpty
                                  ? '${_familyMembers.length} ${_familyMembers.length == 1 ? 'member' : 'members'} on map'
                                  : 'Locating family...'
                              : _isLoading
                                  ? 'Getting location...'
                                  : 'Location unavailable',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_families.length > 1) ...[
                    _buildFamilySelectorButton(cs, isDark),
                    const SizedBox(width: 8),
                  ],
                  GestureDetector(
                    onTap: () => context.push('/location-history'),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.route_rounded,
                        color: cs.primary,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_isLoading)
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.primary,
                      ),
                    )
                  else if (_currentPosition != null)
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981)
                                .withValues(alpha: 0.5),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFamilySelectorButton(ColorScheme cs, bool isDark) {
    return GestureDetector(
      onTap: _showFamilySelector,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.family_restroom_rounded,
              size: 16,
              color: cs.primary,
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: cs.onSurface.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocateMeFab(ColorScheme cs, bool isDark) {
    return GestureDetector(
      onTap: _locateMe,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              cs.primary,
              cs.primary.withValues(alpha: 0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: cs.primary.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black
                  .withValues(alpha: isDark ? 0.4 : 0.1),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.my_location_rounded,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Marker widgets
// ---------------------------------------------------------------------------

class _FamilyMemberMarker extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final Color color;
  final bool isCurrentUser;

  const _FamilyMemberMarker({
    required this.name,
    this.photoUrl,
    required this.color,
    required this.isCurrentUser,
  });

  @override
  Widget build(BuildContext context) {
    final initials = name.characters.take(2).join().toUpperCase();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: isCurrentUser ? 3 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.5),
                blurRadius: isCurrentUser ? 14 : 10,
                spreadRadius: isCurrentUser ? 3 : 1,
              ),
            ],
            image: photoUrl != null
                ? DecorationImage(
                    image: NetworkImage(photoUrl!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: photoUrl == null
              ? Center(
                  child: Text(
                    initials,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                )
              : null,
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF151D30),
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 6,
              ),
            ],
          ),
          child: Text(
            isCurrentUser ? 'You' : name.split(' ').first,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// SOS Alert Overlay
// ---------------------------------------------------------------------------

class _SosAlertOverlay extends StatefulWidget {
  @override
  State<_SosAlertOverlay> createState() => _SosAlertOverlayState();
}

class _SosAlertOverlayState extends State<_SosAlertOverlay>
    with SingleTickerProviderStateMixin {
  EmergencyAlertWithSender? _currentAlert;
  Timer? _dismissTimer;
  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
    EmergencyAlertService.activeAlertsNotifier.addListener(_onAlertsChanged);
  }

  @override
  void dispose() {
    EmergencyAlertService.activeAlertsNotifier
        .removeListener(_onAlertsChanged);
    _dismissTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  void _onAlertsChanged() {
    final alerts = EmergencyAlertService.activeAlertsNotifier.value;
    if (alerts.isEmpty) {
      _dismissAlert();
      return;
    }
    final newest = alerts.first;
    if (_currentAlert != null && _currentAlert!.alert.id == newest.alert.id) {
      return;
    }
    _showAlert(newest);
  }

  void _showAlert(EmergencyAlertWithSender alert) {
    _dismissTimer?.cancel();
    setState(() => _currentAlert = alert);
    _animController.forward(from: 0.0);
    _dismissTimer = Timer(const Duration(seconds: 10), _dismissAlert);
    print('[SOS Map Overlay] Showing alert: alertId=${alert.alert.id}');
  }

  void _dismissAlert() {
    _dismissTimer?.cancel();
    _animController.reverse().then((_) {
      if (mounted) setState(() => _currentAlert = null);
    });
    print('[SOS Map Overlay] Dismissed');
  }

  Future<void> _dismissPermanently() async {
    if (_currentAlert == null) return;
    final alertId = _currentAlert!.alert.id;
    final service = EmergencyAlertService.defaultClient();
    await service.dismissNotification(alertId);
    _dismissAlert();
    print('[SOS Map Overlay] Permanently dismissed: alertId=$alertId');
  }

  String _elapsedText(DateTime createdAt) {
    final d = DateTime.now().difference(createdAt);
    if (d.inSeconds < 10) return 'Just now';
    if (d.inSeconds < 60) return '${d.inSeconds}s ago';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    return '${d.inHours}h ago';
  }

  @override
  Widget build(BuildContext context) {
    if (_currentAlert == null) return const SizedBox.shrink();

    final alert = _currentAlert!;
    final initial =
        alert.senderName.characters.first.toUpperCase();

    return SlideTransition(
      position: _slideAnim,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: GestureDetector(
          onTap: () {
            print('[SOS Map Overlay] Tapped: navigating to '
                'alertId=${alert.alert.id}');
            context.push('/sos-alert-detail/${alert.alert.id}');
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.danger.withValues(alpha: 0.4),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: alert.senderPhotoUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            alert.senderPhotoUrl!,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Center(
                              child: Text(
                                initial,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            initial,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'EMERGENCY',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${alert.senderName} needs help',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _elapsedText(alert.alert.createdAt),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    print('[SOS Map Overlay] Close button tapped');
                    _dismissPermanently();
                  },
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Popup info item
// ---------------------------------------------------------------------------

class _PopupInfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final ColorScheme cs;

  const _PopupInfoItem({
    required this.icon,
    required this.label,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: cs.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
