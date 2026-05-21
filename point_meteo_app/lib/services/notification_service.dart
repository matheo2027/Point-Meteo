import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM background: ${message.notification?.title}');
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static String? _fcmToken;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'point_meteo_alerts',
    'Alertes Météo',
    description: 'Notifications des alertes météorologiques',
    importance: Importance.high,
  );

  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

      if (!kIsWeb) {
        await _initLocalNotifications();
      }

      await _requestPermissions();
      await _loadFcmToken();
      _setupForegroundHandler();

      _initialized = true;
    } catch (e) {
      debugPrint('NotificationService init error: $e');
    }
  }

  static Future<void> _initLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(settings);

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static Future<void> _requestPermissions() async {
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  static Future<void> _loadFcmToken() async {
    try {
      _fcmToken = await FirebaseMessaging.instance.getToken();
      debugPrint('FCM Token: $_fcmToken');

      FirebaseMessaging.instance.onTokenRefresh.listen((token) {
        _fcmToken = token;
      });
    } catch (e) {
      debugPrint('FCM token error: $e');
    }
  }

  static void _setupForegroundHandler() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification == null) return;

      if (kIsWeb) {
        // Sur le web, Firebase affiche les notifications nativement
        debugPrint('FCM foreground (web): ${notification.title}');
        return;
      }

      _localNotifications.show(
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
            icon: '@mipmap/launcher_icon',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
    });
  }

  static String? get fcmToken => _fcmToken;
}
