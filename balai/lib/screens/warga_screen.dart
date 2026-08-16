import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/warga_repository.dart';
import '../models/warga.dart';
import '../widgets/foto_warga.dart';
import '../widgets/label_kategori.dart';

/// Buku warga.
///
/// Inti gunanya bukan daftar nama, tapi menjawab "siapa yang bisa
/// memperbaiki pompa air sekarang" - jadi penyaring keahlian ditaruh di
/// tempat yang paling gampang dijangkau jempol.
class WargaScreen extends StatefulWidget {
  const WargaScreen({super.key});

  @override
  State<WargaScreen> createState() => _WargaScreenState();
}

class _WargaScreenState extends State<WargaScreen> {
  final TextEditingController _cari = TextEditingController();
  String _keahlian = '';

  @override
  void dispose() {
    _cari.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = BalaiTheme.of(context);

    return StreamBuilder<List<Warga>>(
      stream: WargaRepository.semua(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final semua = snap.data ?? const <Warga>[];
        final keahlian = WargaRepository.keahlianTerpakai(semua);
        final hasil = WargaRepository.saring(
          semua,
          cari: _cari.text,
          keahlian: _keahlian,
        );

        return Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
              child: TextField(
                controller: _cari,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Cari nama, gang, atau keahlian',
                  prefixIcon: Icon(Icons.search, color: t.tinta3),
                  suffixIcon: _cari.text.isEmpty
                      ? null
                      : IconButton(
                          icon: Icon(Icons.close, color: t.tinta3),
                          onPressed: () {
                            _cari.clear();
                            setState(() {});
                          },
                        ),
                ),
              ),
            ),

            if (keahlian.isNotEmpty)
              SizedBox(
                height: 42,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  itemCount: keahlian.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 7),
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return PilPilihan(
                        label: 'Semua',
                        terpilih: _keahlian.isEmpty,
                        onTap: () => setState(() => _keahlian = ''),
                      );
                    }
                    final k = keahlian[i - 1];
                    return PilPilihan(
                      label: k,
                      terpilih: _keahlian == k,
                      onTap: () => setState(
                          () => _keahlian = _keahlian == k ? '' : k),
                    );
                  },
                ),
              ),

            const SizedBox(height: 6),
            Expanded(
              child: hasil.isEmpty
                  ? _kosong(context, t, semua.isEmpty)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
                      itemCount: hasil.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        if (i == hasil.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8, left: 4),
                            child: Text(
                              hasil.length == semua.length
                                  ? '${semua.length} warga terdaftar'
                                  : '${hasil.length} dari ${semua.length} warga',
                              style:
                                  TextStyle(fontSize: 12.5, color: t.tinta3),
                            ),
                          );
                        }
                        return _KartuWarga(warga: hasil[i]);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _kosong(BuildContext context, BalaiTheme t, bool benarBenarKosong) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          benarBenarKosong
              ? 'Belum ada warga yang disetujui kepala desa.'
              : 'Tidak ada warga yang cocok.\nCoba kata lain, misalnya '
                  '“pompa” atau “bidan”.',
          textAlign: TextAlign.center,
          style: TextStyle(color: t.tinta3, height: 1.6),
        ),
      ),
    );
  }
}

class _KartuWarga extends StatelessWidget {
  const _KartuWarga({required this.warga});

  final Warga warga;

  @override
  Widget build(BuildContext context) {
    final t = BalaiTheme.of(context);
    final skema = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
        child: Row(
          children: <Widget>[
            FotoWarga(nama: warga.nama, foto: warga.foto),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          warga.nama,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (warga.kepalaDesa) ...<Widget>[
                        const SizedBox(width: 6),
                        Icon(Icons.verified, size: 15, color: skema.primary),
                      ],
                    ],
                  ),
                  if (warga.keterangan.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      warga.keterangan,
                      style: TextStyle(fontSize: 12.5, color: t.tinta3),
                    ),
                  ],
                  if (warga.keahlian.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: warga.keahlian
                          .map((k) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: t.permukaan2,
                                  border: Border.all(color: t.garis),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  k,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: t.tinta2,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
            if (warga.telepon.isNotEmpty)
              // Nomornya ditampilkan, bukan langsung memanggil: di desa orang
              // sering menyalinnya ke WhatsApp, bukan menelepon.
              IconButton(
                icon: Icon(Icons.phone_outlined, color: skema.primary),
                tooltip: 'Lihat nomor',
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(warga.nama),
                    content: SelectableText(
                      warga.telepon,
                      style: const TextStyle(fontSize: 20, letterSpacing: 1),
                    ),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Tutup'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
