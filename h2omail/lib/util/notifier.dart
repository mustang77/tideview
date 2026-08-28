import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Local notifications for new mail (Android; no-op on web).
class Notifier {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static Future<void> init() async {
    if (kIsWeb || _ready) return;
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      await _plugin.initialize(
          const InitializationSettings(android: android));
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      _ready = true;
    } catch (_) {
      // Platform without support: stay silent, app works without notifications.
    }
  }

  static Future<void> newMail({
    required String from,
    required String subject,
    required int count,
  }) async {
    if (kIsWeb || !_ready) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'new_mail',
        'Email Baru',
        channelDescription: 'Notifikasi email masuk',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    try {
      await _plugin.show(
        1,
        count > 1 ? '$count email baru' : from,
        count > 1 ? 'Terbaru: $subject' : subject,
        details,
      );
    } catch (_) {}
  }
}
