import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/waktu.dart';
import '../data/kiriman_repository.dart';
import '../models/kategori.dart';
import '../models/kiriman.dart';
import '../models/warga.dart';
import 'foto_warga.dart';
import 'label_kategori.dart';
import 'lembar_komentar.dart';

/// Satu kiriman di beranda.
class KartuKiriman extends StatelessWidget {
  const KartuKiriman({
    super.key,
    required this.kiriman,
    required this.saya,
  });

  final Kiriman kiriman;

  /// Warga yang sedang masuk. Null berarti profilnya belum termuat.
  final Warga? saya;

  bool get _bolehHapus =>
      saya != null &&
      (saya!.uid == kiriman.penulisUid || saya!.kepalaDesa);

  @override
  Widget build(BuildContext context) {
    final t = BalaiTheme.of(context);

    // Pengumuman kepala desa tampil beda: latar hijau lembut, tanpa foto
    // profil, dengan tanda semat. Warga harus bisa membedakannya dari
    // obrolan biasa dalam sekali lihat.
    if (kiriman.disematkan) return _kartuPengumuman(context, t);

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _kepala(context, t),
          if (kiriman.isi.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Text(kiriman.isi,
                  style: Theme.of(context).textTheme.bodyLarge),
            ),
          if (kiriman.foto.isNotEmpty) _foto(context, t),
          Divider(height: 1, color: t.garis),
          _tombol(context, t),
        ],
      ),
    );
  }

  Widget _kartuPengumuman(BuildContext context, BalaiTheme t) {
    final skema = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: t.merekLembut,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: skema.primary.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.push_pin_outlined, size: 15, color: skema.primary),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'PENGUMUMAN',
                  style: TextStyle(
                    color: skema.primary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              if (_bolehHapus) _menu(context, warnaIkon: skema.primary),
            ],
          ),
          const SizedBox(height: 6),
          Text(kiriman.isi, style: Theme.of(context).textTheme.bodyLarge),
          if (kiriman.foto.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _gambar(context, t),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '${kiriman.penulisNama} · Kepala desa · ${Waktu.lalu(kiriman.dibuat)}',
            style: TextStyle(fontSize: 12, color: t.tinta2),
          ),
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              _tombolSuka(context, t),
              _tombolKomentar(context, t),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kepala(BuildContext context, BalaiTheme t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 13, 6, 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          FotoWarga(nama: kiriman.penulisNama, foto: kiriman.penulisFoto),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  kiriman.penulisNama,
                  style: const TextStyle(
                      fontSize: 14.5, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Row(
                  children: <Widget>[
                    Text(
                      Waktu.lalu(kiriman.dibuat),
                      style: TextStyle(fontSize: 12, color: t.tinta3),
                    ),
                    if (kiriman.kategori != Kategori.umum) ...<Widget>[
                      const SizedBox(width: 7),
                      LabelKategori(kiriman.kategori),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (_bolehHapus) _menu(context),
        ],
      ),
    );
  }

  Widget _menu(BuildContext context, {Color? warnaIkon}) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_horiz,
          color: warnaIkon ?? BalaiTheme.of(context).tinta3),
      onSelected: (pilihan) async {
        if (pilihan == 'hapus') {
          final yakin = await _tanyaHapus(context);
          if (yakin) await KirimanRepository.hapus(kiriman);
        } else if (pilihan == 'semat') {
          await KirimanRepository.ubahSematan(kiriman.id, !kiriman.disematkan);
        }
      },
      itemBuilder: (context) => <PopupMenuEntry<String>>[
        if (saya?.kepalaDesa ?? false)
          PopupMenuItem<String>(
            value: 'semat',
            child: Text(kiriman.disematkan
                ? 'Lepas dari atas beranda'
                : 'Sematkan di atas beranda'),
          ),
        const PopupMenuItem<String>(
          value: 'hapus',
          child: Text('Hapus kiriman'),
        ),
      ],
    );
  }

  Future<bool> _tanyaHapus(BuildContext context) async {
    final jawab = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus kiriman ini?'),
        content: const Text(
            'Kiriman dan komentarnya hilang untuk semua warga, dan tidak '
            'bisa dikembalikan.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    return jawab ?? false;
  }

  Widget _foto(BuildContext context, BalaiTheme t) {
    return AspectRatio(aspectRatio: 5 / 3, child: _gambar(context, t));
  }

  Widget _gambar(BuildContext context, BalaiTheme t) {
    return CachedNetworkImage(
      imageUrl: kiriman.foto,
      fit: BoxFit.cover,
      width: double.infinity,
      placeholder: (_, __) => Container(color: t.permukaan2),
      errorWidget: (_, __, ___) => Container(
        color: t.permukaan2,
        alignment: Alignment.center,
        child: Icon(Icons.image_not_supported_outlined, color: t.tinta3),
      ),
    );
  }

  Widget _tombol(BuildContext context, BalaiTheme t) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(
        children: <Widget>[
          _tombolSuka(context, t),
          _tombolKomentar(context, t),
        ],
      ),
    );
  }

  Widget _tombolSuka(BuildContext context, BalaiTheme t) {
    return StreamBuilder<bool>(
      stream: KirimanRepository.sudahSuka(kiriman.id),
      builder: (context, snap) {
        final suka = snap.data ?? false;
        return TextButton.icon(
          onPressed: () => KirimanRepository.ubahSuka(kiriman.id),
          icon: Icon(
            suka ? Icons.favorite : Icons.favorite_border,
            size: 20,
            color: suka ? t.bata : t.tinta2,
          ),
          label: Text(
            kiriman.jumlahSuka == 0 ? 'Suka' : '${kiriman.jumlahSuka}',
            style: TextStyle(
              color: suka ? t.bata : t.tinta2,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      },
    );
  }

  Widget _tombolKomentar(BuildContext context, BalaiTheme t) {
    return TextButton.icon(
      onPressed: () => LembarKomentar.buka(context, kiriman: kiriman, saya: saya),
      icon: Icon(Icons.mode_comment_outlined, size: 19, color: t.tinta2),
      label: Text(
        kiriman.jumlahKomentar == 0 ? 'Komentar' : '${kiriman.jumlahKomentar}',
        style: TextStyle(color: t.tinta2, fontWeight: FontWeight.w600),
      ),
    );
  }
}
