import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api.dart';

// Background/terminated messages: the system shows the notification payload
// automatically, so this only needs to exist and be a top-level entry point.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {}

/// Thin wrapper around Firebase Cloud Messaging + local notifications.
/// Everything is guarded so the web build compiles and a device without Google
/// Play services simply gets no push (the app keeps working).
class Push {
  static final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

  // Must match the channel id the server sends (fcm.php) and the manifest meta.
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'paramall_orders',
    'Pesanan Paramall',
    description: 'Notifikasi status pesanan & pesanan baru',
    importance: Importance.high,
  );

  static bool _ready = false;

  static Future<void> init() async {
    if (kIsWeb) return; // No Firebase web app configured; skip cleanly.
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);

      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      await _local.initialize(const InitializationSettings(android: androidInit));
      await _local
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);

      await FirebaseMessaging.instance.requestPermission();
      // Foreground messages don't auto-display — show them ourselves.
      FirebaseMessaging.onMessage.listen(_showForeground);
      _ready = true;
    } catch (_) {
      // Firebase unavailable on this device/build — push just stays off.
    }
  }

  static void _showForeground(RemoteMessage m) {
    final n = m.notification;
    if (n == null) return;
    _local.show(
      n.hashCode,
      n.title,
      n.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }

  /// After login, hand this device's FCM token to the server so it can push
  /// order-status updates to this customer.
  static Future<void> registerDevice(String sessionToken) async {
    if (kIsWeb || !_ready || sessionToken.isEmpty) return;
    try {
      final fcm = await FirebaseMessaging.instance.getToken();
      if (fcm != null && fcm.isNotEmpty) {
        await Api.registerToken(token: sessionToken, deviceToken: fcm, platform: 'android');
      }
    } catch (_) {}
  }

  /// Staff (admin/driver) devices subscribe to 'staff' to hear about new orders.
  static Future<void> subscribeStaff() async {
    if (kIsWeb || !_ready) return;
    try {
      await FirebaseMessaging.instance.subscribeToTopic('staff');
    } catch (_) {}
  }
}
