// ╔══════════════════════════════════════════════════════════════════╗
// ║         notification_service.dart — FCM Push Notifications       ║
// ╚══════════════════════════════════════════════════════════════════╝

import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../services/auth_service.dart';
import 'package:provider/provider.dart';

class NotificationService {
  static final _fcm = FirebaseMessaging.instance;
  static final _localNotifications = FlutterLocalNotificationsPlugin();

  // Android notification channel
  static const _channel = AndroidNotificationChannel(
    'filq_main',           // id
    'Filq Notifications',  // name
    description: 'All Filq app notifications',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  /// Call once from main widget initState
  static Future<void> init(BuildContext context) async {
    // 1. Request permission
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
    );

    debugPrint('[FCM] Permission: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('[FCM] Notifications denied by user');
      return;
    }

    // 2. Setup local notifications plugin
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        _handleNotificationTap(details.payload, context);
      },
    );

    // 3. Create Android notification channel
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // 4. Foreground messages — show local notification
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('[FCM Foreground] ${message.notification?.title}');
      _showLocalNotification(message);
    });

    // 5. App opened from background notification tap
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[FCM Opened] ${message.data}');
      _handleNotificationTap(
        message.data['type'],
        context,
        data: message.data,
      );
    });

    // 6. App launched from terminated state via notification
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('[FCM Initial] ${initialMessage.data}');
      // Small delay so app is ready
      await Future.delayed(const Duration(milliseconds: 500));
      if (context.mounted) {
        _handleNotificationTap(
          initialMessage.data['type'],
          context,
          data: initialMessage.data,
        );
      }
    }

    // 7. Get FCM token and register with backend
    await _registerToken(context);

    // 8. Token refresh listener
    _fcm.onTokenRefresh.listen((newToken) async {
      debugPrint('[FCM] Token refreshed');
      await _sendTokenToServer(newToken, context);
    });
  }

  static Future<void> _registerToken(BuildContext context) async {
    try {
      final token = await _fcm.getToken();
      if (token != null && token.isNotEmpty) {
        debugPrint('[FCM] Token: ${token.substring(0, 20)}...');
        await _sendTokenToServer(token, context);
      }
    } catch (e) {
      debugPrint('[FCM] Token error: $e');
    }
  }

  static Future<void> _sendTokenToServer(
      String token, BuildContext context) async {
    try {
      if (!context.mounted) return;
      final auth = context.read<AuthService>();
      if (!auth.isLoggedIn()) return;
      await auth.registerFCMToken(token);
      debugPrint('[FCM] Token registered with server');
    } catch (e) {
      debugPrint('[FCM] Token register error: $e');
    }
  }

  /// Re-register token after login (call from login/register success)
  static Future<void> registerAfterLogin(BuildContext context) async {
    await _registerToken(context);
  }

  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final android = message.notification?.android;
    if (notification == null) return;

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: android?.smallIcon ?? '@mipmap/ic_launcher',
          playSound: true,
          enableVibration: true,
          color: const Color(0xFF00C853),
        ),
      ),
      payload: message.data['type'] ?? '',
    );
  }

  static void _handleNotificationTap(
    String? type,
    BuildContext context, {
    Map<String, dynamic>? data,
  }) {
    if (!context.mounted) return;
    final navigator = Navigator.of(context, rootNavigator: true);

    switch (type) {
      case 'support_reply':
        navigator.pushNamed('/support');
        break;
      case 'coins_credited':
        navigator.pushNamed('/home');
        break;
      case 'withdrawal_update':
        navigator.pushNamed('/withdraw');
        break;
      default:
        navigator.pushNamed('/home');
    }
  }

  /// Get current FCM token (for debug)
  static Future<String?> getToken() => _fcm.getToken();
}
