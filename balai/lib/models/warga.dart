/// Satu warga desa, tersimpan di users/{uid}.
class Warga {
  const Warga({
    required this.uid,
    required this.nama,
    this.foto = '',
    this.gang = '',
    this.alamat = '',
    this.telepon = '',
    this.keahlian = const <String>[],
    this.disetujui = false,
    this.kepalaDesa = false,
    this.bergabung = 0,
  });

  final String uid;
  final String nama;
  final String foto;

  /// Gang/dusun tempat tinggal, dari [BalaiConfig.daftarGang].
  final String gang;

  /// Petunjuk tambahan yang dipakai orang desa sungguhan, misalnya
  /// "rumah dengan pohon kamboja". Lebih berguna daripada nomor rumah.
  final String alamat;

  final String telepon;

  /// Yang bisa dikerjakan warga ini kalau dimintai tolong.
  final List<String> keahlian;

  /// Kepala desa harus menyetujui akun baru sebelum warga bisa menulis.
  /// Sebelum disetujui, warga tetap boleh membaca - jadi orang tidak
  /// menatap layar kosong sambil menunggu.
  final bool disetujui;

  final bool kepalaDesa;

  /// Milidetik epoch saat akun dibuat.
  final int bergabung;

  /// Boleh menulis kiriman, komentar, dan mendaftar acara.
  bool get bolehMenulis => disetujui || kepalaDesa;

  /// Huruf awal untuk foto profil sementara: "Bu Sri" -> "BS".
  String get inisial {
    final bagian = nama.trim().split(RegExp(r'\s+'))
      ..removeWhere((s) => s.isEmpty);
    if (bagian.isEmpty) return '?';
    if (bagian.length == 1) {
      final satu = bagian.first;
      return (satu.length == 1 ? satu : satu.substring(0, 2)).toUpperCase();
    }
    return (bagian.first[0] + bagian.last[0]).toUpperCase();
  }

  /// Baris kedua di buku warga: "Gang 2 · rumah dengan pohon kamboja".
  String get keterangan {
    final bagian = <String>[
      if (gang.isNotEmpty) gang,
      if (alamat.isNotEmpty) alamat,
    ];
    return bagian.join(' · ');
  }

  static Warga dariMap(String uid, Map<String, dynamic> m) {
    return Warga(
      uid: uid,
      nama: m['nama'] as String? ?? 'Warga',
      foto: m['foto'] as String? ?? '',
      gang: m['gang'] as String? ?? '',
      alamat: m['alamat'] as String? ?? '',
      telepon: m['telepon'] as String? ?? '',
      keahlian: (m['keahlian'] as List?)?.cast<String>() ?? const <String>[],
      disetujui: m['disetujui'] as bool? ?? false,
      kepalaDesa: m['kepalaDesa'] as bool? ?? false,
      bergabung: (m['bergabung'] as num? ?? 0).toInt(),
    );
  }

  /// Isi yang boleh ditulis ulang oleh warga sendiri.
  ///
  /// `disetujui` dan `kepalaDesa` sengaja TIDAK ikut. Kalau ikut, menyimpan
  /// profil akan menimpa keputusan kepala desa - dan warga bisa mengangkat
  /// dirinya sendiri jadi kepala desa. Aturan Firestore juga mengunci
  /// keduanya, jadi ada dua lapis penjaga.
  Map<String, dynamic> keMap() {
    return <String, dynamic>{
      'nama': nama,
      'foto': foto,
      'gang': gang,
      'alamat': alamat,
      'telepon': telepon,
      'keahlian': keahlian,
    };
  }

  Warga salin({
    String? nama,
    String? foto,
    String? gang,
    String? alamat,
    String? telepon,
    List<String>? keahlian,
    bool? disetujui,
    bool? kepalaDesa,
  }) {
    return Warga(
      uid: uid,
      nama: nama ?? this.nama,
      foto: foto ?? this.foto,
      gang: gang ?? this.gang,
      alamat: alamat ?? this.alamat,
      telepon: telepon ?? this.telepon,
      keahlian: keahlian ?? this.keahlian,
      disetujui: disetujui ?? this.disetujui,
      kepalaDesa: kepalaDesa ?? this.kepalaDesa,
      bergabung: bergabung,
    );
  }

  /// Apakah warga ini cocok dengan kata yang dicari di buku warga?
  /// Mencakup nama, gang, alamat, dan keahlian sekaligus, supaya
  /// mengetik "pompa" langsung menemukan orangnya.
  bool cocok(String kata) {
    if (kata.trim().isEmpty) return true;
    final k = kata.trim().toLowerCase();
    return nama.toLowerCase().contains(k) ||
        gang.toLowerCase().contains(k) ||
        alamat.toLowerCase().contains(k) ||
        keahlian.any((e) => e.toLowerCase().contains(k));
  }
}
