import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Jenis kiriman di beranda.
///
/// Di desa 100 orang, beranda itu papan pengumuman, bukan hiburan. Kategori
/// inilah yang menjaga kabar kambing hilang tidak menimbun kabar duka.
enum Kategori {
  umum('umum', 'Sekadar cerita'),
  jual('jual', 'Dijual'),
  bantuan('bantuan', 'Butuh bantuan'),
  hilang('hilang', 'Kehilangan'),
  acara('acara', 'Acara'),
  kabar('kabar', 'Kabar baik'),

  /// Hanya kepala desa yang bisa memakai ini, dan kiriman bertanda
  /// pengumuman selalu naik ke atas beranda.
  pengumuman('pengumuman', 'Pengumuman');

  const Kategori(this.kode, this.label);

  /// Nilai yang disimpan di Firestore. Sengaja dipisah dari [name] supaya
  /// mengganti nama enum di Dart tidak merusak data yang sudah tersimpan.
  final String kode;

  /// Tulisan yang dilihat warga.
  final String label;

  static Kategori dariKode(String? kode) {
    for (final k in Kategori.values) {
      if (k.kode == kode) return k;
    }
    return Kategori.umum;
  }

  /// Kategori yang boleh dipilih warga biasa saat menulis.
  static List<Kategori> untukWarga() => Kategori.values
      .where((k) => k != Kategori.pengumuman)
      .toList(growable: false);

  /// Warna tulisan pada label kategori.
  Color warna(BuildContext context) {
    final t = BalaiTheme.of(context);
    switch (this) {
      case Kategori.jual:
        return t.madu;
      case Kategori.bantuan:
        return t.bata;
      case Kategori.hilang:
        return t.nila;
      case Kategori.acara:
        return t.terong;
      case Kategori.kabar:
      case Kategori.pengumuman:
        return Theme.of(context).colorScheme.primary;
      case Kategori.umum:
        return t.tinta2;
    }
  }

  /// Warna latar label kategori.
  Color warnaLatar(BuildContext context) {
    final t = BalaiTheme.of(context);
    switch (this) {
      case Kategori.jual:
        return t.maduLembut;
      case Kategori.bantuan:
        return t.bataLembut;
      case Kategori.hilang:
        return t.nilaLembut;
      case Kategori.acara:
        return t.terongLembut;
      case Kategori.kabar:
      case Kategori.pengumuman:
        return t.merekLembut;
      case Kategori.umum:
        return t.permukaan2;
    }
  }
}
