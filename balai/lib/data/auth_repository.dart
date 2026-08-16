import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/config.dart';
import '../models/warga.dart';

/// Dilempar saat warga mencoba menulis padahal akunnya belum disetujui.
/// Ditulis sebagai kebijakan, bukan sebagai kesalahan sistem, karena
/// begitulah warga membacanya.
class BelumDisetujui implements Exception {
  const BelumDisetujui();

  @override
  String toString() =>
      'Akun Anda menunggu persetujuan kepala desa. Sementara ini Anda '
      'tetap bisa membaca beranda dan melihat buku warga.';
}

/// Akun warga: masuk, daftar, dan persetujuan kepala desa.
class AuthRepository {
  const AuthRepository._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static String? get uid => _auth.currentUser?.uid;
  static bool get sudahMasuk => _auth.currentUser != null;

  /// Berubah setiap kali warga masuk atau keluar. Dipakai layar gerbang
  /// untuk memilih antara layar masuk dan isi aplikasi.
  static Stream<User?> perubahanAkun() => _auth.authStateChanges();

  // ---- Masuk dan daftar --------------------------------------------------

  static Future<void> masuk(String email, String sandi) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: sandi,
    );
  }

  /// Membuat akun sekaligus profil warganya.
  ///
  /// Akun baru selalu `disetujui: false`. Kepala desa yang membukanya dari
  /// menu admin - itulah penjaga pintu desa ini.
  static Future<void> daftar({
    required String nama,
    required String email,
    required String sandi,
    required String gang,
    String telepon = '',
  }) async {
    final hasil = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: sandi,
    );
    final pengguna = hasil.user;
    if (pengguna == null) return;

    await pengguna.updateDisplayName(nama.trim());
    await _db.collection(BalaiConfig.colUsers).doc(pengguna.uid).set(
      <String, dynamic>{
        'nama': nama.trim(),
        'foto': '',
        'gang': gang,
        'alamat': '',
        'telepon': telepon.trim(),
        'keahlian': <String>[],
        'disetujui': false,
        'kepalaDesa': false,
        'bergabung': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  static Future<void> keluar() => _auth.signOut();

  static Future<void> lupaSandi(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  // ---- Profil ------------------------------------------------------------

  /// Profil warga yang sedang masuk, mengikuti perubahan.
  ///
  /// Sengaja aliran (stream), bukan sekali baca: saat kepala desa menyetujui
  /// akun, aplikasi warga langsung membuka tombol tulis tanpa perlu keluar
  /// masuk lagi.
  static Stream<Warga?> profilSaya() {
    final id = uid;
    if (id == null) return Stream<Warga?>.value(null);
    return _db
        .collection(BalaiConfig.colUsers)
        .doc(id)
        .snapshots()
        .map((d) => d.exists ? Warga.dariMap(d.id, d.data()!) : null);
  }

  static Future<Warga?> muatProfil(String wargaUid) async {
    final d = await _db.collection(BalaiConfig.colUsers).doc(wargaUid).get();
    if (!d.exists) return null;
    return Warga.dariMap(d.id, d.data()!);
  }

  /// Menyimpan bagian profil yang boleh diubah warga sendiri.
  static Future<void> simpanProfil(Warga warga) async {
    await _db
        .collection(BalaiConfig.colUsers)
        .doc(warga.uid)
        .update(warga.keMap());
  }

  /// Memastikan warga boleh menulis. Layar memanggil ini sebelum mengirim
  /// apa pun, jadi pesan penolakan muncul sekali dan jelas.
  static Future<void> pastikanBolehMenulis() async {
    final id = uid;
    if (id == null) throw const BelumDisetujui();
    final d = await _db.collection(BalaiConfig.colUsers).doc(id).get();
    if (!d.exists) throw const BelumDisetujui();
    final warga = Warga.dariMap(d.id, d.data()!);
    if (!warga.bolehMenulis) throw const BelumDisetujui();
  }

  // ---- Persetujuan kepala desa -------------------------------------------

  /// Warga yang menunggu disetujui.
  static Stream<List<Warga>> wargaMenunggu() {
    return _db
        .collection(BalaiConfig.colUsers)
        .where('disetujui', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Warga.dariMap(d.id, d.data()))
            .where((w) => !w.kepalaDesa)
            .toList());
  }

  static Future<void> setujuiWarga(String wargaUid) {
    return _db
        .collection(BalaiConfig.colUsers)
        .doc(wargaUid)
        .update(<String, dynamic>{'disetujui': true});
  }

  /// Menolak berarti menghapus profilnya. Akun masuknya sendiri masih ada
  /// di Firebase Auth; kepala desa bisa menghapusnya lewat Firebase Console
  /// kalau memang orang luar.
  static Future<void> tolakWarga(String wargaUid) {
    return _db.collection(BalaiConfig.colUsers).doc(wargaUid).delete();
  }

  /// Pesan Firebase diterjemahkan jadi kalimat yang bisa dimengerti warga.
  /// Tanpa ini, orang cuma melihat "[firebase_auth/invalid-credential]".
  static String pesanRamah(Object e) {
    if (e is BelumDisetujui) return e.toString();
    if (e is! FirebaseAuthException) {
      return 'Ada yang tidak beres. Coba lagi sebentar lagi.';
    }
    switch (e.code) {
      case 'invalid-email':
        return 'Alamat email itu sepertinya salah tulis.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email atau kata sandi tidak cocok.';
      case 'email-already-in-use':
        return 'Email ini sudah dipakai. Coba masuk saja.';
      case 'weak-password':
        return 'Kata sandi terlalu pendek. Pakai minimal 6 huruf.';
      case 'network-request-failed':
        return 'Tidak ada sambungan. Periksa sinyal, lalu coba lagi.';
      case 'too-many-requests':
        return 'Terlalu banyak percobaan. Tunggu sebentar, lalu coba lagi.';
      default:
        return 'Tidak bisa masuk sekarang. Coba lagi sebentar lagi.';
    }
  }
}
