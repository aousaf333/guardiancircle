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
import 'package:guardiancircle/core/widgets/bottom_nav_shell.dart';

final GoRouter appRouter = GoRouter(
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) {
        return const SplashScreen();
      },
    ),
    GoRoute(
      path: '/login',
      builder: (BuildContext context, GoRouterState state) {
        return const LoginScreen();
      },
    ),
    GoRoute(
      path: '/signup',
      builder: (BuildContext context, GoRouterState state) {
        return const SignupScreen();
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
      builder: (BuildContext context, GoRouterState state) {
        return const ProfileScreen();
      },
    ),
    GoRoute(
      path: '/sos',
      builder: (BuildContext context, GoRouterState state) {
        return const SosScreen();
      },
    ),
  ],
);
