import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:guardiancircle/app/theme_state.dart';
import 'package:guardiancircle/core/theme/app_theme.dart';
import 'package:guardiancircle/core/router/app_router.dart';
import 'package:guardiancircle/app/app_initialization.dart';
import 'package:guardiancircle/firebase_options.dart';
import 'package:guardiancircle/services/background_location_service.dart';
import 'package:guardiancircle/services/emergency_alert_service.dart';
import 'package:guardiancircle/services/local_storage_service.dart';
import 'package:guardiancircle/services/notification_service.dart';
import 'package:guardiancircle/services/offline_location_sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Supabase FIRST
  await initializeSupabase();

  // Initialize Notifications AFTER Supabase
  await NotificationService.initialize();

  // Initialize Hive local storage for offline support
  await LocalStorageService.instance.initialize();

  // Start automatic offline SOS synchronization
  await EmergencyAlertService.startOfflineSync();

  // Start automatic offline location synchronization
  await OfflineLocationSyncService.startOfflineSync();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFF0A0F1E),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      BackgroundLocationService.resumeTracking();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, mode, _) {
        return MaterialApp.router(
          title: 'GuardianCircle',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: mode,
          routerConfig: appRouter,
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}