import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/waktu.dart';
import '../data/auth_repository.dart';
import '../models/warga.dart';
import '../widgets/foto_warga.dart';

/// Layar kepala desa: menyetujui warga baru.
///
/// Inilah pintu desa. Selama akun belum disetujui, orang bisa membaca tapi
/// tidak bisa menulis - jadi orang luar yang menemukan aplikasi ini tidak
/// bisa mengirim apa pun ke beranda.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = BalaiTheme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Warga menunggu persetujuan')),
      body: SafeArea(
        child: StreamBuilder<List<Warga>>(
          stream: AuthRepository.wargaMenunggu(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final daftar = snap.data ?? const <Warga>[];
            if (daftar.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.check_circle_outline,
                          size: 44, color: t.tinta3),
                      const SizedBox(height: 14),
                      Text(
                        'Tidak ada yang menunggu.\nSemua warga sudah disetujui.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: t.tinta3, height: 1.6),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 32),
              itemCount: daftar.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _kartu(context, t, daftar[i]),
            );
          },
        ),
      ),
    );
  }

  Widget _kartu(BuildContext context, BalaiTheme t, Warga warga) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                FotoWarga(nama: warga.nama, foto: warga.foto),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        warga.nama,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        <String>[
                          if (warga.gang.isNotEmpty) warga.gang,
                          if (warga.telepon.isNotEmpty) warga.telepon,
                          if (warga.bergabung > 0)
                            'daftar ${Waktu.lalu(warga.bergabung)}',
                        ].join(' · '),
                        style: TextStyle(fontSize: 12.5, color: t.tinta3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      await AuthRepository.setujuiWarga(warga.uid);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${warga.nama} sudah bisa menulis'),
                        ),
                      );
                    },
                    child: const Text('Setujui'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _tanyaTolak(context, warga),
                    child: const Text('Tolak'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _tanyaTolak(BuildContext context, Warga warga) async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Tolak ${warga.nama}?'),
        content: const Text(
            'Data profilnya dihapus. Kalau ternyata memang warga desa, dia '
            'bisa mendaftar lagi.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Tolak'),
          ),
        ],
      ),
    );
    if (yakin ?? false) await AuthRepository.tolakWarga(warga.uid);
  }
}
