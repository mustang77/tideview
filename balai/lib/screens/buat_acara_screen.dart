import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/waktu.dart';
import '../data/acara_repository.dart';
import '../data/auth_repository.dart';
import '../models/warga.dart';

/// Membuat acara baru: gotong royong, posyandu, rapat, hajatan.
class BuatAcaraScreen extends StatefulWidget {
  const BuatAcaraScreen({super.key, required this.saya});

  final Warga saya;

  @override
  State<BuatAcaraScreen> createState() => _BuatAcaraScreenState();
}

class _BuatAcaraScreenState extends State<BuatAcaraScreen> {
  final _formKunci = GlobalKey<FormState>();
  final _judul = TextEditingController();
  final _tempat = TextEditingController();
  final _keterangan = TextEditingController();

  late DateTime _mulai = _bulatkanKeJamBerikutnya();
  bool _menyimpan = false;

  /// Acara desa hampir tidak pernah dimulai pukul 14.37, jadi jam awal
  /// dibulatkan - mengurangi satu langkah bagi yang membuat acara.
  static DateTime _bulatkanKeJamBerikutnya() {
    final kini = DateTime.now();
    return DateTime(kini.year, kini.month, kini.day, kini.hour + 1);
  }

  @override
  void dispose() {
    _judul.dispose();
    _tempat.dispose();
    _keterangan.dispose();
    super.dispose();
  }

  Future<void> _pilihTanggal() async {
    final kini = DateTime.now();
    final tanggal = await showDatePicker(
      context: context,
      initialDate: _mulai,
      firstDate: DateTime(kini.year, kini.month, kini.day),
      lastDate: kini.add(const Duration(days: 730)),
      helpText: 'Tanggal acara',
      cancelText: 'Batal',
      confirmText: 'Pilih',
    );
    if (tanggal == null || !mounted) return;

    final jam = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_mulai),
      helpText: 'Jam mulai',
      cancelText: 'Batal',
      confirmText: 'Pilih',
    );
    if (jam == null) return;

    setState(() {
      _mulai = DateTime(
          tanggal.year, tanggal.month, tanggal.day, jam.hour, jam.minute);
    });
  }

  Future<void> _simpan() async {
    if (!_formKunci.currentState!.validate()) return;

    setState(() => _menyimpan = true);
    try {
      await AcaraRepository.buat(
        pembuat: widget.saya,
        judul: _judul.text,
        keterangan: _keterangan.text,
        tempat: _tempat.text,
        mulai: _mulai,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Acara ditambahkan ke agenda desa')),
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
      appBar: AppBar(title: const Text('Acara baru')),
      body: SafeArea(
        child: Form(
          key: _formKunci,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: <Widget>[
              TextFormField(
                controller: _judul,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nama acara',
                  hintText: 'Gotong royong bersihkan selokan',
                ),
                validator: (v) => (v == null || v.trim().length < 3)
                    ? 'Tulis nama acaranya'
                    : null,
              ),
              const SizedBox(height: 14),

              InkWell(
                onTap: _pilihTanggal,
                borderRadius: BorderRadius.circular(14),
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Waktu'),
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.event, size: 19, color: t.tinta3),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${Waktu.hariTanggal(_mulai.millisecondsSinceEpoch)}'
                          ', pukul '
                          '${Waktu.jam(_mulai.millisecondsSinceEpoch)}',
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
                      Icon(Icons.edit_outlined, size: 17, color: t.tinta3),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _tempat,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Tempat',
                  hintText: 'Balai desa',
                ),
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _keterangan,
                minLines: 3,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Keterangan',
                  hintText: 'Bawa cangkul kalau punya. Kopi disiapkan.',
                ),
              ),
              const SizedBox(height: 24),

              FilledButton(
                onPressed: _menyimpan ? null : _simpan,
                child: _menyimpan
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      )
                    : const Text('Simpan acara'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
