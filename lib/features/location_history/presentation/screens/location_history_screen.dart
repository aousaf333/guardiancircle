import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:guardiancircle/core/theme/app_theme.dart';
import 'package:guardiancircle/services/supabase_service.dart';
import 'package:guardiancircle/services/family_service.dart';
import 'package:latlong2/latlong.dart';

class LocationHistoryScreen extends StatefulWidget {
  const LocationHistoryScreen({super.key});

  @override
  State<LocationHistoryScreen> createState() => _LocationHistoryScreenState();
}

class _LocationHistoryScreenState extends State<LocationHistoryScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnim;
  final MapController _mapController = MapController();

  List<Map<String, dynamic>> _familyMembers = [];
  String? _selectedMemberId;
  String? _selectedFamilyId;
  bool _isLoadingMembers = true;
  bool _isLoadingHistory = false;

  List<Map<String, dynamic>> _historyPoints = [];
  List<LatLng> _polylinePoints = [];
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 1));
  DateTime _endDate = DateTime.now();
  int _selectedFilter = 0;
  static const _filters = ['Today', 'Yesterday', 'Last 7 Days', 'Custom'];

  static const List<Color> _memberColors = [
    Color(0xFF3B82F6),
    Color(0xFFEC4899),
    Color(0xFF8B5CF6),
    Color(0xFFF59E0B),
    Color(0xFF06B6D4),
    Color(0xFFEF4444),
    Color(0xFF14B8A6),
    Color(0xFFF97316),
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic);
    _fadeController.forward();
    _loadFamiliesAndMembers();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadFamiliesAndMembers() async {
    print('[LocationHistory] Loading families and members...');
    setState(() => _isLoadingMembers = true);
    try {
      final familyService = FamilyService.defaultClient();
      final families = await familyService.fetchFamilies();
      if (!mounted) return;

      if (families.isEmpty) {
        print('[LocationHistory] No families found');
        setState(() {
          _familyMembers = [];
          _isLoadingMembers = false;
        });
        return;
      }

      _selectedFamilyId = families.first.id;
      print('[LocationHistory] Selected familyId=$_selectedFamilyId');
      final members = await familyService.fetchFamilyMembers(_selectedFamilyId!);
      if (!mounted) return;

      print('[LocationHistory] Loaded ${members.length} family members');
      setState(() {
        _familyMembers = members;
        _isLoadingMembers = false;
        if (members.isNotEmpty && _selectedMemberId == null) {
          final currentUserId = SupabaseService.client.auth.currentUser?.id;
          final currentMember = members.firstWhere(
            (m) => m['user_id'] == currentUserId,
            orElse: () => members.first,
          );
          _selectedMemberId = currentMember['user_id'] as String;
          print('[LocationHistory] Auto-selected member=$_selectedMemberId');
        }
      });

      if (_selectedMemberId != null) {
        await _loadHistory();
      }
    } catch (e) {
      print('[LocationHistory] Error loading families: $e');
      if (mounted) setState(() => _isLoadingMembers = false);
    }
  }

  Future<void> _loadHistory() async {
    final memberId = _selectedMemberId;
    if (memberId == null) return;

    print('[LocationHistory] Loading history for memberId=$memberId');
    print('[LocationHistory] Date range: ${_startDate.toIso8601String()} to ${_endDate.toIso8601String()}');

    setState(() {
      _isLoadingHistory = true;
      _historyPoints = [];
      _polylinePoints = [];
    });

    try {
      final startIso = _startDate.toUtc().toIso8601String();
      final endIso = _endDate
          .add(const Duration(days: 1))
          .subtract(const Duration(seconds: 1))
          .toUtc()
          .toIso8601String();

      print('[LocationHistory] Querying location_history: start=$startIso, end=$endIso');

      final rows = await SupabaseService.client
          .from('location_history')
          .select('id, latitude, longitude, accuracy, speed, heading, recorded_at')
          .eq('user_id', memberId)
          .gte('recorded_at', startIso)
          .lte('recorded_at', endIso)
          .order('recorded_at', ascending: true);

      final points = List<Map<String, dynamic>>.from(rows as List);
      print('[LocationHistory] History Loaded: ${points.length} points');

      final latLngs = points
          .map((p) => LatLng(
                (p['latitude'] as num).toDouble(),
                (p['longitude'] as num).toDouble(),
              ))
          .toList();

      print('[LocationHistory] Route Points Loaded: ${latLngs.length}');

      if (latLngs.length >= 2) {
        final totalDist = _calculateTotalDistance(latLngs);
        final startTime = DateTime.parse(points.first['recorded_at'] as String);
        final endTime = DateTime.parse(points.last['recorded_at'] as String);
        final duration = endTime.difference(startTime);
        print('[LocationHistory] Polyline Created: ${latLngs.length} vertices');
        print('[LocationHistory] Total Distance: ${totalDist.toStringAsFixed(1)}m');
        print('[LocationHistory] Total Duration: ${duration.inMinutes}m ${duration.inSeconds % 60}s');
      }

      if (!mounted) return;
      setState(() {
        _historyPoints = points;
        _polylinePoints = latLngs;
        _isLoadingHistory = false;
      });

      if (latLngs.isNotEmpty) {
        _fitMapToPoints(latLngs);
      }
    } catch (e) {
      print('[LocationHistory] Error loading history: $e');
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  void _fitMapToPoints(List<LatLng> points) {
    if (points.isEmpty) return;
    if (points.length == 1) {
      _mapController.move(points.first, 16.0);
      return;
    }
    final bounds = LatLngBounds.fromPoints(points);
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60)),
    );
  }

  void _applyFilter(int index) {
    HapticFeedback.lightImpact();
    final now = DateTime.now();
    setState(() {
      _selectedFilter = index;
      switch (index) {
        case 0:
          _startDate = DateTime(now.year, now.month, now.day);
          _endDate = now;
          break;
        case 1:
          _startDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
          _endDate = DateTime(now.year, now.month, now.day).subtract(const Duration(seconds: 1));
          break;
        case 2:
          _startDate = now.subtract(const Duration(days: 7));
          _endDate = now;
          break;
        case 3:
          return;
      }
    });
    _loadHistory();
  }

  double _calculateTotalDistance(List<LatLng> points) {
    if (points.length < 2) return 0;
    double total = 0;
    const dist = Distance();
    for (var i = 1; i < points.length; i++) {
      total += dist(points[i - 1], points[i]);
    }
    return total;
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()}m';
    return '${(meters / 1000).toStringAsFixed(1)}km';
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
    if (d.inMinutes > 0) return '${d.inMinutes}m';
    return '${d.inSeconds}s';
  }

  void _moveMapToIndex(int index) {
    if (index < 0 || index >= _polylinePoints.length) return;
    HapticFeedback.lightImpact();
    final point = _polylinePoints[index];
    _mapController.move(point, 17.0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final ext = theme.extension<AppThemeExtension>();

    return Scaffold(
      body: Container(
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
          bottom: false,
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Column(
              children: [
                _buildHeader(theme, cs, isDark),
                _buildMemberSelector(theme, cs, isDark),
                _buildFilterChips(theme, cs, isDark),
                Expanded(
                  child: _isLoadingHistory
                      ? Center(child: CircularProgressIndicator(strokeWidth: 2.5, color: cs.primary))
                      : _historyPoints.isEmpty
                          ? _buildEmptyState(theme, cs, isDark)
                          : _buildContent(theme, cs, isDark),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, ColorScheme cs, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: cs.surface.withValues(alpha: isDark ? 0.5 : 0.7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outline.withValues(alpha: 0.3), width: 0.5),
              ),
              child: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: cs.onSurface.withValues(alpha: 0.6)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Location History',
                  style: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_historyPoints.length} points recorded',
                  style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurface.withValues(alpha: 0.4)),
                ),
              ],
            ),
          ),
          if (_historyPoints.length >= 2)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: isDark ? 0.15 : 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.straighten_rounded, size: 14, color: cs.primary),
                  const SizedBox(width: 4),
                  Text(
                    _formatDistance(_calculateTotalDistance(_polylinePoints)),
                    style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMemberSelector(ThemeData theme, ColorScheme cs, bool isDark) {
    if (_isLoadingMembers) return const SizedBox.shrink();

    return SizedBox(
      height: 56,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        scrollDirection: Axis.horizontal,
        itemCount: _familyMembers.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final member = _familyMembers[index];
          final memberId = member['user_id'] as String;
          final profile = member['profile'] as Map<String, dynamic>?;
          final name = profile?['name'] as String? ?? 'Unknown';
          final photoUrl = profile?['photo_url'] as String?;
          final isSelected = _selectedMemberId == memberId;
          final color = _memberColors[index % _memberColors.length];

          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _selectedMemberId = memberId);
              _loadHistory();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withValues(alpha: 0.15)
                    : cs.surface.withValues(alpha: isDark ? 0.5 : 0.7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? color.withValues(alpha: 0.5) : cs.outline.withValues(alpha: 0.4),
                  width: isSelected ? 1.5 : 0.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: color.withValues(alpha: 0.2),
                    backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                    child: photoUrl == null
                        ? Text(name.characters.first.toUpperCase(),
                            style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12))
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    name.split(' ').first,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13,
                      color: isSelected ? color : cs.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterChips(ThemeData theme, ColorScheme cs, bool isDark) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final selected = _selectedFilter == index;
          return GestureDetector(
            onTap: () => _applyFilter(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? cs.primary : cs.surface.withValues(alpha: isDark ? 0.5 : 0.7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? cs.primary : cs.outline.withValues(alpha: 0.5),
                  width: 0.5,
                ),
                boxShadow: selected
                    ? [BoxShadow(color: cs.primary.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))]
                    : null,
              ),
              child: Center(
                child: Text(
                  _filters[index],
                  style: TextStyle(
                    color: selected ? Colors.white : cs.onSurface.withValues(alpha: 0.55),
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent(ThemeData theme, ColorScheme cs, bool isDark) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        SliverToBoxAdapter(child: _buildMap(cs, isDark)),
        SliverToBoxAdapter(child: _buildStatsBar(theme, cs, isDark)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Text(
              'ROUTE TIMELINE',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: cs.onSurface.withValues(alpha: 0.4),
                letterSpacing: 0.5,
                fontSize: 12,
              ),
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => _buildTimelineItem(index, theme, cs, isDark),
            childCount: _historyPoints.length,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildMap(ColorScheme cs, bool isDark) {
    final center = _polylinePoints.isNotEmpty ? _polylinePoints.first : const LatLng(20.0, 0.0);
    final zoom = _polylinePoints.length == 1 ? 16.0 : 13.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 240,
          decoration: BoxDecoration(
            border: Border.all(color: cs.outline.withValues(alpha: 0.2), width: 0.5),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: zoom,
                    maxZoom: 19,
                    minZoom: 3,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.guardiancircle.app',
                      maxZoom: 19,
                    ),
                    if (_polylinePoints.length >= 2)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _polylinePoints,
                            color: cs.primary.withValues(alpha: 0.8),
                            strokeWidth: 4.0,
                          ),
                        ],
                      ),
                    MarkerLayer(markers: _buildRouteMarkers(cs)),
                  ],
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      '${_polylinePoints.length} pts',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
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

  List<Marker> _buildRouteMarkers(ColorScheme cs) {
    if (_polylinePoints.isEmpty) return [];

    final markers = <Marker>[];

    if (_polylinePoints.length >= 2) {
      // Start marker
      markers.add(
        Marker(
          point: _polylinePoints.first,
          width: 32,
          height: 32,
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.success,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [BoxShadow(color: AppTheme.success.withValues(alpha: 0.5), blurRadius: 8)],
            ),
            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
          ),
        ),
      );
      // End marker
      markers.add(
        Marker(
          point: _polylinePoints.last,
          width: 32,
          height: 32,
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.danger,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [BoxShadow(color: AppTheme.danger.withValues(alpha: 0.5), blurRadius: 8)],
            ),
            child: const Icon(Icons.stop_rounded, color: Colors.white, size: 18),
          ),
        ),
      );
    } else if (_polylinePoints.length == 1) {
      markers.add(
        Marker(
          point: _polylinePoints.first,
          width: 36,
          height: 36,
          child: Container(
            decoration: BoxDecoration(
              color: cs.primary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [BoxShadow(color: cs.primary.withValues(alpha: 0.5), blurRadius: 10)],
            ),
            child: const Icon(Icons.person_rounded, color: Colors.white, size: 18),
          ),
        ),
      );
    }

    return markers;
  }

  Widget _buildStatsBar(ThemeData theme, ColorScheme cs, bool isDark) {
    if (_historyPoints.length < 2) return const SizedBox.shrink();

    final totalDistance = _calculateTotalDistance(_polylinePoints);
    final startTime = DateTime.parse(_historyPoints.first['recorded_at'] as String);
    final endTime = DateTime.parse(_historyPoints.last['recorded_at'] as String);
    final duration = endTime.difference(startTime);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          _statCard(cs, isDark, Icons.straighten_rounded, 'Distance', _formatDistance(totalDistance), AppTheme.primary),
          const SizedBox(width: 8),
          _statCard(cs, isDark, Icons.timer_outlined, 'Duration', _formatDuration(duration), AppTheme.accent),
          const SizedBox(width: 8),
          _statCard(cs, isDark, Icons.location_on_outlined, 'Points', '${_historyPoints.length}', AppTheme.success),
        ],
      ),
    );
  }

  Widget _statCard(ColorScheme cs, bool isDark, IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: isDark ? 0.45 : 0.65),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outline.withValues(alpha: 0.3), width: 0.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(value, style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 14)),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(color: cs.onSurface.withValues(alpha: 0.4), fontWeight: FontWeight.w500, fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineItem(int index, ThemeData theme, ColorScheme cs, bool isDark) {
    final point = _historyPoints[index];
    final isFirst = index == 0;
    final isLast = index == _historyPoints.length - 1;
    final recordedAt = DateTime.parse(point['recorded_at'] as String);
    final timeStr = '${recordedAt.hour.toString().padLeft(2, '0')}:${recordedAt.minute.toString().padLeft(2, '0')}';
    final dateStr = '${recordedAt.month.toString().padLeft(2, '0')}/${recordedAt.day.toString().padLeft(2, '0')}';
    final speed = point['speed'] as num?;

    return GestureDetector(
      onTap: () => _moveMapToIndex(index),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 40,
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isFirst
                          ? AppTheme.success.withValues(alpha: isDark ? 0.15 : 0.1)
                          : isLast
                              ? AppTheme.danger.withValues(alpha: isDark ? 0.15 : 0.1)
                              : cs.primary.withValues(alpha: isDark ? 0.15 : 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isFirst
                            ? AppTheme.success.withValues(alpha: 0.3)
                            : isLast
                                ? AppTheme.danger.withValues(alpha: 0.3)
                                : cs.primary.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      isFirst ? Icons.play_arrow_rounded : isLast ? Icons.stop_rounded : Icons.circle,
                      size: 18,
                      color: isFirst ? AppTheme.success : isLast ? AppTheme.danger : cs.primary,
                    ),
                  ),
                  if (!isLast) Container(width: 1.5, height: 20, color: cs.onSurface.withValues(alpha: 0.07)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.surface.withValues(alpha: isDark ? 0.55 : 0.75),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: cs.outline.withValues(alpha: 0.3), width: 0.5),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      '$timeStr  $dateStr',
                                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, fontSize: 14),
                                    ),
                                    if (isFirst) ...[
                                      const SizedBox(width: 6),
                                      _buildTag('START', AppTheme.success, isDark),
                                    ],
                                    if (isLast && !isFirst) ...[
                                      const SizedBox(width: 6),
                                      _buildTag('END', AppTheme.danger, isDark),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${(point['latitude'] as num).toStringAsFixed(4)}, ${(point['longitude'] as num).toStringAsFixed(4)}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.onSurface.withValues(alpha: 0.4),
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (speed != null && speed > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${(speed * 3.6).toStringAsFixed(1)} km/h',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.onSurface.withValues(alpha: 0.5)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 9)),
    );
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme cs, bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.route_rounded, size: 32, color: cs.primary.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 16),
          Text(
            'No Location History Found',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Location data will appear here once\ntracking is active',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.4),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
