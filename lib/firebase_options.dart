import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Konfigurasi Firebase proyek "WCA Mobile" (wca-mobile-10a8d),
/// dipakai untuk verifikasi nomor HP (OTP SMS) saat pendaftaran.
///
/// Baru Android yang terdaftar di Firebase Console; tambahkan app Web
/// di console lalu isi konfigurasi `web` di bawah bila ingin OTP di web.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
          'App Web belum didaftarkan di Firebase Console.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
            'Firebase belum dikonfigurasi untuk platform ini.');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAXjYcfTuqlDvNlO6ArQFghBPdABxKPR5E',
    appId: '1:1029538336237:android:d2e2dc37d8237d7ad92be4',
    messagingSenderId: '1029538336237',
    projectId: 'wca-mobile-10a8d',
    storageBucket: 'wca-mobile-10a8d.firebasestorage.app',
  );
}
