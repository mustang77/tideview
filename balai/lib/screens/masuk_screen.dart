import 'package:flutter/material.dart';

import '../core/config.dart';
import '../core/theme.dart';
import '../data/auth_repository.dart';

/// Layar masuk dan daftar, dalam satu halaman yang bisa ditukar.
class MasukScreen extends StatefulWidget {
  const MasukScreen({super.key});

  @override
  State<MasukScreen> createState() => _MasukScreenState();
}

class _MasukScreenState extends State<MasukScreen> {
  final _formKunci = GlobalKey<FormState>();
  final _nama = TextEditingController();
  final _email = TextEditingController();
  final _sandi = TextEditingController();
  final _telepon = TextEditingController();

  bool _daftarBaru = false;
  bool _sibuk = false;
  bool _sandiTerlihat = false;
  String _gang = BalaiConfig.daftarGang.first;
  String? _galat;

  @override
  void dispose() {
    _nama.dispose();
    _email.dispose();
    _sandi.dispose();
    _telepon.dispose();
    super.dispose();
  }

  Future<void> _kirim() async {
    if (!_formKunci.currentState!.validate()) return;

    setState(() {
      _sibuk = true;
      _galat = null;
    });

    try {
      if (_daftarBaru) {
        await AuthRepository.daftar(
          nama: _nama.text,
          email: _email.text,
          sandi: _sandi.text,
          gang: _gang,
          telepon: _telepon.text,
        );
      } else {
        await AuthRepository.masuk(_email.text, _sandi.text);
      }
      // Tidak perlu berpindah layar sendiri: GerbangScreen mendengarkan
      // keadaan akun dan menggantinya begitu masuk berhasil.
    } catch (e) {
      if (mounted) setState(() => _galat = AuthRepository.pesanRamah(e));
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  Future<void> _lupaSandi() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _galat = 'Isi dulu alamat email Anda di atas.');
      return;
    }
    try {
      await AuthRepository.lupaSandi(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tautan ganti sandi dikirim ke $email')),
      );
    } catch (e) {
      if (mounted) setState(() => _galat = AuthRepository.pesanRamah(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = BalaiTheme.of(context);
    final skema = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKunci,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      BalaiConfig.namaAplikasi,
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontSize: 34),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Desa ${BalaiConfig.namaDesa}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: t.tinta3, fontSize: 14),
                    ),
                    const SizedBox(height: 30),

                    if (_daftarBaru) ...<Widget>[
                      TextFormField(
                        controller: _nama,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Nama panggilan',
                          hintText: 'Yang biasa dipakai tetangga, misal Bu Sri',
                        ),
                        validator: (v) => (v == null || v.trim().length < 2)
                            ? 'Tulis nama Anda'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _gang,
                        decoration: const InputDecoration(labelText: 'Gang'),
                        items: BalaiConfig.daftarGang
                            .map((g) => DropdownMenuItem<String>(
                                value: g, child: Text(g)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _gang = v ?? _gang),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _telepon,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Nomor HP (boleh dikosongkan)',
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (v) => (v == null || !v.contains('@'))
                          ? 'Tulis alamat email yang benar'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _sandi,
                      obscureText: !_sandiTerlihat,
                      decoration: InputDecoration(
                        labelText: 'Kata sandi',
                        suffixIcon: IconButton(
                          icon: Icon(_sandiTerlihat
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined),
                          onPressed: () =>
                              setState(() => _sandiTerlihat = !_sandiTerlihat),
                        ),
                      ),
                      validator: (v) => (v == null || v.length < 6)
                          ? 'Kata sandi minimal 6 huruf'
                          : null,
                      onFieldSubmitted: (_) => _kirim(),
                    ),

                    if (_galat != null) ...<Widget>[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: t.bataLembut,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _galat!,
                          style: TextStyle(color: t.bata, fontSize: 13.5),
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _sibuk ? null : _kirim,
                      child: _sibuk
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2.2),
                            )
                          : Text(_daftarBaru ? 'Daftar' : 'Masuk'),
                    ),

                    if (!_daftarBaru)
                      TextButton(
                        onPressed: _sibuk ? null : _lupaSandi,
                        child: const Text('Lupa kata sandi'),
                      ),

                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: _sibuk
                          ? null
                          : () => setState(() {
                                _daftarBaru = !_daftarBaru;
                                _galat = null;
                              }),
                      child: Text(_daftarBaru
                          ? 'Sudah punya akun? Masuk'
                          : 'Warga baru? Daftar di sini'),
                    ),

                    if (_daftarBaru) ...<Widget>[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: t.merekLembut,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          'Akun baru ditinjau kepala desa dulu sebelum bisa '
                          'menulis. Sambil menunggu, Anda tetap bisa membaca '
                          'beranda dan buku warga.',
                          style: TextStyle(
                            color: skema.primary,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
