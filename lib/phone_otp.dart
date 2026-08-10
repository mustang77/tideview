import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'firebase_options.dart';

/// Verifikasi nomor HP lewat SMS OTP (Firebase Phone Auth).
///
/// OTP hanya diminta sekali, saat pendaftaran akun — masuk harian tetap
/// cukup nomor HP + PIN sehingga tidak ada biaya SMS berulang. Setelah
/// kode benar, idToken Firebase dikirim ke server sebagai bukti bahwa
/// pendaftar benar-benar memegang nomor tersebut.
class PhoneOtp {
  /// true bila Firebase siap dipakai di platform ini. Web masih false
  /// sampai app Web didaftarkan di Firebase Console (lihat
  /// firebase_options.dart) — pendaftaran web sementara tanpa OTP.
  static bool available = false;

  static Future<void> init() async {
    if (kIsWeb) return;
    try {
      await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform);
      available = true;
    } catch (_) {
      available = false;
    }
  }

  /// Kirim SMS kode ke [phone62] (format 62xxxx, tanpa tanda +).
  ///
  /// [onCode] dipanggil saat SMS terkirim (lanjut ke input kode);
  /// [onAuto] bila Android membaca SMS otomatis (langsung dapat token);
  /// [onError] bila pengiriman gagal.
  static Future<void> sendCode(
    String phone62, {
    required void Function(String verificationId) onCode,
    required void Function(String idToken) onAuto,
    required void Function(String message) onError,
  }) async {
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: '+$phone62',
        timeout: const Duration(seconds: 60),
        verificationCompleted: (credential) async {
          final token = await _signIn(credential);
          if (token != null) onAuto(token);
        },
        verificationFailed: (e) => onError(_message(e)),
        codeSent: (verificationId, _) => onCode(verificationId),
        codeAutoRetrievalTimeout: (_) {},
      );
    } on FirebaseAuthException catch (e) {
      onError(_message(e));
    } catch (_) {
      onError('Gagal mengirim SMS verifikasi. Coba lagi.');
    }
  }

  /// Cocokkan kode 6 digit yang diketik pengguna. Mengembalikan
  /// idToken bila benar, null bila salah/kedaluwarsa.
  static Future<String?> confirmCode(
      String verificationId, String smsCode) async {
    try {
      final credential = PhoneAuthProvider.credential(
          verificationId: verificationId, smsCode: smsCode);
      return await _signIn(credential);
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _signIn(PhoneAuthCredential credential) async {
    final user =
        (await FirebaseAuth.instance.signInWithCredential(credential)).user;
    final token = await user?.getIdToken();
    // Sesi Firebase tidak dipakai setelah token diteruskan ke server;
    // akun harian tetap nomor HP + PIN.
    await FirebaseAuth.instance.signOut();
    return token;
  }

  static String _message(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'Nomor HP tidak valid.';
      case 'too-many-requests':
        return 'Terlalu banyak percobaan. Coba lagi beberapa saat.';
      case 'quota-exceeded':
        return 'Kuota SMS sedang habis. Coba lagi nanti.';
      case 'network-request-failed':
        return 'Tidak ada koneksi internet.';
      default:
        return 'Verifikasi gagal (${e.code}). Coba lagi.';
    }
  }
}
