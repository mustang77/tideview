import 'kategori.dart';

/// Satu kiriman di beranda, tersimpan di posts/{id}.
class Kiriman {
  const Kiriman({
    required this.id,
    required this.penulisUid,
    required this.penulisNama,
    required this.penulisFoto,
    required this.isi,
    this.kategori = Kategori.umum,
    this.foto = '',
    this.dibuat = 0,
    this.disematkan = false,
    this.jumlahSuka = 0,
    this.jumlahKomentar = 0,
  });

  final String id;
  final String penulisUid;

  /// Nama dan foto penulis disalin ke dalam kiriman, tidak diambil lewat
  /// pencarian terpisah. Beranda jadi cukup satu kali baca ke Firestore -
  /// penting saat sinyal desa cuma dua garis.
  final String penulisNama;
  final String penulisFoto;

  final String isi;
  final Kategori kategori;
  final String foto;

  /// Milidetik epoch.
  final int dibuat;

  /// Kiriman kepala desa yang dinaikkan ke atas beranda.
  final bool disematkan;

  final int jumlahSuka;
  final int jumlahKomentar;

  static Kiriman dariMap(String id, Map<String, dynamic> m) {
    return Kiriman(
      id: id,
      penulisUid: m['penulisUid'] as String? ?? '',
      penulisNama: m['penulisNama'] as String? ?? 'Warga',
      penulisFoto: m['penulisFoto'] as String? ?? '',
      isi: m['isi'] as String? ?? '',
      kategori: Kategori.dariKode(m['kategori'] as String?),
      foto: m['foto'] as String? ?? '',
      dibuat: (m['dibuat'] as num? ?? 0).toInt(),
      disematkan: m['disematkan'] as bool? ?? false,
      jumlahSuka: (m['jumlahSuka'] as num? ?? 0).toInt(),
      jumlahKomentar: (m['jumlahKomentar'] as num? ?? 0).toInt(),
    );
  }

  Map<String, dynamic> keMap() {
    return <String, dynamic>{
      'penulisUid': penulisUid,
      'penulisNama': penulisNama,
      'penulisFoto': penulisFoto,
      'isi': isi,
      'kategori': kategori.kode,
      'foto': foto,
      'dibuat': dibuat,
      'disematkan': disematkan,
      'jumlahSuka': jumlahSuka,
      'jumlahKomentar': jumlahKomentar,
    };
  }

  Kiriman salin({
    String? isi,
    Kategori? kategori,
    String? foto,
    bool? disematkan,
    int? jumlahSuka,
    int? jumlahKomentar,
  }) {
    return Kiriman(
      id: id,
      penulisUid: penulisUid,
      penulisNama: penulisNama,
      penulisFoto: penulisFoto,
      isi: isi ?? this.isi,
      kategori: kategori ?? this.kategori,
      foto: foto ?? this.foto,
      dibuat: dibuat,
      disematkan: disematkan ?? this.disematkan,
      jumlahSuka: jumlahSuka ?? this.jumlahSuka,
      jumlahKomentar: jumlahKomentar ?? this.jumlahKomentar,
    );
  }
}

/// Satu komentar, tersimpan di posts/{id}/comments/{id}.
class Komentar {
  const Komentar({
    required this.id,
    required this.penulisUid,
    required this.penulisNama,
    required this.penulisFoto,
    required this.isi,
    this.dibuat = 0,
  });

  final String id;
  final String penulisUid;
  final String penulisNama;
  final String penulisFoto;
  final String isi;
  final int dibuat;

  static Komentar dariMap(String id, Map<String, dynamic> m) {
    return Komentar(
      id: id,
      penulisUid: m['penulisUid'] as String? ?? '',
      penulisNama: m['penulisNama'] as String? ?? 'Warga',
      penulisFoto: m['penulisFoto'] as String? ?? '',
      isi: m['isi'] as String? ?? '',
      dibuat: (m['dibuat'] as num? ?? 0).toInt(),
    );
  }

  Map<String, dynamic> keMap() {
    return <String, dynamic>{
      'penulisUid': penulisUid,
      'penulisNama': penulisNama,
      'penulisFoto': penulisFoto,
      'isi': isi,
      'dibuat': dibuat,
    };
  }
}
