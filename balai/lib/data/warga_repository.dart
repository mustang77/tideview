import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/config.dart';
import '../models/warga.dart';

/// Buku warga: siapa saja yang ada di desa, dan siapa yang bisa dimintai
/// tolong untuk apa.
class WargaRepository {
  const WargaRepository._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Semua warga yang sudah disetujui, urut menurut nama.
  ///
  /// Desa 100-an orang muat sekali ambil, jadi pencarian dan penyaringan
  /// keahlian dikerjakan di aplikasi. Hasilnya: mengetik di kotak cari
  /// terasa seketika, dan tetap jalan walau sinyal putus setelah termuat.
  static Stream<List<Warga>> semua() {
    return _db
        .collection(BalaiConfig.colUsers)
        .where('disetujui', isEqualTo: true)
        .snapshots()
        .map((snap) {
      final daftar =
          snap.docs.map((d) => Warga.dariMap(d.id, d.data())).toList();
      daftar.sort(
          (a, b) => a.nama.toLowerCase().compareTo(b.nama.toLowerCase()));
      return daftar;
    });
  }

  /// Menyaring daftar warga menurut kata pencarian dan keahlian.
  /// Dipisah dari layar supaya bisa diuji tanpa membuka aplikasi.
  static List<Warga> saring(
    List<Warga> semua, {
    String cari = '',
    String keahlian = '',
  }) {
    return semua
        .where((w) => w.cocok(cari))
        .where((w) => keahlian.isEmpty || w.keahlian.contains(keahlian))
        .toList();
  }

  /// Keahlian yang benar-benar dimiliki warga, urut menurut jumlah orang
  /// yang punya. Dipakai untuk baris tombol penyaring di buku warga, supaya
  /// yang muncul hanya keahlian yang ada orangnya - bukan daftar angan-angan.
  static List<String> keahlianTerpakai(List<Warga> semua) {
    final hitung = <String, int>{};
    for (final w in semua) {
      for (final k in w.keahlian) {
        hitung[k] = (hitung[k] ?? 0) + 1;
      }
    }
    final daftar = hitung.keys.toList()
      ..sort((a, b) {
        final beda = hitung[b]!.compareTo(hitung[a]!);
        return beda != 0 ? beda : a.compareTo(b);
      });
    return daftar;
  }

  static Future<int> jumlahWarga() async {
    final snap = await _db
        .collection(BalaiConfig.colUsers)
        .where('disetujui', isEqualTo: true)
        .count()
        .get();
    return snap.count ?? 0;
  }
}
