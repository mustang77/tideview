import 'dart:io';

import 'package:flutter/material.dart';

import '../core/config.dart';
import '../core/theme.dart';
import '../data/auth_repository.dart';
import '../data/foto_repository.dart';
import '../data/kiriman_repository.dart';
import '../models/kategori.dart';
import '../models/warga.dart';
import '../widgets/label_kategori.dart';

/// Lembar tulis kiriman, naik dari bawah layar.
class TulisScreen extends StatefulWidget {
  const TulisScreen({super.key, required this.saya});

  final Warga saya;

  static Future<void> buka(BuildContext context, {required Warga saya}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => TulisScreen(saya: saya),
    );
  }

  @override
  State<TulisScreen> createState() => _TulisScreenState();
}

class _TulisScreenState extends State<TulisScreen> {
  final TextEditingController _isi = TextEditingController();
  Kategori _kategori = Kategori.umum;
  File? _foto;
  bool _semat = false;
  bool _mengirim = false;

  @override
  void dispose() {
    _isi.dispose();
    super.dispose();
  }

  List<Kategori> get _pilihanKategori => widget.saya.kepalaDesa
      ? Kategori.values
      : Kategori.untukWarga();

  Future<void> _pilihFoto(bool dariKamera) async {
    try {
      final berkas = await FotoRepository.pilih(dariKamera: dariKamera);
      if (berkas != null && mounted) setState(() => _foto = berkas);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak bisa membuka kamera atau galeri.'),
        ),
      );
    }
  }

  Future<void> _kirim() async {
    if (_isi.text.trim().isEmpty && _foto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tulis sesuatu dulu, atau pilih foto.')),
      );
      return;
    }

    setState(() => _mengirim = true);
    try {
      await KirimanRepository.kirim(
        penulis: widget.saya,
        isi: _isi.text,
        kategori: _kategori,
        foto: _foto,
        // Pengumuman selalu naik ke atas beranda; kiriman lain menyusul
        // pilihan kepala desa.
        disematkan: _semat || _kategori == Kategori.pengumuman,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Terkirim ke beranda desa')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _mengirim = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AuthRepository.pesanRamah(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = BalaiTheme.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: t.garis,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text('Bagikan ke warga desa',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),

              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _pilihanKategori.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 7),
                  itemBuilder: (context, i) {
                    final k = _pilihanKategori[i];
                    return PilPilihan(
                      label: k.label,
                      terpilih: _kategori == k,
                      onTap: () => setState(() => _kategori = k),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _isi,
                minLines: 4,
                maxLines: 10,
                maxLength: BalaiConfig.maksHurufKiriman,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText:
                      'Apa yang sedang terjadi di ${BalaiConfig.namaDesa}?',
                  counterText: '',
                ),
              ),

              if (_foto != null) ...<Widget>[
                const SizedBox(height: 12),
                Stack(
                  alignment: Alignment.topRight,
                  children: <Widget>[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.file(
                        _foto!,
                        height: 190,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Material(
                        color: Colors.black54,
                        shape: const CircleBorder(),
                        child: IconButton(
                          icon: const Icon(Icons.close,
                              size: 18, color: Colors.white),
                          tooltip: 'Buang foto',
                          onPressed: () => setState(() => _foto = null),
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              if (widget.saya.kepalaDesa &&
                  _kategori != Kategori.pengumuman) ...<Widget>[
                const SizedBox(height: 4),
                CheckboxListTile(
                  value: _semat,
                  onChanged: (v) => setState(() => _semat = v ?? false),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Sematkan di atas beranda',
                      style: TextStyle(fontSize: 14)),
                ),
              ],

              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  IconButton(
                    onPressed: _mengirim ? null : () => _pilihFoto(true),
                    icon: const Icon(Icons.photo_camera_outlined),
                    tooltip: 'Ambil foto',
                  ),
                  IconButton(
                    onPressed: _mengirim ? null : () => _pilihFoto(false),
                    icon: const Icon(Icons.photo_library_outlined),
                    tooltip: 'Pilih dari galeri',
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _mengirim ? null : _kirim,
                    child: _mengirim
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          )
                        : const Text('Kirim'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
