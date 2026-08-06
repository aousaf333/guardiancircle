import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:guardiancircle/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Background Notification');
  print('Title: ${message.notification?.title}');
  print('Body: ${message.notification?.body}');
}

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static bool _localNotificationsInitialized = false;

  /// Whether non-critical app notifications are enabled. Restored from the
  /// locally persisted settings on startup. SOS critical alerts are never
  /// suppressed by this flag.
  static bool notificationsEnabled = true;

  /// Updates the notifications preference. Called by the Settings screen
  /// whenever the user toggles notifications.
  static void setNotificationsEnabled(bool enabled) {
    notificationsEnabled = enabled;
    print('[Notifications] ${enabled ? 'Enabled' : 'Disabled'}');
  }

  static Future<void> initialize() async {
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      announcement: true,
      provisional: false,
      criticalAlert: false,
    );

    print('Notification permission: ${settings.authorizationStatus}');

    FirebaseMessaging.onBackgroundMessage(
      firebaseMessagingBackgroundHandler,
    );

    final token = await _messaging.getToken();

    print('====================================');
    print('FCM TOKEN');
    print(token);
    print('====================================');

    if (token != null) {
      await _saveToken(token);
    }

    _messaging.onTokenRefresh.listen((newToken) async {
      print('====================================');
      print('NEW FCM TOKEN');
      print(newToken);
      print('====================================');

      await _saveToken(newToken);
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (!notificationsEnabled) return;
      print('Foreground Notification');
      print('Title: ${message.notification?.title}');
      print('Body: ${message.notification?.body}');
      print('Data: ${message.data}');
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Notification Clicked');
      print('Data: ${message.data}');
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      print('Opened From Terminated');
      print(initialMessage.data);
    }

    await _initLocalNotifications();
  }

  static Future<void> _initLocalNotifications() async {
    if (_localNotificationsInitialized) return;
    _localNotificationsInitialized = true;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: ios);

    await _localNotifications.initialize(settings: settings);

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// Shows a single local notification once all queued offline SOS alerts
  /// have been successfully uploaded after internet was restored.
  static Future<void> showOfflineSosSuccessNotification() async {
    if (!notificationsEnabled) return;
    if (!_localNotificationsInitialized) {
      await _initLocalNotifications();
    }

    const androidDetails = AndroidNotificationDetails(
      'offline_sos_sync_channel',
      'Offline SOS Sync',
      channelDescription: 'Notifications for offline SOS synchronization',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    try {
      await _localNotifications.show(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: 'SOS Sent',
        body:
            'Your offline SOS has been sent successfully after internet was restored.',
        notificationDetails: details,
      );
      print('[OfflineSync] Showing success notification');
    } catch (e) {
      print('[OfflineSync] Failed to show success notification: $e');
    }
  }

  // NEW PUBLIC METHOD
  static Future<void> saveTokenToSupabase() async {
    final token = await _messaging.getToken();

    if (token != null) {
      await _saveToken(token);
    }
  }

  static Future<void> _saveToken(String token) async {
    try {
      final user = SupabaseService.client.auth.currentUser;

      if (user == null) {
        print('No logged in user. FCM token not saved.');
        return;
      }

      await SupabaseService.client
          .from('profiles')
          .update({
            'fcm_token': token,
          })
          .eq('id', user.id);

      print('====================================');
      print('FCM TOKEN SAVED TO SUPABASE');
      print('User ID: ${user.id}');
      print('====================================');
    } catch (e) {
      print('Error saving FCM token: $e');
    }
  }
}