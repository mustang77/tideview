import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Menjalankan aplikasi memakai Firebase Emulator Suite di komputer sendiri,
/// bukan Firebase sungguhan.
///
/// Gunanya untuk mencoba aplikasi tanpa menyentuh data desa yang asli - warga
/// palsu, kiriman palsu, semuanya hilang saat emulator ditutup.
///
/// Nyalakan dengan:
///   firebase emulators:start --project demo-balai
///   flutter run --dart-define=EMULATOR=true
///
/// Tanpa tanda itu, tidak satu pun baris di berkas ini berjalan, jadi aplikasi
/// yang dibagikan ke warga tidak mungkin nyasar ke emulator.
class Emulator {
  const Emulator._();

  static const bool aktif = bool.fromEnvironment('EMULATOR');

  static const String _host = String.fromEnvironment(
    'EMULATOR_HOST',
    defaultValue: 'localhost',
  );

  /// Setelan palsu untuk emulator. Proyek berawalan `demo-` sengaja dipilih:
  /// Firebase memperlakukannya sebagai proyek yang pasti tidak ada, jadi
  /// kunci palsu di bawah ini tidak mungkin menyentuh proyek orang lain.
  static const FirebaseOptions opsi = FirebaseOptions(
    apiKey: 'demo-key',
    appId: '1:0:web:0',
    messagingSenderId: '0',
    projectId: 'demo-balai',
    storageBucket: 'demo-balai.appspot.com',
  );

  static Future<void> sambungkan() async {
    await FirebaseAuth.instance.useAuthEmulator(_host, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(_host, 8080);
    await FirebaseStorage.instance.useStorageEmulator(_host, 9199);
  }
}
