/// Satu acara desa, tersimpan di events/{id}.
class Acara {
  const Acara({
    required this.id,
    required this.judul,
    this.keterangan = '',
    this.tempat = '',
    this.mulai = 0,
    this.pembuatUid = '',
    this.pembuatNama = '',
    this.dibuat = 0,
    this.jumlahIkut = 0,
  });

  final String id;
  final String judul;
  final String keterangan;

  /// "Balai desa", "Teras Bu Sri". Diketik bebas, bukan peta - di desa
  /// orang menyebut tempat pakai nama, bukan koordinat.
  final String tempat;

  /// Milidetik epoch, tanggal dan jam acara dimulai.
  final int mulai;

  final String pembuatUid;
  final String pembuatNama;
  final int dibuat;

  /// Jumlah warga yang menyatakan ikut.
  final int jumlahIkut;

  static Acara dariMap(String id, Map<String, dynamic> m) {
    return Acara(
      id: id,
      judul: m['judul'] as String? ?? '',
      keterangan: m['keterangan'] as String? ?? '',
      tempat: m['tempat'] as String? ?? '',
      mulai: (m['mulai'] as num? ?? 0).toInt(),
      pembuatUid: m['pembuatUid'] as String? ?? '',
      pembuatNama: m['pembuatNama'] as String? ?? '',
      dibuat: (m['dibuat'] as num? ?? 0).toInt(),
      jumlahIkut: (m['jumlahIkut'] as num? ?? 0).toInt(),
    );
  }

  Map<String, dynamic> keMap() {
    return <String, dynamic>{
      'judul': judul,
      'keterangan': keterangan,
      'tempat': tempat,
      'mulai': mulai,
      'pembuatUid': pembuatUid,
      'pembuatNama': pembuatNama,
      'dibuat': dibuat,
      'jumlahIkut': jumlahIkut,
    };
  }

  Acara salin({int? jumlahIkut}) {
    return Acara(
      id: id,
      judul: judul,
      keterangan: keterangan,
      tempat: tempat,
      mulai: mulai,
      pembuatUid: pembuatUid,
      pembuatNama: pembuatNama,
      dibuat: dibuat,
      jumlahIkut: jumlahIkut ?? this.jumlahIkut,
    );
  }
}
