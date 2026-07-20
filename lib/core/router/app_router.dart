import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:guardiancircle/features/auth/presentation/screens/login_screen.dart';
import 'package:guardiancircle/features/auth/presentation/screens/signup_screen.dart';
import 'package:guardiancircle/features/home/presentation/screens/home_screen.dart';
import 'package:guardiancircle/features/family/presentation/screens/family_screen.dart';
import 'package:guardiancircle/features/history/presentation/screens/history_screen.dart';
import 'package:guardiancircle/features/settings/presentation/screens/settings_screen.dart';
import 'package:guardiancircle/features/splash/presentation/screens/splash_screen.dart';
import 'package:guardiancircle/features/profile/presentation/screens/profile_screen.dart';
import 'package:guardiancircle/features/sos/presentation/screens/sos_screen.dart';
import 'package:guardiancircle/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:guardiancircle/features/home/presentation/screens/location_details_screen.dart';
import 'package:guardiancircle/features/family/presentation/screens/member_details_screen.dart';
import 'package:guardiancircle/features/notifications/presentation/screens/notification_details_screen.dart';
import 'package:guardiancircle/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:guardiancircle/features/settings/presentation/screens/emergency_contacts_screen.dart';
import 'package:guardiancircle/features/map/presentation/screens/map_screen.dart';
import 'package:guardiancircle/features/location_history/presentation/screens/location_history_screen.dart';
import 'package:guardiancircle/features/sos/presentation/screens/sos_alert_detail_screen.dart';
import 'package:guardiancircle/core/widgets/bottom_nav_shell.dart';
import 'package:guardiancircle/services/supabase_service.dart';

CustomTransitionPage<void> _buildFadePage(Widget child, {LocalKey? key}) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 350),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.03, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

CustomTransitionPage<void> _buildSlideUpPage(Widget child, {LocalKey? key}) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 400),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(curved),
        child: FadeTransition(
          opacity: curved,
          child: child,
        ),
      );
    },
  );
}

CustomTransitionPage<void> _buildSlideRightPage(
  Widget child, {
  LocalKey? key,
}) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 400),
    reverseTransitionDuration: const Duration(milliseconds: 350),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      final reverseCurved = CurvedAnimation(
        parent: secondaryAnimation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.3, 0),
          end: Offset.zero,
        ).animate(curved),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: Offset.zero,
            end: const Offset(-0.15, 0),
          ).animate(reverseCurved),
          child: FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
            ),
            child: child,
          ),
        ),
      );
    },
  );
}

CustomTransitionPage<void> _buildScalePage(Widget child, {LocalKey? key}) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 400),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return ScaleTransition(
        scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
        child: FadeTransition(
          opacity: curved,
          child: child,
        ),
      );
    },
  );
}

final GoRouter appRouter = GoRouter(
  redirect: (BuildContext context, GoRouterState state) {
    final isLoggedIn = SupabaseService.client.auth.currentUser != null;
    final isAuthRoute = state.matchedLocation == '/login' ||
        state.matchedLocation == '/signup' ||
        state.matchedLocation == '/';
    final isProtectedRoute = !isAuthRoute;

    if (!isLoggedIn && isProtectedRoute) {
      return '/login';
    }
    if (isLoggedIn && state.matchedLocation == '/login') {
      return '/home';
    }
    return null;
  },
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      pageBuilder: (BuildContext context, GoRouterState state) {
        return _buildFadePage(const SplashScreen(), key: state.pageKey);
      },
    ),
    GoRoute(
      path: '/login',
      pageBuilder: (BuildContext context, GoRouterState state) {
        return _buildSlideUpPage(const LoginScreen(), key: state.pageKey);
      },
    ),
    GoRoute(
      path: '/signup',
      pageBuilder: (BuildContext context, GoRouterState state) {
        return _buildSlideUpPage(const SignupScreen(), key: state.pageKey);
      },
    ),
    StatefulShellRoute.indexedStack(
      builder: (
        BuildContext context,
        GoRouterState state,
        StatefulNavigationShell navigationShell,
      ) {
        return BottomNavShell(navigationShell: navigationShell);
      },
      branches: <StatefulShellBranch>[
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: '/home',
              builder: (BuildContext context, GoRouterState state) {
                return const HomeScreen();
              },
            ),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: '/map',
              builder: (BuildContext context, GoRouterState state) {
                return const MapScreen();
              },
            ),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: '/notifications',
              builder: (BuildContext context, GoRouterState state) {
                return const NotificationsScreen();
              },
            ),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: '/family',
              builder: (BuildContext context, GoRouterState state) {
                return const FamilyScreen();
              },
            ),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: '/history',
              builder: (BuildContext context, GoRouterState state) {
                return const HistoryScreen();
              },
            ),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: '/settings',
              builder: (BuildContext context, GoRouterState state) {
                return const SettingsScreen();
              },
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/profile',
      pageBuilder: (BuildContext context, GoRouterState state) {
        return _buildSlideRightPage(const ProfileScreen(), key: state.pageKey);
      },
    ),
    GoRoute(
      path: '/sos',
      pageBuilder: (BuildContext context, GoRouterState state) {
        return _buildScalePage(const SosScreen(), key: state.pageKey);
      },
    ),
    GoRoute(
      path: '/location-details',
      pageBuilder: (BuildContext context, GoRouterState state) {
        return _buildSlideRightPage(
          const LocationDetailsScreen(),
          key: state.pageKey,
        );
      },
    ),
    GoRoute(
      path: '/member-details',
      pageBuilder: (BuildContext context, GoRouterState state) {
        final args = state.extra as Map<String, dynamic>? ?? {};
        return _buildSlideRightPage(
          MemberDetailsScreen(
            name: args['name'] as String? ?? 'Unknown',
            role: args['role'] as String? ?? 'Member',
            color: args['color'] as Color? ?? Colors.blue,
            isOnline: args['isOnline'] as bool? ?? false,
            battery: args['battery'] as int? ?? 0,
            distance: args['distance'] as String? ?? '—',
          ),
          key: state.pageKey,
        );
      },
    ),
    GoRoute(
      path: '/notification-details',
      pageBuilder: (BuildContext context, GoRouterState state) {
        final args = state.extra as Map<String, dynamic>? ?? {};
        return _buildSlideRightPage(
          NotificationDetailsScreen(
            icon: args['icon'] as IconData? ?? Icons.info_outline,
            color: args['color'] as Color? ?? Colors.blue,
            title: args['title'] as String? ?? '',
            subtitle: args['subtitle'] as String? ?? '',
            time: args['time'] as String? ?? '',
            type: args['type'] as String? ?? 'info',
          ),
          key: state.pageKey,
        );
      },
    ),
    GoRoute(
      path: '/edit-profile',
      pageBuilder: (BuildContext context, GoRouterState state) {
        final args = state.extra as Map<String, dynamic>? ?? {};
        return _buildSlideRightPage(
          EditProfileScreen(
            currentName: args['name'] as String? ?? '',
            currentPhone: args['phone'] as String? ?? '',
            currentEmail: args['email'] as String? ?? '',
            currentEmergency: args['emergency'] as String? ?? '',
          ),
          key: state.pageKey,
        );
      },
    ),
    GoRoute(
      path: '/emergency-contacts',
      pageBuilder: (BuildContext context, GoRouterState state) {
        return _buildSlideRightPage(
          const EmergencyContactsScreen(),
          key: state.pageKey,
        );
      },
    ),
    GoRoute(
      path: '/location-history',
      pageBuilder: (BuildContext context, GoRouterState state) {
        return _buildSlideRightPage(
          const LocationHistoryScreen(),
          key: state.pageKey,
        );
      },
    ),
    GoRoute(
      path: '/sos-alert-detail/:alertId',
      pageBuilder: (BuildContext context, GoRouterState state) {
        final alertId = state.pathParameters['alertId']!;
        return _buildSlideRightPage(
          SosAlertDetailScreen(alertId: alertId),
          key: state.pageKey,
        );
      },
    ),

  ],
);
