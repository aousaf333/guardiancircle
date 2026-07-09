import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:guardiancircle/features/auth/presentation/screens/login_screen.dart';
import 'package:guardiancircle/features/auth/presentation/screens/signup_screen.dart';
import 'package:guardiancircle/features/home/presentation/screens/home_screen.dart';
import 'package:guardiancircle/features/splash/presentation/screens/splash_screen.dart';

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
    GoRoute(
      path: '/home',
      builder: (BuildContext context, GoRouterState state) {
        return const HomeScreen();
      },
    ),
  ],
);