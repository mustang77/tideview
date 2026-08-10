import 'package:flutter/material.dart';

import '../store.dart';

/// Masuk sebagai pelanggan: cukup nama + no. HP (akun lokal di
/// perangkat, tanpa kata sandi). Dipakai juga saat masuk kembali
/// setelah keluar.
class CustomerLoginScreen extends StatefulWidget {
  const CustomerLoginScreen({super.key});

  @override
  State<CustomerLoginScreen> createState() => _CustomerLoginScreenState();
}

class _CustomerLoginScreenState extends State<CustomerLoginScreen> {
  late final _name = TextEditingController(text: store.profile.name);
  late final _phone = TextEditingController(text: store.profile.phone);
  String? _nameError;
  String? _phoneError;

  /// Pengguna baru (belum pernah mengisi profil di perangkat ini)
  /// melihat alur "Daftar"; pengguna lama melihat "Masuk".
  late final bool _isNew =
      store.profile.name.isEmpty && store.profile.phone.isEmpty;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    final phone = _phone.text.trim();
    setState(() {
      _nameError = name.isEmpty ? 'Nama wajib diisi' : null;
      _phoneError = phone.isEmpty ? 'No. HP wajib diisi' : null;
    });
    if (name.isEmpty || phone.isEmpty) return;
    await store.saveProfile(name, phone, store.profile.address);
    await store.setRole('customer');
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(_isNew ? 'Daftar' : 'Masuk')),
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
                    _isNew
                        ? 'Selamat datang! 👋'
                        : 'Selamat datang kembali! 👋',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isNew
                        ? 'Buat akun dengan nama dan no. HP untuk mulai '
                            'memesan dan melacak cucian Anda.'
                        : 'Periksa nama dan no. HP Anda, lalu masuk.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),
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
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: 'No. HP / WhatsApp',
                      errorText: _phoneError,
                      prefixIcon: const Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _submit,
                    icon: Icon(_isNew ? Icons.person_add_alt : Icons.login),
                    label: Text(_isNew ? 'Daftar & Mulai' : 'Masuk'),
                    style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16)),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Data Anda tersimpan di perangkat ini.',
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
