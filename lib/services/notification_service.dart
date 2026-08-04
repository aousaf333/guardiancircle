import 'package:firebase_messaging/firebase_messaging.dart';
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