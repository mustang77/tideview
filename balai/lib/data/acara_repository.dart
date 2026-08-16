import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/config.dart';
import '../models/acara.dart';
import '../models/warga.dart';
import 'auth_repository.dart';

/// Agenda desa: gotong royong, posyandu, rapat warga, hajatan.
class AcaraRepository {
  const AcaraRepository._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _events =>
      _db.collection(BalaiConfig.colEvents);

  /// Acara yang belum lewat, dari yang paling dekat.
  ///
  /// Penyaringan acara lampau dilakukan di aplikasi supaya daftarnya ikut
  /// bersih sendiri saat hari berganti, tanpa perlu menulis ulang pertanyaan
  /// ke Firestore setiap tengah malam.
  static Stream<List<Acara>> mendatang() {
    return _events.orderBy('mulai').snapshots().map((snap) {
      final batas = DateTime.now().millisecondsSinceEpoch;
      return snap.docs
          .map((d) => Acara.dariMap(d.id, d.data()))
          .where((a) => a.mulai >= batas)
          .toList();
    });
  }

  /// Acara yang sudah lewat, terbaru lebih dulu. Berguna untuk melihat
  /// kapan terakhir kali gotong royong diadakan.
  static Stream<List<Acara>> sudahLewat() {
    return _events.orderBy('mulai', descending: true).snapshots().map((snap) {
      final batas = DateTime.now().millisecondsSinceEpoch;
      return snap.docs
          .map((d) => Acara.dariMap(d.id, d.data()))
          .where((a) => a.mulai < batas)
          .toList();
    });
  }

  static Future<void> buat({
    required Warga pembuat,
    required String judul,
    required String keterangan,
    required String tempat,
    required DateTime mulai,
  }) async {
    await AuthRepository.pastikanBolehMenulis();
    if (judul.trim().isEmpty) return;

    await _events.add(
      Acara(
        id: '',
        judul: judul.trim(),
        keterangan: keterangan.trim(),
        tempat: tempat.trim(),
        mulai: mulai.millisecondsSinceEpoch,
        pembuatUid: pembuat.uid,
        pembuatNama: pembuat.nama,
        dibuat: DateTime.now().millisecondsSinceEpoch,
      ).keMap(),
    );
  }

  static Future<void> hapus(String acaraId) => _events.doc(acaraId).delete();

  /// Apakah warga yang sedang masuk menyatakan ikut.
  static Stream<bool> sayaIkut(String acaraId) {
    final id = AuthRepository.uid;
    if (id == null) return Stream<bool>.value(false);
    return _events
        .doc(acaraId)
        .collection(BalaiConfig.colRsvps)
        .doc(id)
        .snapshots()
        .map((d) => d.exists);
  }

  /// Nama-nama warga yang ikut. Di desa, siapa yang datang sama pentingnya
  /// dengan berapa yang datang - orang mengecek apakah tetangganya ikut.
  static Stream<List<String>> namaYangIkut(String acaraId) {
    return _events
        .doc(acaraId)
        .collection(BalaiConfig.colRsvps)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => d.data()['nama'] as String? ?? '')
            .where((n) => n.isNotEmpty)
            .toList());
  }

  /// Menyatakan ikut atau membatalkannya. Satu transaksi, dengan alasan
  /// yang sama seperti tombol suka di beranda.
  static Future<void> ubahIkut(String acaraId, Warga warga) async {
    final acara = _events.doc(acaraId);
    final ikut = acara.collection(BalaiConfig.colRsvps).doc(warga.uid);

    await _db.runTransaction((tx) async {
      final adaIkut = await tx.get(ikut);
      final docAcara = await tx.get(acara);
      if (!docAcara.exists) return;

      final sekarang = (docAcara.data()?['jumlahIkut'] as num? ?? 0).toInt();

      if (adaIkut.exists) {
        tx.delete(ikut);
        tx.update(acara, <String, dynamic>{
          'jumlahIkut': sekarang > 0 ? sekarang - 1 : 0,
        });
      } else {
        tx.set(ikut, <String, dynamic>{
          'nama': warga.nama,
          'dibuat': DateTime.now().millisecondsSinceEpoch,
        });
        tx.update(acara, <String, dynamic>{'jumlahIkut': sekarang + 1});
      }
    });
  }
}
