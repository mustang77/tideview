import 'dart:io';

import 'package:flutter/material.dart';

import '../core/config.dart';
import '../core/theme.dart';
import '../data/auth_repository.dart';
import '../data/foto_repository.dart';
import '../models/warga.dart';
import '../widgets/foto_warga.dart';
import '../widgets/label_kategori.dart';

/// Mengubah data diri: nama, gang, patokan rumah, nomor HP, dan keahlian.
class UbahProfilScreen extends StatefulWidget {
  const UbahProfilScreen({super.key, required this.saya});

  final Warga saya;

  @override
  State<UbahProfilScreen> createState() => _UbahProfilScreenState();
}

class _UbahProfilScreenState extends State<UbahProfilScreen> {
  final _formKunci = GlobalKey<FormState>();
  late final TextEditingController _nama =
      TextEditingController(text: widget.saya.nama);
  late final TextEditingController _alamat =
      TextEditingController(text: widget.saya.alamat);
  late final TextEditingController _telepon =
      TextEditingController(text: widget.saya.telepon);

  late String _gang = widget.saya.gang.isEmpty
      ? BalaiConfig.daftarGang.first
      : widget.saya.gang;
  late final Set<String> _keahlian = widget.saya.keahlian.toSet();

  File? _fotoBaru;
  bool _menyimpan = false;

  @override
  void dispose() {
    _nama.dispose();
    _alamat.dispose();
    _telepon.dispose();
    super.dispose();
  }

  /// Gabungan keahlian bawaan dan keahlian yang sudah dipilih warga, supaya
  /// pilihan lama tidak hilang dari layar kalau daftarnya nanti diubah.
  List<String> get _pilihanKeahlian {
    final semua = <String>{...BalaiConfig.daftarKeahlian, ..._keahlian}.toList()
      ..sort();
    return semua;
  }

  Future<void> _gantiFoto() async {
    final berkas = await FotoRepository.pilih(dariKamera: false);
    if (berkas != null && mounted) setState(() => _fotoBaru = berkas);
  }

  Future<void> _simpan() async {
    if (!_formKunci.currentState!.validate()) return;

    setState(() => _menyimpan = true);
    try {
      var urlFoto = widget.saya.foto;
      if (_fotoBaru != null) {
        urlFoto = await FotoRepository.unggahProfil(_fotoBaru!, widget.saya.uid);
      }

      await AuthRepository.simpanProfil(
        widget.saya.salin(
          nama: _nama.text.trim(),
          foto: urlFoto,
          gang: _gang,
          alamat: _alamat.text.trim(),
          telepon: _telepon.text.trim(),
          keahlian: _keahlian.toList()..sort(),
        ),
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data Anda tersimpan')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _menyimpan = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AuthRepository.pesanRamah(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = BalaiTheme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Ubah data saya')),
      body: SafeArea(
        child: Form(
          key: _formKunci,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: <Widget>[
              Center(
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: <Widget>[
                    if (_fotoBaru != null)
                      ClipOval(
                        child: Image.file(_fotoBaru!,
                            width: 92, height: 92, fit: BoxFit.cover),
                      )
                    else
                      FotoWarga(
                        nama: widget.saya.nama,
                        foto: widget.saya.foto,
                        ukuran: 92,
                      ),
                    Material(
                      color: Theme.of(context).colorScheme.primary,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _gantiFoto,
                        child: Padding(
                          padding: const EdgeInsets.all(7),
                          child: Icon(
                            Icons.photo_camera,
                            size: 17,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              TextFormField(
                controller: _nama,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nama panggilan'),
                validator: (v) => (v == null || v.trim().length < 2)
                    ? 'Tulis nama Anda'
                    : null,
              ),
              const SizedBox(height: 14),

              DropdownButtonFormField<String>(
                initialValue: BalaiConfig.daftarGang.contains(_gang)
                    ? _gang
                    : BalaiConfig.daftarGang.first,
                decoration: const InputDecoration(labelText: 'Gang'),
                items: BalaiConfig.daftarGang
                    .map((g) =>
                        DropdownMenuItem<String>(value: g, child: Text(g)))
                    .toList(),
                onChanged: (v) => setState(() => _gang = v ?? _gang),
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _alamat,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Patokan rumah',
                  hintText: 'Rumah dengan pohon kamboja',
                ),
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _telepon,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Nomor HP',
                  hintText: 'Dilihat warga lain di buku warga',
                ),
              ),
              const SizedBox(height: 22),

              Text('Keahlian', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Pilih yang Anda bisa bantu. Warga mencari lewat ini saat '
                'ada yang rusak atau ada yang sakit.',
                style: TextStyle(fontSize: 13, color: t.tinta3, height: 1.5),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: _pilihanKeahlian.map((k) {
                  return PilPilihan(
                    label: k,
                    terpilih: _keahlian.contains(k),
                    onTap: () => setState(() {
                      if (!_keahlian.remove(k)) _keahlian.add(k);
                    }),
                  );
                }).toList(),
              ),
              const SizedBox(height: 26),

              FilledButton(
                onPressed: _menyimpan ? null : _simpan,
                child: _menyimpan
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      )
                    : const Text('Simpan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
