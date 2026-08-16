import 'package:flutter/material.dart';

import '../core/config.dart';
import '../core/theme.dart';
import '../core/waktu.dart';
import '../data/auth_repository.dart';
import '../main.dart';
import '../models/warga.dart';
import '../widgets/foto_warga.dart';
import 'admin_screen.dart';
import 'ubah_profil_screen.dart';

/// Profil warga sendiri dan setelan aplikasi.
class SayaScreen extends StatelessWidget {
  const SayaScreen({super.key, required this.saya});

  final Warga? saya;

  @override
  Widget build(BuildContext context) {
    final orang = saya;
    if (orang == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final t = BalaiTheme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 32),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 18),
            child: Column(
              children: <Widget>[
                FotoWarga(nama: orang.nama, foto: orang.foto, ukuran: 76),
                const SizedBox(height: 12),
                Text(orang.nama,
                    style: Theme.of(context).textTheme.titleLarge),
                if (orang.keterangan.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 3),
                  Text(
                    orang.keterangan,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: t.tinta3),
                  ),
                ],
                if (orang.bergabung > 0) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    'Bergabung ${Waktu.lalu(orang.bergabung)}',
                    style: TextStyle(fontSize: 12, color: t.tinta3),
                  ),
                ],
                if (!orang.bolehMenulis) ...<Widget>[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: t.merekLembut,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Menunggu persetujuan kepala desa.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                OutlinedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => UbahProfilScreen(saya: orang),
                    ),
                  ),
                  child: const Text('Ubah data saya'),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 18),
        _judulBagian(context, 'Pengaturan'),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: <Widget>[
              ListTile(
                leading: Icon(Icons.brightness_6_outlined, color: t.tinta3),
                title: const Text('Tampilan'),
                subtitle: Text(_namaTampilan(BalaiApp.tampilanSekarang(context))),
                onTap: () => _pilihTampilan(context),
              ),
              Divider(height: 1, color: t.garis),
              ListTile(
                leading: Icon(Icons.help_outline, color: t.tinta3),
                title: const Text('Tentang aplikasi'),
                onTap: () => showAboutDialog(
                  context: context,
                  applicationName:
                      '${BalaiConfig.namaAplikasi} ${BalaiConfig.namaDesa}',
                  applicationVersion: '0.1.0',
                  children: <Widget>[
                    const Text(
                      'Aplikasi warga desa: beranda, agenda acara, dan buku '
                      'warga. Dibuat untuk dipakai satu desa.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        if (orang.kepalaDesa) ...<Widget>[
          const SizedBox(height: 18),
          _judulBagian(context, 'Khusus kepala desa'),
          const SizedBox(height: 8),
          Card(
            child: StreamBuilder<List<Warga>>(
              stream: AuthRepository.wargaMenunggu(),
              builder: (context, snap) {
                final menunggu = snap.data?.length ?? 0;
                return ListTile(
                  leading: Icon(Icons.how_to_reg_outlined, color: t.tinta3),
                  title: const Text('Warga menunggu persetujuan'),
                  trailing: menunggu == 0
                      ? Text('0', style: TextStyle(color: t.tinta3))
                      : Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(
                            color: t.bataLembut,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '$menunggu',
                            style: TextStyle(
                              color: t.bata,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(builder: (_) => const AdminScreen()),
                  ),
                );
              },
            ),
          ),
        ],

        const SizedBox(height: 22),
        OutlinedButton(
          onPressed: () async {
            final yakin = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Keluar dari akun?'),
                content: const Text(
                    'Anda perlu memasukkan email dan kata sandi lagi untuk '
                    'masuk kembali.'),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Batal'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Keluar'),
                  ),
                ],
              ),
            );
            if (yakin ?? false) await AuthRepository.keluar();
          },
          child: const Text('Keluar'),
        ),
      ],
    );
  }

  Widget _judulBagian(BuildContext context, String teks) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(teks, style: Theme.of(context).textTheme.titleLarge),
    );
  }

  static String _namaTampilan(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Terang';
      case ThemeMode.dark:
        return 'Gelap';
      case ThemeMode.system:
        return 'Ikut setelan HP';
    }
  }

  void _pilihTampilan(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (lembar) {
        final sekarang = BalaiApp.tampilanSekarang(context);
        return SafeArea(
          child: RadioGroup<ThemeMode>(
            groupValue: sekarang,
            onChanged: (v) {
              if (v != null) BalaiApp.ubahTampilan(context, v);
              Navigator.pop(lembar);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: ThemeMode.values
                  .map((mode) => RadioListTile<ThemeMode>(
                        value: mode,
                        title: Text(_namaTampilan(mode)),
                      ))
                  .toList(),
            ),
          ),
        );
      },
    );
  }
}
