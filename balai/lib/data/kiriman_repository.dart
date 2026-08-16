import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/config.dart';
import '../models/kategori.dart';
import '../models/kiriman.dart';
import '../models/warga.dart';
import 'auth_repository.dart';
import 'foto_repository.dart';

/// Kiriman beranda: menulis, menyukai, dan berkomentar.
class KirimanRepository {
  const KirimanRepository._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _posts =>
      _db.collection(BalaiConfig.colPosts);

  // ---- Membaca -----------------------------------------------------------

  /// Beranda desa.
  ///
  /// Pengumuman kepala desa selalu di atas, sisanya urut dari yang terbaru.
  /// Pengurutan gabungan itu dilakukan di sini, bukan di Firestore, supaya
  /// tidak perlu indeks gabungan - satu hal yang bisa gagal saat pemasangan
  /// dan bikin bingung.
  static Stream<List<Kiriman>> beranda() {
    return _posts
        .orderBy('dibuat', descending: true)
        .limit(BalaiConfig.halamanBeranda)
        .snapshots()
        .map((snap) {
      final daftar =
          snap.docs.map((d) => Kiriman.dariMap(d.id, d.data())).toList();
      daftar.sort((a, b) {
        if (a.disematkan != b.disematkan) return a.disematkan ? -1 : 1;
        return b.dibuat.compareTo(a.dibuat);
      });
      return daftar;
    });
  }

  /// Kiriman satu warga, untuk halaman profilnya.
  static Stream<List<Kiriman>> milik(String wargaUid) {
    return _posts
        .where('penulisUid', isEqualTo: wargaUid)
        .snapshots()
        .map((snap) {
      final daftar =
          snap.docs.map((d) => Kiriman.dariMap(d.id, d.data())).toList();
      daftar.sort((a, b) => b.dibuat.compareTo(a.dibuat));
      return daftar;
    });
  }

  // ---- Menulis -----------------------------------------------------------

  /// Mengirim kiriman baru. [foto] boleh kosong.
  ///
  /// Foto diunggah lebih dulu; kalau unggahan gagal, kiriman tidak dibuat
  /// sama sekali - lebih baik gagal seluruhnya daripada meninggalkan kiriman
  /// yang menyebut foto yang tidak pernah sampai.
  static Future<void> kirim({
    required Warga penulis,
    required String isi,
    required Kategori kategori,
    File? foto,
    bool disematkan = false,
  }) async {
    await AuthRepository.pastikanBolehMenulis();

    final teks = isi.trim();
    if (teks.isEmpty && foto == null) return;

    var urlFoto = '';
    if (foto != null) {
      urlFoto = await FotoRepository.unggahKiriman(foto, penulis.uid);
    }

    // Hanya kepala desa yang boleh menyematkan dan memakai kategori
    // pengumuman. Aturan Firestore menegakkan hal yang sama di sisi server.
    final bolehSemat = penulis.kepalaDesa;
    final kategoriAkhir =
        (kategori == Kategori.pengumuman && !bolehSemat) ? Kategori.umum : kategori;

    final kiriman = Kiriman(
      id: '',
      penulisUid: penulis.uid,
      penulisNama: penulis.nama,
      penulisFoto: penulis.foto,
      isi: teks.length > BalaiConfig.maksHurufKiriman
          ? teks.substring(0, BalaiConfig.maksHurufKiriman)
          : teks,
      kategori: kategoriAkhir,
      foto: urlFoto,
      dibuat: DateTime.now().millisecondsSinceEpoch,
      disematkan: disematkan && bolehSemat,
    );

    await _posts.add(kiriman.keMap());
  }

  /// Menghapus kiriman beserta fotonya. Penulis atau kepala desa saja.
  static Future<void> hapus(Kiriman kiriman) async {
    await _posts.doc(kiriman.id).delete();
    await FotoRepository.hapusLewatUrl(kiriman.foto);
  }

  /// Menyematkan atau melepas kiriman dari puncak beranda.
  static Future<void> ubahSematan(String kirimanId, bool disematkan) {
    return _posts
        .doc(kirimanId)
        .update(<String, dynamic>{'disematkan': disematkan});
  }

  // ---- Suka --------------------------------------------------------------

  /// Apakah warga ini sudah menyukai kiriman tersebut.
  static Stream<bool> sudahSuka(String kirimanId) {
    final id = AuthRepository.uid;
    if (id == null) return Stream<bool>.value(false);
    return _posts
        .doc(kirimanId)
        .collection(BalaiConfig.colLikes)
        .doc(id)
        .snapshots()
        .map((d) => d.exists);
  }

  /// Menyukai atau membatalkan suka.
  ///
  /// Penanda suka dan angka penghitungnya ditulis dalam satu transaksi.
  /// Kalau dipisah, menekan tombol dua kali dengan cepat di sinyal buruk
  /// bisa membuat angkanya melenceng dari kenyataan.
  static Future<void> ubahSuka(String kirimanId) async {
    final id = AuthRepository.uid;
    if (id == null) return;

    final kiriman = _posts.doc(kirimanId);
    final suka = kiriman.collection(BalaiConfig.colLikes).doc(id);

    await _db.runTransaction((tx) async {
      final adaSuka = await tx.get(suka);
      final docKiriman = await tx.get(kiriman);
      if (!docKiriman.exists) return;

      final sekarang =
          (docKiriman.data()?['jumlahSuka'] as num? ?? 0).toInt();

      if (adaSuka.exists) {
        tx.delete(suka);
        tx.update(kiriman, <String, dynamic>{
          'jumlahSuka': sekarang > 0 ? sekarang - 1 : 0,
        });
      } else {
        tx.set(suka, <String, dynamic>{
          'dibuat': DateTime.now().millisecondsSinceEpoch,
        });
        tx.update(kiriman, <String, dynamic>{'jumlahSuka': sekarang + 1});
      }
    });
  }

  // ---- Komentar ----------------------------------------------------------

  static Stream<List<Komentar>> komentar(String kirimanId) {
    return _posts
        .doc(kirimanId)
        .collection(BalaiConfig.colComments)
        .orderBy('dibuat')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Komentar.dariMap(d.id, d.data())).toList());
  }

  static Future<void> tulisKomentar({
    required String kirimanId,
    required Warga penulis,
    required String isi,
  }) async {
    await AuthRepository.pastikanBolehMenulis();
    final teks = isi.trim();
    if (teks.isEmpty) return;

    final kiriman = _posts.doc(kirimanId);
    final komentar = kiriman.collection(BalaiConfig.colComments).doc();

    await _db.runTransaction((tx) async {
      final docKiriman = await tx.get(kiriman);
      if (!docKiriman.exists) return;
      final sekarang =
          (docKiriman.data()?['jumlahKomentar'] as num? ?? 0).toInt();

      tx.set(
        komentar,
        Komentar(
          id: komentar.id,
          penulisUid: penulis.uid,
          penulisNama: penulis.nama,
          penulisFoto: penulis.foto,
          isi: teks,
          dibuat: DateTime.now().millisecondsSinceEpoch,
        ).keMap(),
      );
      tx.update(kiriman, <String, dynamic>{'jumlahKomentar': sekarang + 1});
    });
  }

  static Future<void> hapusKomentar({
    required String kirimanId,
    required String komentarId,
  }) async {
    final kiriman = _posts.doc(kirimanId);
    final komentar =
        kiriman.collection(BalaiConfig.colComments).doc(komentarId);

    await _db.runTransaction((tx) async {
      final docKiriman = await tx.get(kiriman);
      if (!docKiriman.exists) return;
      final sekarang =
          (docKiriman.data()?['jumlahKomentar'] as num? ?? 0).toInt();

      tx.delete(komentar);
      tx.update(kiriman, <String, dynamic>{
        'jumlahKomentar': sekarang > 0 ? sekarang - 1 : 0,
      });
    });
  }
}
