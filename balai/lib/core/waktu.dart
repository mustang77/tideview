/// Pengubah waktu jadi kalimat pendek berbahasa Indonesia.
///
/// Ditulis tangan, bukan pakai `intl`, karena yang dibutuhkan cuma
/// "2 jam lalu" dan "Kemarin" - dan pustaka bahasa yang penuh menambah
/// ukuran unduhan aplikasi tanpa gunanya di sini.
class Waktu {
  const Waktu._();

  static const List<String> _bulan = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];

  static const List<String> _hari = <String>[
    'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu',
  ];

  /// "Baru saja", "5 menit lalu", "2 jam lalu", "Kemarin", "14 Agu".
  ///
  /// [ms] adalah milidetik epoch. [sekarang] bisa diisi saat pengujian
  /// supaya hasilnya tidak berubah mengikuti jam dinding.
  static String lalu(int ms, {DateTime? sekarang}) {
    if (ms <= 0) return '';
    final saat = DateTime.fromMillisecondsSinceEpoch(ms);
    final kini = sekarang ?? DateTime.now();
    final selisih = kini.difference(saat);

    if (selisih.isNegative) return 'Baru saja';
    if (selisih.inMinutes < 1) return 'Baru saja';
    if (selisih.inMinutes < 60) return '${selisih.inMinutes} menit lalu';
    if (selisih.inHours < 24) return '${selisih.inHours} jam lalu';

    // Bandingkan tanggalnya, bukan selisih 24 jam: kiriman pukul 23.00
    // yang dibaca pukul 07.00 harus berbunyi "Kemarin", bukan "8 jam lalu".
    final hariIni = DateTime(kini.year, kini.month, kini.day);
    final hariKiriman = DateTime(saat.year, saat.month, saat.day);
    final bedaHari = hariIni.difference(hariKiriman).inDays;

    if (bedaHari == 1) return 'Kemarin';
    if (bedaHari < 7) return '$bedaHari hari lalu';
    if (saat.year == kini.year) return '${saat.day} ${_bulan[saat.month - 1]}';
    return '${saat.day} ${_bulan[saat.month - 1]} ${saat.year}';
  }

  static const List<String> _bulanPanjang = <String>[
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];

  /// "Agustus 2026" - dipakai untuk tanggal bergabung di profil.
  ///
  /// Bukan [lalu], karena "Bergabung Baru saja" terbaca aneh dan sebulan lagi
  /// jadi "Bergabung 30 hari lalu" - bukan itu yang ingin dilihat orang di
  /// profil tetangganya.
  static String bulanTahun(int ms) {
    if (ms <= 0) return '';
    final saat = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${_bulanPanjang[saat.month - 1]} ${saat.year}';
  }

  /// "Minggu, 24 Agu" - dipakai di kartu acara.
  static String hariTanggal(int ms) {
    if (ms <= 0) return '';
    final saat = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${_hari[saat.weekday - 1]}, ${saat.day} ${_bulan[saat.month - 1]}';
  }

  /// "06.00" - jam gaya Indonesia, memakai titik, bukan titik dua.
  static String jam(int ms) {
    if (ms <= 0) return '';
    final saat = DateTime.fromMillisecondsSinceEpoch(ms);
    final j = saat.hour.toString().padLeft(2, '0');
    final m = saat.minute.toString().padLeft(2, '0');
    return '$j.$m';
  }

  /// Singkatan bulan untuk kotak tanggal di kartu acara: "Agu".
  static String bulanPendek(int ms) {
    if (ms <= 0) return '';
    return _bulan[DateTime.fromMillisecondsSinceEpoch(ms).month - 1];
  }

  /// Tanggal dua digit untuk kotak tanggal: "24", "06".
  static String tanggalDuaDigit(int ms) {
    if (ms <= 0) return '';
    return DateTime.fromMillisecondsSinceEpoch(ms)
        .day
        .toString()
        .padLeft(2, '0');
  }

  /// Apakah acara sudah lewat? Dipakai untuk menyembunyikan acara lama
  /// dari daftar agenda.
  static bool sudahLewat(int ms, {DateTime? sekarang}) {
    if (ms <= 0) return false;
    return DateTime.fromMillisecondsSinceEpoch(ms)
        .isBefore(sekarang ?? DateTime.now());
  }
}
