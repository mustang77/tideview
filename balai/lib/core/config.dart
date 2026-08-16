/// Setelan desa dan nama koleksi Firestore.
///
/// Satu desa per aplikasi. Kalau nanti aplikasi ini dipakai desa lain,
/// cukup ganti isi [BalaiConfig] dan bangun ulang - tidak ada nama desa
/// yang ditulis langsung di dalam layar.
class BalaiConfig {
  const BalaiConfig._();

  // ---- Identitas desa ----------------------------------------------------

  /// Nama desa, tampil di kepala aplikasi.
  static const String namaDesa = 'Karang Sari';

  /// Nama aplikasi, tampil di kepala aplikasi dan di layar masuk.
  static const String namaAplikasi = 'Balai';

  /// Daftar gang/dusun. Dipakai di menu pilihan saat warga mengisi alamat
  /// dan sebagai penyaring di buku warga.
  static const List<String> daftarGang = <String>[
    'Gang 1',
    'Gang 2',
    'Gang 3',
    'Gang 4',
  ];

  /// Keahlian yang bisa dipilih warga di profilnya. Inilah yang membuat
  /// buku warga berguna: saat pompa air mati, warga mencari "Pompa air",
  /// bukan menggulir 112 nama satu per satu.
  static const List<String> daftarKeahlian = <String>[
    'Bidan',
    'Perawat',
    'Listrik',
    'Pompa air',
    'Bengkel motor',
    'Gergaji mesin',
    'Tukang kayu',
    'Tukang batu',
    'Traktor',
    'Guru',
    'Jahit',
    'Warung',
    'Ojek',
    'Sopir',
  ];

  // ---- Koleksi Firestore -------------------------------------------------

  static const String colUsers = 'users';
  static const String colPosts = 'posts';
  static const String colEvents = 'events';

  /// Subkoleksi.
  static const String colComments = 'comments';
  static const String colLikes = 'likes';
  static const String colRsvps = 'rsvps';

  // ---- Batasan -----------------------------------------------------------

  /// Jumlah kiriman yang diambil sekali muat.
  static const int halamanBeranda = 20;

  /// Panjang maksimal isi kiriman.
  static const int maksHurufKiriman = 2000;

  /// Sisi terpanjang foto setelah diperkecil, dalam piksel. Desa sering
  /// dapat sinyal seadanya, jadi foto 12 MP dari kamera HP tidak dikirim
  /// apa adanya.
  static const double maksSisiFoto = 1600;

  /// Mutu JPEG saat mengunggah (0-100).
  static const int mutuFoto = 82;
}
