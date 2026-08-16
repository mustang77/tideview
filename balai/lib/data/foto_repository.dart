import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../core/config.dart';

/// Mengambil foto dari kamera/galeri lalu mengunggahnya ke Firebase Storage.
class FotoRepository {
  const FotoRepository._();

  static final ImagePicker _pemilih = ImagePicker();
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Memilih satu foto. Pengecilan dilakukan oleh image_picker saat memilih,
  /// bukan setelahnya, supaya berkas 12 MP tidak pernah sempat masuk memori.
  static Future<File?> pilih({required bool dariKamera}) async {
    final berkas = await _pemilih.pickImage(
      source: dariKamera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: BalaiConfig.maksSisiFoto,
      maxHeight: BalaiConfig.maksSisiFoto,
      imageQuality: BalaiConfig.mutuFoto,
    );
    if (berkas == null) return null;
    return File(berkas.path);
  }

  /// Mengunggah foto kiriman, mengembalikan URL untuk disimpan di Firestore.
  static Future<String> unggahKiriman(File berkas, String uid) {
    final nama = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    return _unggah(berkas, 'kiriman/$uid/$nama');
  }

  /// Mengunggah foto profil. Namanya tetap sama supaya foto lama tertimpa
  /// dan penyimpanan tidak menumpuk foto profil yang sudah tidak dipakai.
  static Future<String> unggahProfil(File berkas, String uid) {
    return _unggah(berkas, 'profil/$uid.jpg');
  }

  static Future<String> _unggah(File berkas, String jalur) async {
    final rujukan = _storage.ref().child(jalur);
    await rujukan.putFile(
      berkas,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return rujukan.getDownloadURL();
  }

  /// Menghapus foto lewat URL unduhannya. Dipakai saat kiriman dihapus.
  /// Kegagalan diabaikan: foto yang sudah tidak ada bukan alasan untuk
  /// membatalkan penghapusan kiriman.
  static Future<void> hapusLewatUrl(String url) async {
    if (url.isEmpty) return;
    try {
      await _storage.refFromURL(url).delete();
    } catch (_) {
      // Sengaja dibiarkan.
    }
  }
}
