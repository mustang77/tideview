import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/waktu.dart';
import '../data/acara_repository.dart';
import '../models/acara.dart';
import '../models/warga.dart';
import 'buat_acara_screen.dart';

/// Agenda desa.
class AcaraScreen extends StatelessWidget {
  const AcaraScreen({super.key, required this.saya});

  final Warga? saya;

  @override
  Widget build(BuildContext context) {
    final t = BalaiTheme.of(context);
    final bolehBuat = saya?.bolehMenulis ?? false;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: bolehBuat
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => BuatAcaraScreen(saya: saya!),
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Acara baru'),
            )
          : null,
      body: StreamBuilder<List<Acara>>(
        stream: AcaraRepository.mendatang(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final daftar = snap.data ?? const <Acara>[];

          if (daftar.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.event_available_outlined,
                        size: 44, color: t.tinta3),
                    const SizedBox(height: 14),
                    Text(
                      'Belum ada acara yang dijadwalkan.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: t.tinta3, height: 1.6),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 96),
            itemCount: daftar.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.only(left: 2, bottom: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Agenda desa',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 2),
                      Text(
                        daftar.length == 1
                            ? '1 kegiatan yang akan datang'
                            : '${daftar.length} kegiatan yang akan datang',
                        style: TextStyle(fontSize: 12.5, color: t.tinta3),
                      ),
                    ],
                  ),
                );
              }
              return _KartuAcara(acara: daftar[i - 1], saya: saya);
            },
          );
        },
      ),
    );
  }
}

class _KartuAcara extends StatelessWidget {
  const _KartuAcara({required this.acara, required this.saya});

  final Acara acara;
  final Warga? saya;

  bool get _bolehHapus =>
      saya != null &&
      (saya!.uid == acara.pembuatUid || saya!.kepalaDesa);

  @override
  Widget build(BuildContext context) {
    final t = BalaiTheme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _kotakTanggal(context, t),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          acara.judul,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (_bolehHapus)
                        InkWell(
                          onTap: () => _tanyaHapus(context),
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child:
                                Icon(Icons.more_horiz, color: t.tinta3, size: 20),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: <Widget>[
                      Icon(Icons.schedule, size: 14, color: t.tinta3),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          <String>[
                            Waktu.hariTanggal(acara.mulai),
                            Waktu.jam(acara.mulai),
                            if (acara.tempat.isNotEmpty) acara.tempat,
                          ].join(' · '),
                          style: TextStyle(fontSize: 12.5, color: t.tinta3),
                        ),
                      ),
                    ],
                  ),
                  if (acara.keterangan.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 6),
                    Text(
                      acara.keterangan,
                      style:
                          TextStyle(fontSize: 13.5, height: 1.5, color: t.tinta2),
                    ),
                  ],
                  const SizedBox(height: 10),
                  _barisIkut(context, t),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kotakTanggal(BuildContext context, BalaiTheme t) {
    return Container(
      width: 54,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: t.permukaan2,
        border: Border.all(color: t.garis),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        children: <Widget>[
          Text(
            Waktu.bulanPendek(acara.mulai).toUpperCase(),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: t.bata,
            ),
          ),
          Text(
            Waktu.tanggalDuaDigit(acara.mulai),
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontSize: 22),
          ),
        ],
      ),
    );
  }

  Widget _barisIkut(BuildContext context, BalaiTheme t) {
    final orang = saya;
    if (orang == null) return const SizedBox.shrink();

    return StreamBuilder<bool>(
      stream: AcaraRepository.sayaIkut(acara.id),
      builder: (context, snap) {
        final ikut = snap.data ?? false;
        return Row(
          children: <Widget>[
            if (orang.bolehMenulis)
              ikut
                  ? OutlinedButton.icon(
                      onPressed: () =>
                          AcaraRepository.ubahIkut(acara.id, orang),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Ikut'),
                    )
                  : FilledButton(
                      onPressed: () =>
                          AcaraRepository.ubahIkut(acara.id, orang),
                      child: const Text('Saya ikut'),
                    ),
            const SizedBox(width: 10),
            Flexible(
              child: InkWell(
                onTap: () => _lihatYangIkut(context),
                child: Text(
                  '${acara.jumlahIkut} ikut',
                  style: TextStyle(fontSize: 12.5, color: t.tinta3),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _lihatYangIkut(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StreamBuilder<List<String>>(
        stream: AcaraRepository.namaYangIkut(acara.id),
        builder: (context, snap) {
          final nama = snap.data ?? const <String>[];
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text('Yang ikut',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                if (nama.isEmpty)
                  const Text('Belum ada yang menyatakan ikut.')
                else
                  Text(nama.join(', '),
                      style: const TextStyle(height: 1.6, fontSize: 14)),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _tanyaHapus(BuildContext context) async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus acara ini?'),
        content: Text('"${acara.judul}" hilang dari agenda semua warga.'),
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
    if (yakin ?? false) await AcaraRepository.hapus(acara.id);
  }
}
