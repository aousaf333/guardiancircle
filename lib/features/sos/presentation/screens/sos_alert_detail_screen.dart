import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:guardiancircle/core/theme/app_theme.dart';
import 'package:guardiancircle/services/emergency_alert_service.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

class SosAlertDetailScreen extends StatefulWidget {
  final String alertId;
  const SosAlertDetailScreen({super.key, required this.alertId});
  @override
  State<SosAlertDetailScreen> createState() => _SosAlertDetailScreenState();
}

class _SosAlertDetailScreenState extends State<SosAlertDetailScreen> {
  final EmergencyAlertService _service = EmergencyAlertService.defaultClient();
  EmergencyAlertWithSender? _alertData;
  bool _isLoading = true;
  Timer? _refreshTimer;
  int _elapsedSeconds = 0;
  Timer? _elapsedTimer;
  final MapController _mapController = MapController();
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    print('[SOS Detail] initState: alertId=${widget.alertId}');
    EmergencyAlertService.viewingAlertNotifier.value = null;
    _loadAlert();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _refreshAlert(),
    );
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_disposed) setState(() => _elapsedSeconds++);
    });
  }

  @override
  void dispose() {
    print('[SOS Detail] dispose: alertId=${widget.alertId}');
    _disposed = true;
    _refreshTimer?.cancel();
    _elapsedTimer?.cancel();
    EmergencyAlertService.viewingAlertNotifier.value = null;
    super.dispose();
  }

  String get _elapsedText {
    final m = _elapsedSeconds ~/ 60;
    final s = _elapsedSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _loadAlert() async {
    try {
      print('[SOS Detail] _loadAlert: fetching alertId=${widget.alertId}');
      final data = await _service.fetchAlert(widget.alertId);
      if (data != null && mounted && !_disposed) {
        final diff = DateTime.now().difference(data.alert.createdAt);
        print('[SOS Detail] _loadAlert: loaded alertId=${data.alert.id}, '
            'status=${data.alert.status}');
        setState(() {
          _alertData = data;
          _elapsedSeconds = diff.inSeconds;
          _isLoading = false;
        });
      } else if (mounted && !_disposed) {
        print('[SOS Detail] _loadAlert: alert not found');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('[SOS Detail] _loadAlert: ERROR=$e');
      if (mounted && !_disposed) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshAlert() async {
    if (_disposed) return;
    try {
      final data = await _service.fetchAlert(widget.alertId);
      if (data != null && mounted && !_disposed) {
        print('[SOS Detail] _refreshAlert: updated status=${data.alert.status}');
        setState(() => _alertData = data);
      }
    } catch (e) {
      print('[SOS Detail] _refreshAlert: ERROR=$e');
    }
  }

  void _openOnLiveMap() {
    final alert = _alertData?.alert;
    if (alert == null) return;
    print('[SOS Detail] _openOnLiveMap: switching to Map tab');
    context.go('/map');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _alertData?.alert.isActive == true
                ? [const Color(0xFF1A0505), const Color(0xFF0A0F1E)]
                : isDark
                    ? [const Color(0xFF0A0F1E), const Color(0xFF060A14)]
                    : [const Color(0xFFF8FAFC), const Color(0xFFEFF6FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? Center(
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: cs.primary,
                    ),
                  ),
                )
              : _alertData == null
                  ? _buildNotFound(theme, cs, isDark)
                  : _buildContent(theme, cs, isDark),
        ),
      ),
    );
  }

  Widget _buildNotFound(ThemeData theme, ColorScheme cs, bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: cs.onSurface.withValues(alpha: 0.3),
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'Alert not found',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'Go Back',
                style: TextStyle(
                  color: cs.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ThemeData theme, ColorScheme cs, bool isDark) {
    final alert = _alertData!.alert;
    final isActive = alert.isActive;
    final senderInitial = _alertData!.senderName.characters.first.toUpperCase();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
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
                Expanded(
                  child: Text(
                    'Emergency Alert',
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                if (isActive)
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.danger.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: AppTheme.danger,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0x80EF4444),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Text(
                            'ACTIVE',
                            style: TextStyle(
                              color: AppTheme.danger,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Sender info card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isActive
                    ? AppTheme.danger.withValues(alpha: 0.06)
                    : cs.surface.withValues(alpha: isDark ? 0.45 : 0.65),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive
                      ? AppTheme.danger.withValues(alpha: 0.2)
                      : cs.outline.withValues(alpha: 0.25),
                  width: 0.5,
                ),
              ),
              child: Row(
                children: [
                  // Profile photo / initial
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isActive
                            ? [AppTheme.danger, AppTheme.dangerLight]
                            : [cs.primary, cs.primary.withValues(alpha: 0.7)],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: (isActive ? AppTheme.danger : cs.primary)
                              .withValues(alpha: 0.3),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: _alertData!.senderPhotoUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image.network(
                              _alertData!.senderPhotoUrl!,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Center(
                                child: Text(
                                  senderInitial,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 22,
                                  ),
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              senderInitial,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 22,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_alertData!.senderName} needs help',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 13,
                              color: cs.onSurface.withValues(alpha: 0.4),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isActive ? 'Started $_elapsedText ago' : _alertData!.elapsedText,
                              style: TextStyle(
                                color: cs.onSurface.withValues(alpha: 0.4),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              isActive ? Icons.circle : Icons.check_circle,
                              size: 12,
                              color: isActive ? AppTheme.danger : AppTheme.success,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isActive ? 'Active' : 'Cancelled',
                              style: TextStyle(
                                color: isActive ? AppTheme.danger : AppTheme.success,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Map preview
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GestureDetector(
              onTap: _openOnLiveMap,
              child: Container(
                height: 220,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: cs.outline.withValues(alpha: 0.25),
                    width: 0.5,
                  ),
                ),
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: LatLng(
                          alert.latitude,
                          alert.longitude,
                        ),
                        initialZoom: 16.0,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.none,
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.guardiancircle.app',
                          maxZoom: 19,
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(
                                alert.latitude,
                                alert.longitude,
                              ),
                              width: 48,
                              height: 62,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? AppTheme.danger
                                          : cs.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 3,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: (isActive
                                                  ? AppTheme.danger
                                                  : cs.primary)
                                              .withValues(alpha: 0.5),
                                          blurRadius: 12,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.person,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF151D30),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      _alertData!.senderName.split(' ').first,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    // Tap overlay
                    Positioned.fill(
                      child: Container(
                        color: Colors.transparent,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.open_in_new,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'Open on Live Map',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
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
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Coordinates info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.surface.withValues(alpha: isDark ? 0.45 : 0.65),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: cs.outline.withValues(alpha: 0.25),
                  width: 0.5,
                ),
              ),
              child: Column(
                children: [
                  _buildInfoRow(
                    icon: Icons.location_on_rounded,
                    label: 'Latitude',
                    value: alert.latitude.toStringAsFixed(6),
                    cs: cs,
                  ),
                  const SizedBox(height: 10),
                  _buildInfoRow(
                    icon: Icons.location_on_rounded,
                    label: 'Longitude',
                    value: alert.longitude.toStringAsFixed(6),
                    cs: cs,
                  ),
                  const SizedBox(height: 10),
                  _buildInfoRow(
                    icon: Icons.access_time_rounded,
                    label: 'Started',
                    value: _formatDateTime(alert.createdAt),
                    cs: cs,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required ColorScheme cs,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: cs.onSurface.withValues(alpha: 0.35)),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.4),
            fontSize: 13,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    return '$month/$day $h:$m';
  }
}
