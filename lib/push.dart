import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'api.dart';

// Background/terminated messages carrying a notification payload are shown by the
// system automatically (via the default channel in the manifest), so this only
// needs to exist as a top-level entry point.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {}

/// Thin wrapper around Firebase Cloud Messaging. Everything is guarded so the
/// web build compiles and a device without Google Play services simply gets no
/// push (the app keeps working).
class Push {
  static bool _ready = false;

  static Future<void> init() async {
    if (kIsWeb) return; // No Firebase web app configured; skip cleanly.
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
      await FirebaseMessaging.instance.requestPermission();
      _ready = true;
    } catch (_) {
      // Firebase unavailable on this device/build — push just stays off.
    }
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
