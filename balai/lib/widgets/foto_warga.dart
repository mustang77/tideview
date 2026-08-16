import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Foto profil warga, atau inisial namanya kalau belum ada foto.
///
/// Warna inisial diambil dari nama, jadi orang yang sama selalu dapat warna
/// yang sama di seluruh aplikasi. Itu membuat beranda tetap mudah dipindai
/// walau separuh desa belum memasang foto.
class FotoWarga extends StatelessWidget {
  const FotoWarga({
    super.key,
    required this.nama,
    this.foto = '',
    this.ukuran = 42,
  });

  final String nama;
  final String foto;
  final double ukuran;

  /// Palet inisial, diambil dari warna kategori supaya tidak ada warna asing
  /// yang tiba-tiba muncul di halaman.
  static const List<(Color, Color)> _paletTerang = <(Color, Color)>[
    (BalaiColors.merekLembut, BalaiColors.merek),
    (BalaiColors.maduLembut, BalaiColors.madu),
    (BalaiColors.bataLembut, BalaiColors.bata),
    (BalaiColors.nilaLembut, BalaiColors.nila),
    (BalaiColors.terongLembut, BalaiColors.terong),
  ];

  static const List<(Color, Color)> _paletGelap = <(Color, Color)>[
    (BalaiColors.merekLembutGelap, BalaiColors.merekGelap),
    (BalaiColors.maduLembutGelap, BalaiColors.maduGelap),
    (BalaiColors.bataLembutGelap, BalaiColors.bataGelap),
    (BalaiColors.nilaLembutGelap, BalaiColors.nilaGelap),
    (BalaiColors.terongLembutGelap, BalaiColors.terongGelap),
  ];

  String get _inisial {
    final bagian = nama.trim().split(RegExp(r'\s+'))
      ..removeWhere((s) => s.isEmpty);
    if (bagian.isEmpty) return '?';
    if (bagian.length == 1) {
      final satu = bagian.first;
      return (satu.length == 1 ? satu : satu.substring(0, 2)).toUpperCase();
    }
    return (bagian.first[0] + bagian.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (foto.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: foto,
          width: ukuran,
          height: ukuran,
          fit: BoxFit.cover,
          placeholder: (_, __) => _kotakInisial(context),
          errorWidget: (_, __, ___) => _kotakInisial(context),
        ),
      );
    }
    return _kotakInisial(context);
  }

  Widget _kotakInisial(BuildContext context) {
    final gelap = Theme.of(context).brightness == Brightness.dark;
    final palet = gelap ? _paletGelap : _paletTerang;
    // Jumlah kode huruf nama menentukan warnanya - sederhana, dan hasilnya
    // tetap sama di semua perangkat.
    var jumlah = 0;
    for (final unit in nama.codeUnits) {
      jumlah += unit;
    }
    final (latar, tulisan) = palet[jumlah % palet.length];

    return Container(
      width: ukuran,
      height: ukuran,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: latar, shape: BoxShape.circle),
      child: Text(
        _inisial,
        style: TextStyle(
          color: tulisan,
          fontSize: ukuran * 0.36,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
