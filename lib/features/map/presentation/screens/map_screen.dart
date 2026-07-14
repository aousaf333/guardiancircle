import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;
  late final AnimationController _sheetAnimController;
  late final Animation<Offset> _sheetSlideAnim;
  late final AnimationController _markerAnimController;

  final _familyMembers = const [
    _FamilyMember(
      name: 'Sarah',
      role: 'Mom',
      color: Color(0xFFEC4899),
      offsetX: 0.35,
      offsetY: 0.22,
      status: 'At home',
      isOnline: true,
      lastSeen: 'Just now',
    ),
    _FamilyMember(
      name: 'James',
      role: 'Dad',
      color: Color(0xFF3B82F6),
      offsetX: 0.62,
      offsetY: 0.35,
      status: 'At work',
      isOnline: true,
      lastSeen: '5m ago',
    ),
    _FamilyMember(
      name: 'Emma',
      role: 'Sister',
      color: Color(0xFF8B5CF6),
      offsetX: 0.20,
      offsetY: 0.55,
      status: 'At school',
      isOnline: false,
      lastSeen: '1h ago',
    ),
    _FamilyMember(
      name: 'You',
      role: 'Me',
      color: Color(0xFF10B981),
      offsetX: 0.50,
      offsetY: 0.45,
      status: 'Downtown',
      isOnline: true,
      lastSeen: 'Just now',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: false);
    _pulseAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );
    _sheetAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _sheetSlideAnim = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _sheetAnimController,
        curve: Curves.easeOutCubic,
      ),
    );
    _markerAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _sheetAnimController.forward();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _sheetAnimController.dispose();
    _markerAnimController.dispose();
    super.dispose();
  }

  void _locateMe() {
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // ── Fake Map Background ──
          Positioned.fill(
            child: _FakeMapBackground(isDark: isDark),
          ),

          // ── Family Markers ──
          ..._buildFamilyMarkers(),

          // ── Current Location Marker ──
          _buildCurrentLocationMarker(),

          // ── Top status bar ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildTopBar(theme, colorScheme, isDark),
          ),

          // ── Family count badge ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 60,
            left: 16,
            child: _buildFamilyBadge(theme, colorScheme, isDark),
          ),

          // ── Locate Me FAB ──
          Positioned(
            right: 16,
            bottom: 280,
            child: _buildLocateMeFab(colorScheme, isDark),
          ),

          // ── Bottom Sheet ──
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomSheet(theme, colorScheme, isDark),
          ),
        ],
      ),
    );
  }

  // ─── Markers ─────────────────────────────────────────────────────────────

  Widget _buildCurrentLocationMarker() {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (context, _) {
        final size = MediaQuery.of(context).size;
        final cx = size.width * 0.50;
        final cy = size.height * 0.45;
        final pulseRadius = 20.0 + 20.0 * _pulseAnim.value;
        final pulseOpacity = (1.0 - _pulseAnim.value) * 0.35;
        return Positioned(
          left: cx - 30,
          top: cy - 30,
          child: SizedBox(
            width: 60,
            height: 60,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer pulse ring
                Container(
                  width: pulseRadius * 2,
                  height: pulseRadius * 2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF10B981).withValues(alpha:pulseOpacity),
                  ),
                ),
                // Static glow
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF10B981).withValues(alpha:0.2),
                  ),
                ),
                // Core dot
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF10B981),
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withValues(alpha:0.5),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                // Label
                Positioned(
                  top: 36,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF151D30),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha:0.3),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: const Text(
                      'You',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildFamilyMarkers() {
    final size = MediaQuery.of(context).size;
    final markers = <Widget>[];
    for (final m in _familyMembers) {
      if (m.name == 'You') continue;
      final mx = size.width * m.offsetX;
      final my = size.height * m.offsetY;
      markers.add(
        Positioned(
          left: mx - 22,
          top: my - 22,
          child: FadeTransition(
            opacity: _markerAnimController,
            child: ScaleTransition(
              scale: CurvedAnimation(
                parent: _markerAnimController,
                curve: Curves.elasticOut,
              ),
              child: SizedBox(
                width: 44,
                height: 52,
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    // Glow
                    Positioned(
                      top: 10,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: m.color.withValues(alpha:0.15),
                        ),
                      ),
                    ),
                    // Pin
                    Positioned(
                      top: 0,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [m.color, m.color.withValues(alpha:0.7)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: m.color.withValues(alpha:0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            m.name.characters.first,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Arrow tail
                    Positioned(
                      top: 36,
                      child: CustomPaint(
                        size: const Size(12, 8),
                        painter: _PinTailPainter(color: m.color),
                      ),
                    ),
                    // Online dot
                    Positioned(
                      top: 2,
                      right: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: m.isOnline
                              ? const Color(0xFF10B981)
                              : Colors.grey,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                    // Name label
                    Positioned(
                      top: 44,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF151D30).withValues(alpha:0.9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          m.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
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
    return markers;
  }

  // ─── Top Bar ──────────────────────────────────────────────────────────────

  Widget _buildTopBar(ThemeData theme, ColorScheme colorScheme, bool isDark) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha:0.06)
                    : Colors.white.withValues(alpha:0.82),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha:0.08)
                      : Colors.black.withValues(alpha:0.06),
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha:isDark ? 0.3 : 0.06),
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
                          ? Colors.white.withValues(alpha:0.08)
                          : Colors.black.withValues(alpha:0.04),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: colorScheme.onSurface.withValues(alpha:0.7),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'GuardianCircle',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          'Tracking 4 family members',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha:0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha:
                        isDark ? 0.15 : 0.1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.fullscreen_rounded,
                      size: 20,
                      color: colorScheme.primary,
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

  // ─── Family Count Badge ───────────────────────────────────────────────────

  Widget _buildFamilyBadge(
    ThemeData theme,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    final onlineCount = _familyMembers.where((m) => m.isOnline).length;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha:0.08)
                : Colors.white.withValues(alpha:0.85),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha:0.1)
                  : Colors.black.withValues(alpha:0.06),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: colorScheme.secondary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.secondary.withValues(alpha:0.5),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$onlineCount/${_familyMembers.length} online',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Locate Me FAB ────────────────────────────────────────────────────────

  Widget _buildLocateMeFab(ColorScheme colorScheme, bool isDark) {
    return GestureDetector(
      onTap: _locateMe,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colorScheme.primary,
              colorScheme.primary.withValues(alpha:0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withValues(alpha:0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha:isDark ? 0.4 : 0.1),
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

  // ─── Bottom Sheet ─────────────────────────────────────────────────────────

  Widget _buildBottomSheet(
    ThemeData theme,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    return SlideTransition(
      position: _sheetSlideAnim,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.38,
            ),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF151D30).withValues(alpha:0.88)
                  : Colors.white.withValues(alpha:0.92),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha:0.08)
                    : Colors.black.withValues(alpha:0.06),
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha:isDark ? 0.4 : 0.1),
                  blurRadius: 40,
                  offset: const Offset(0, -10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha:0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Text(
                        'Family Members',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.secondary.withValues(alpha:
                            isDark ? 0.15 : 0.1,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_familyMembers.where((m) => m.isOnline).length} online',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.secondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _familyMembers.length,
                    itemBuilder: (context, index) {
                      return _buildMemberTile(
                        _familyMembers[index],
                        theme,
                        colorScheme,
                        isDark,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMemberTile(
    _FamilyMember member,
    ThemeData theme,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha:0.04)
              : Colors.black.withValues(alpha:0.02),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha:0.05)
                : Colors.black.withValues(alpha:0.03),
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [member.color, member.color.withValues(alpha:0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: member.color.withValues(alpha:0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  member.name.characters.first,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        member.name,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        member.role,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha:0.4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    member.status,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha:0.5),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: member.isOnline
                            ? colorScheme.secondary
                            : colorScheme.onSurface.withValues(alpha:0.2),
                        shape: BoxShape.circle,
                        boxShadow: member.isOnline
                            ? [
                                BoxShadow(
                                  color: colorScheme.secondary.withValues(alpha:0.5),
                                  blurRadius: 4,
                                ),
                              ]
                            : null,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      member.lastSeen,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha:0.4),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Icon(
                  Icons.navigation_rounded,
                  size: 18,
                  color: colorScheme.primary.withValues(alpha:0.6),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Fake Map Background ──────────────────────────────────────────────────

class _FakeMapBackground extends StatelessWidget {
  final bool isDark;

  const _FakeMapBackground({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _MapPainter(isDark: isDark),
      size: Size.infinite,
    );
  }
}

class _MapPainter extends CustomPainter {
  final bool isDark;

  _MapPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    // ── Base gradient ──
    final bgPaint = Paint()
      ..shader = LinearGradient(
        colors: isDark
            ? [const Color(0xFF0B0F19), const Color(0xFF111827)]
            : [const Color(0xFFE8EEF5), const Color(0xFFD4DDE8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // ── Grid ──
    final gridPaint = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha:0.04)
          : Colors.black.withValues(alpha:0.06)
      ..strokeWidth = 0.5;
    const gridSpacing = 32.0;
    for (double x = 0; x < size.width; x += gridSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += gridSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // ── Roads ──
    final roadPaint = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha:0.06)
          : Colors.black.withValues(alpha:0.07)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    // Horizontal roads
    canvas.drawLine(
      Offset(0, size.height * 0.30),
      Offset(size.width, size.height * 0.30),
      roadPaint,
    );
    canvas.drawLine(
      Offset(0, size.height * 0.55),
      Offset(size.width, size.height * 0.55),
      roadPaint,
    );
    canvas.drawLine(
      Offset(0, size.height * 0.78),
      Offset(size.width, size.height * 0.78),
      roadPaint,
    );

    // Vertical roads
    canvas.drawLine(
      Offset(size.width * 0.25, 0),
      Offset(size.width * 0.25, size.height),
      roadPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.50, 0),
      Offset(size.width * 0.50, size.height),
      roadPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.75, 0),
      Offset(size.width * 0.75, size.height),
      roadPaint,
    );

    // ── Diagonal road ──
    final diagRoad = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha:0.04)
          : Colors.black.withValues(alpha:0.05)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(0, size.height * 0.15),
      Offset(size.width * 0.60, size.height),
      diagRoad,
    );

    // ── Block fills (city blocks) ──
    final blockPaint = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha:0.02)
          : Colors.black.withValues(alpha:0.03);

    final rng = Random(42);
    for (int i = 0; i < 12; i++) {
      final bx = rng.nextDouble() * size.width;
      final by = rng.nextDouble() * size.height;
      final bw = 20.0 + rng.nextDouble() * 40.0;
      final bh = 20.0 + rng.nextDouble() * 40.0;
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(bx, by), width: bw, height: bh),
        const Radius.circular(4),
      );
      canvas.drawRRect(rect, blockPaint);
    }

    // ── Landmark dots ──
    final dotPaint = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha:0.08)
          : Colors.black.withValues(alpha:0.08);
    final dotPositions = [
      Offset(size.width * 0.15, size.height * 0.20),
      Offset(size.width * 0.70, size.height * 0.15),
      Offset(size.width * 0.85, size.height * 0.45),
      Offset(size.width * 0.30, size.height * 0.70),
      Offset(size.width * 0.65, size.height * 0.65),
      Offset(size.width * 0.10, size.height * 0.85),
    ];
    for (final p in dotPositions) {
      canvas.drawCircle(p, 3, dotPaint);
    }

    // ── Subtle vignette ──
    final vignettePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          Colors.black.withValues(alpha:isDark ? 0.3 : 0.08),
        ],
        stops: const [0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), vignettePaint);
  }

  @override
  bool shouldRepaint(covariant _MapPainter old) => old.isDark != isDark;
}

// ─── Pin Tail ─────────────────────────────────────────────────────────────

class _PinTailPainter extends CustomPainter {
  final Color color;

  _PinTailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ─── Zoom Button ──────────────────────────────────────────────────────────


// ─── Data ─────────────────────────────────────────────────────────────────

class _FamilyMember {
  final String name;
  final String role;
  final Color color;
  final double offsetX;
  final double offsetY;
  final String status;
  final bool isOnline;
  final String lastSeen;

  const _FamilyMember({
    required this.name,
    required this.role,
    required this.color,
    required this.offsetX,
    required this.offsetY,
    required this.status,
    required this.isOnline,
    required this.lastSeen,
  });
}
