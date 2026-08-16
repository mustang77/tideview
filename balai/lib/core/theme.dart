import 'package:flutter/material.dart';

/// Warna Balai.
///
/// Hijau desa, bukan biru aplikasi. Netralnya dicondongkan sedikit ke hijau
/// supaya abu-abunya terasa dipilih, bukan bawaan.
class BalaiColors {
  const BalaiColors._();

  // Terang
  static const kertas = Color(0xFFF7F9F4);
  static const permukaan = Color(0xFFFFFFFF);
  static const permukaan2 = Color(0xFFEFF3EC);
  static const garis = Color(0xFFDEE5D9);
  static const tinta = Color(0xFF16211A);
  static const tinta2 = Color(0xFF4A5A50);
  static const tinta3 = Color(0xFF7C8B81);
  static const merek = Color(0xFF2C5642);
  static const merekLembut = Color(0xFFDCE9E0);

  // Gelap
  static const kertasGelap = Color(0xFF121814);
  static const permukaanGelap = Color(0xFF19211B);
  static const permukaan2Gelap = Color(0xFF212A23);
  static const garisGelap = Color(0xFF2A342C);
  static const tintaGelap = Color(0xFFE7EDE6);
  static const tinta2Gelap = Color(0xFFAEBBB0);
  static const tinta3Gelap = Color(0xFF808E84);
  static const merekGelap = Color(0xFF7FBF9B);
  static const merekLembutGelap = Color(0xFF1D3A2B);

  // Warna kategori. Sengaja tidak terlalu pekat supaya beranda tidak
  // berubah jadi lampu lalu lintas.
  static const madu = Color(0xFF8A5F12);
  static const maduLembut = Color(0xFFF2E7CE);
  static const bata = Color(0xFFA0422A);
  static const bataLembut = Color(0xFFF6DFD7);
  static const nila = Color(0xFF3B4E8C);
  static const nilaLembut = Color(0xFFDFE4F4);
  static const terong = Color(0xFF6E3A63);
  static const terongLembut = Color(0xFFEFDFEC);

  static const maduGelap = Color(0xFFDFB264);
  static const maduLembutGelap = Color(0xFF33290F);
  static const bataGelap = Color(0xFFE39070);
  static const bataLembutGelap = Color(0xFF35201A);
  static const nilaGelap = Color(0xFF9FAFE8);
  static const nilaLembutGelap = Color(0xFF1D2340);
  static const terongGelap = Color(0xFFD6A6CB);
  static const terongLembutGelap = Color(0xFF31202E);
}

/// Warna tambahan yang tidak muat di [ColorScheme] bawaan Material.
///
/// Dipasang lewat [ThemeExtension] supaya layar cukup memanggil
/// `BalaiTheme.of(context).tinta3` tanpa perlu memeriksa mode gelap
/// sendiri-sendiri. Satu tempat untuk kedua mode - itu yang mencegah
/// teks mode terang muncul di atas latar mode gelap.
class BalaiTheme extends ThemeExtension<BalaiTheme> {
  const BalaiTheme({
    required this.permukaan2,
    required this.garis,
    required this.tinta2,
    required this.tinta3,
    required this.merekLembut,
    required this.madu,
    required this.maduLembut,
    required this.bata,
    required this.bataLembut,
    required this.nila,
    required this.nilaLembut,
    required this.terong,
    required this.terongLembut,
  });

  final Color permukaan2;
  final Color garis;
  final Color tinta2;
  final Color tinta3;
  final Color merekLembut;
  final Color madu;
  final Color maduLembut;
  final Color bata;
  final Color bataLembut;
  final Color nila;
  final Color nilaLembut;
  final Color terong;
  final Color terongLembut;

  static const terang = BalaiTheme(
    permukaan2: BalaiColors.permukaan2,
    garis: BalaiColors.garis,
    tinta2: BalaiColors.tinta2,
    tinta3: BalaiColors.tinta3,
    merekLembut: BalaiColors.merekLembut,
    madu: BalaiColors.madu,
    maduLembut: BalaiColors.maduLembut,
    bata: BalaiColors.bata,
    bataLembut: BalaiColors.bataLembut,
    nila: BalaiColors.nila,
    nilaLembut: BalaiColors.nilaLembut,
    terong: BalaiColors.terong,
    terongLembut: BalaiColors.terongLembut,
  );

  static const gelap = BalaiTheme(
    permukaan2: BalaiColors.permukaan2Gelap,
    garis: BalaiColors.garisGelap,
    tinta2: BalaiColors.tinta2Gelap,
    tinta3: BalaiColors.tinta3Gelap,
    merekLembut: BalaiColors.merekLembutGelap,
    madu: BalaiColors.maduGelap,
    maduLembut: BalaiColors.maduLembutGelap,
    bata: BalaiColors.bataGelap,
    bataLembut: BalaiColors.bataLembutGelap,
    nila: BalaiColors.nilaGelap,
    nilaLembut: BalaiColors.nilaLembutGelap,
    terong: BalaiColors.terongGelap,
    terongLembut: BalaiColors.terongLembutGelap,
  );

  static BalaiTheme of(BuildContext context) =>
      Theme.of(context).extension<BalaiTheme>() ?? terang;

  @override
  BalaiTheme copyWith({
    Color? permukaan2,
    Color? garis,
    Color? tinta2,
    Color? tinta3,
    Color? merekLembut,
    Color? madu,
    Color? maduLembut,
    Color? bata,
    Color? bataLembut,
    Color? nila,
    Color? nilaLembut,
    Color? terong,
    Color? terongLembut,
  }) {
    return BalaiTheme(
      permukaan2: permukaan2 ?? this.permukaan2,
      garis: garis ?? this.garis,
      tinta2: tinta2 ?? this.tinta2,
      tinta3: tinta3 ?? this.tinta3,
      merekLembut: merekLembut ?? this.merekLembut,
      madu: madu ?? this.madu,
      maduLembut: maduLembut ?? this.maduLembut,
      bata: bata ?? this.bata,
      bataLembut: bataLembut ?? this.bataLembut,
      nila: nila ?? this.nila,
      nilaLembut: nilaLembut ?? this.nilaLembut,
      terong: terong ?? this.terong,
      terongLembut: terongLembut ?? this.terongLembut,
    );
  }

  @override
  BalaiTheme lerp(ThemeExtension<BalaiTheme>? other, double t) {
    if (other is! BalaiTheme) return this;
    return BalaiTheme(
      permukaan2: Color.lerp(permukaan2, other.permukaan2, t)!,
      garis: Color.lerp(garis, other.garis, t)!,
      tinta2: Color.lerp(tinta2, other.tinta2, t)!,
      tinta3: Color.lerp(tinta3, other.tinta3, t)!,
      merekLembut: Color.lerp(merekLembut, other.merekLembut, t)!,
      madu: Color.lerp(madu, other.madu, t)!,
      maduLembut: Color.lerp(maduLembut, other.maduLembut, t)!,
      bata: Color.lerp(bata, other.bata, t)!,
      bataLembut: Color.lerp(bataLembut, other.bataLembut, t)!,
      nila: Color.lerp(nila, other.nila, t)!,
      nilaLembut: Color.lerp(nilaLembut, other.nilaLembut, t)!,
      terong: Color.lerp(terong, other.terong, t)!,
      terongLembut: Color.lerp(terongLembut, other.terongLembut, t)!,
    );
  }
}

/// Bentuk tema terang dan gelap aplikasi.
class BalaiThemeData {
  const BalaiThemeData._();

  static ThemeData terang() => _bangun(
        brightness: Brightness.light,
        latar: BalaiColors.kertas,
        permukaan: BalaiColors.permukaan,
        merek: BalaiColors.merek,
        diAtasMerek: Colors.white,
        tinta: BalaiColors.tinta,
        garis: BalaiColors.garis,
        ekstensi: BalaiTheme.terang,
      );

  static ThemeData gelap() => _bangun(
        brightness: Brightness.dark,
        latar: BalaiColors.kertasGelap,
        permukaan: BalaiColors.permukaanGelap,
        merek: BalaiColors.merekGelap,
        diAtasMerek: const Color(0xFF0C1710),
        tinta: BalaiColors.tintaGelap,
        garis: BalaiColors.garisGelap,
        ekstensi: BalaiTheme.gelap,
      );

  static ThemeData _bangun({
    required Brightness brightness,
    required Color latar,
    required Color permukaan,
    required Color merek,
    required Color diAtasMerek,
    required Color tinta,
    required Color garis,
    required BalaiTheme ekstensi,
  }) {
    final skema = ColorScheme(
      brightness: brightness,
      primary: merek,
      onPrimary: diAtasMerek,
      primaryContainer: ekstensi.merekLembut,
      onPrimaryContainer: merek,
      secondary: ekstensi.madu,
      onSecondary: diAtasMerek,
      error: ekstensi.bata,
      onError: Colors.white,
      surface: permukaan,
      onSurface: tinta,
      surfaceContainerLowest: latar,
      surfaceContainerHighest: ekstensi.permukaan2,
      outline: garis,
      outlineVariant: garis,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: skema,
      scaffoldBackgroundColor: latar,
      extensions: <ThemeExtension<dynamic>>[ekstensi],
      dividerTheme: DividerThemeData(color: garis, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: latar,
        surfaceTintColor: Colors.transparent,
        foregroundColor: tinta,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: permukaan,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: garis),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: merek,
          foregroundColor: diAtasMerek,
          // Tombol besar: banyak warga desa memakai HP dengan satu tangan
          // sambil menggendong sesuatu.
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          shape: const StadiumBorder(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ekstensi.tinta2,
          minimumSize: const Size(0, 48),
          side: BorderSide(color: garis),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          shape: const StadiumBorder(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: merek),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ekstensi.permukaan2,
        hintStyle: TextStyle(color: ekstensi.tinta3),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: garis),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: garis),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: merek, width: 1.6),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: latar,
        surfaceTintColor: Colors.transparent,
        indicatorColor: ekstensi.merekLembut,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: ekstensi.tinta3),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: tinta,
        contentTextStyle: TextStyle(color: latar, fontWeight: FontWeight.w600),
        behavior: SnackBarBehavior.floating,
        shape: const StadiumBorder(),
      ),
      // Judul memakai serif supaya terasa seperti papan pengumuman desa,
      // bukan dasbor perusahaan. Teks isi tetap sans supaya enak dibaca.
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
            fontFamily: 'serif', fontWeight: FontWeight.w600, fontSize: 22),
        titleLarge: TextStyle(
            fontFamily: 'serif', fontWeight: FontWeight.w600, fontSize: 19),
        titleMedium: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        bodyLarge: TextStyle(fontSize: 15, height: 1.45),
        bodyMedium: TextStyle(fontSize: 14, height: 1.45),
        labelSmall: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
      ).apply(bodyColor: tinta, displayColor: tinta),
    );
  }
}
