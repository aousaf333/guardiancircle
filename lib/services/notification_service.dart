import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static Future<void> initialize() async {
    // Request notification permission
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    print('Notification permission: ${settings.authorizationStatus}');

    // Get FCM token
    String? token = await _messaging.getToken();

    print('FCM Token: $token');

    // Listen for token refresh
    _messaging.onTokenRefresh.listen((newToken) {
      print('New FCM Token: $newToken');
    });
  }
}