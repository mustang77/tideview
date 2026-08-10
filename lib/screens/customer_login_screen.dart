import 'package:flutter/material.dart';

import '../store.dart';

/// Daftar / masuk akun pelanggan. Mode server: satu nomor HP = satu
/// akun dengan PIN (diverifikasi server). Mode lokal: cukup nama + HP.
class CustomerLoginScreen extends StatefulWidget {
  const CustomerLoginScreen({super.key});

  @override
  State<CustomerLoginScreen> createState() => _CustomerLoginScreenState();
}

class _CustomerLoginScreenState extends State<CustomerLoginScreen> {
  late final _name = TextEditingController(text: store.profile.name);
  late final _phone = TextEditingController(text: store.profile.phone);
  final _pin = TextEditingController();

  /// true = alur Daftar; false = alur Masuk (hanya relevan mode server).
  late bool _registerMode =
      store.profile.name.isEmpty && store.profile.phone.isEmpty;
  bool _busy = false;
  String? _nameError;
  String? _phoneError;
  String? _pinError;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final name = _name.text.trim();
    final phone = _phone.text.trim();
    final pin = _pin.text.trim();
    final needPin = store.online;
    setState(() {
      _nameError =
          _registerMode && name.isEmpty ? 'Nama wajib diisi' : null;
      _phoneError = phone.isEmpty ? 'No. HP wajib diisi' : null;
      _pinError = needPin &&
              (pin.length < 4 || pin.length > 6 || int.tryParse(pin) == null)
          ? 'PIN 4-6 angka'
          : null;
    });
    if (_nameError != null || _phoneError != null || _pinError != null) {
      return;
    }

    setState(() => _busy = true);
    final String? error;
    if (!store.online || _registerMode) {
      error = await store.registerCustomer(name, phone, pin);
    } else {
      error = await store.loginCustomer(phone, pin);
    }
    if (!mounted) return;
    setState(() => _busy = false);

    if (error == null) {
      Navigator.of(context).popUntil((r) => r.isFirst);
      return;
    }
    if (error == 'SUDAH_TERDAFTAR') {
      setState(() {
        _registerMode = false;
        _pin.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Nomor ini sudah terdaftar — silakan masuk '
              'dengan PIN Anda.')));
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(error)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final daftar = _registerMode || !store.online;
    return Scaffold(
      appBar: AppBar(title: Text(daftar ? 'Daftar' : 'Masuk')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF06B6D4), Color(0xFF0E7490)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.person,
                        size: 38, color: Colors.white),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    daftar
                        ? 'Selamat datang! 👋'
                        : 'Selamat datang kembali! 👋',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    daftar
                        ? (store.online
                            ? 'Buat akun dengan nama, no. HP, dan PIN. '
                                'Satu nomor HP hanya untuk satu akun.'
                            : 'Buat akun dengan nama dan no. HP untuk '
                                'mulai memesan.')
                        : 'Masuk dengan no. HP dan PIN Anda.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),
                  if (daftar) ...[
                    TextField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Nama',
                        errorText: _nameError,
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'No. HP / WhatsApp',
                      errorText: _phoneError,
                      prefixIcon: const Icon(Icons.phone_outlined),
                    ),
                  ),
                  if (store.online) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _pin,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      onSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: daftar ? 'Buat PIN (4-6 angka)' : 'PIN',
                        counterText: '',
                        errorText: _pinError,
                        helperText: daftar
                            ? 'PIN dipakai untuk masuk dan melindungi '
                                'pesanan Anda'
                            : null,
                        prefixIcon: const Icon(Icons.lock_outline),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _busy ? null : _submit,
                    icon: Icon(daftar ? Icons.person_add_alt : Icons.login),
                    label: Text(_busy
                        ? 'Memproses...'
                        : (daftar ? 'Daftar & Mulai' : 'Masuk')),
                    style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16)),
                  ),
                  if (store.online) ...[
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                                _registerMode = !_registerMode;
                                _pinError = null;
                              }),
                      child: Text(_registerMode
                          ? 'Sudah punya akun? Masuk'
                          : 'Belum punya akun? Daftar'),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    store.online
                        ? 'Akun tersimpan aman di server H2O Laundry.'
                        : 'Data Anda tersimpan di perangkat ini.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.disabledColor),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
