import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/kiriman_repository.dart';
import '../models/kiriman.dart';
import '../models/warga.dart';
import '../widgets/foto_warga.dart';
import '../widgets/kartu_kiriman.dart';
import 'tulis_screen.dart';

/// Beranda desa: pengumuman di atas, lalu kiriman warga dari yang terbaru.
class BerandaScreen extends StatelessWidget {
  const BerandaScreen({super.key, required this.saya});

  final Warga? saya;

  @override
  Widget build(BuildContext context) {
    final t = BalaiTheme.of(context);

    return StreamBuilder<List<Kiriman>>(
      stream: KirimanRepository.beranda(),
      builder: (context, snap) {
        if (snap.hasError) {
          return _pesanTengah(
            context,
            'Beranda tidak bisa dimuat. Periksa sinyal, lalu tarik ke bawah '
            'untuk memuat ulang.',
          );
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final daftar = snap.data ?? const <Kiriman>[];

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 96),
          itemCount: daftar.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            if (i == 0) return _kotakTulis(context, t);
            return KartuKiriman(kiriman: daftar[i - 1], saya: saya);
          },
        );
      },
    );
  }

  /// Baris "Bagikan sesuatu…" di puncak beranda. Untuk warga yang belum
  /// disetujui, tempat yang sama dipakai untuk menjelaskan kenapa mereka
  /// belum bisa menulis - bukan sekadar menyembunyikan tombolnya diam-diam.
  Widget _kotakTulis(BuildContext context, BalaiTheme t) {
    final orang = saya;
    if (orang == null) return const SizedBox.shrink();

    if (!orang.bolehMenulis) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: t.merekLembut,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: <Widget>[
            Icon(Icons.hourglass_top_rounded,
                size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Akun Anda menunggu persetujuan kepala desa. Silakan baca '
                'dulu - menulis terbuka setelah disetujui.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: StadiumBorder(side: BorderSide(color: t.garis)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () => TulisScreen.buka(context, saya: orang),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
          child: Row(
            children: <Widget>[
              FotoWarga(nama: orang.nama, foto: orang.foto, ukuran: 32),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Bagikan sesuatu ke warga desa…',
                  style: TextStyle(color: t.tinta3, fontSize: 14),
                ),
              ),
              Icon(Icons.photo_camera_outlined, size: 20, color: t.tinta3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pesanTengah(BuildContext context, String pesan) {
    final t = BalaiTheme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          pesan,
          textAlign: TextAlign.center,
          style: TextStyle(color: t.tinta3, height: 1.6),
        ),
      ),
    );
  }
}
