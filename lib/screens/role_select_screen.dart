import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';

class RoleSelectScreen extends StatefulWidget {
  const RoleSelectScreen({super.key});

  @override
  State<RoleSelectScreen> createState() => _RoleSelectScreenState();
}

class _RoleSelectScreenState extends State<RoleSelectScreen> {
  static const _tapsNeeded = 7;

  int _logoTaps = 0;
  DateTime? _lastTap;

  /// Pintu rahasia mode pemilik: ketuk logo 7x berturut-turut
  /// (jeda antar ketukan maksimal 2 detik).
  void _onLogoTap() {
    final now = DateTime.now();
    if (_lastTap == null ||
        now.difference(_lastTap!) > const Duration(seconds: 2)) {
      _logoTaps = 0;
    }
    _lastTap = now;
    _logoTaps++;

    if (_logoTaps >= _tapsNeeded) {
      _logoTaps = 0;
      _enterOwnerMode();
      return;
    }

    // Beri petunjuk hanya setelah 4 ketukan agar tetap tersembunyi
    // dari pelanggan biasa.
    if (_logoTaps >= 4) {
      final sisa = _tapsNeeded - _logoTaps;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('Ketuk $sisa kali lagi untuk Mode Pemilik'),
          duration: const Duration(seconds: 1),
        ));
    }
  }

  /// Tanpa admin terdaftar, langsung masuk. Bila sudah ada admin,
  /// wajib memilih admin dan memasukkan PIN.
  Future<void> _enterOwnerMode() async {
    if (store.admins.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
            content: Text('Mode Pemilik terbuka. Tambahkan admin & PIN '
                'lewat menu Kelola Admin untuk mengamankannya.')));
      await store.setRole('owner');
      return;
    }
    final admin = await showDialog<AdminUser>(
      context: context,
      builder: (context) => const _AdminLoginDialog(),
    );
    if (admin != null) await store.loginOwner(admin);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GestureDetector(
                    onTap: _onLogoTap,
                    child: Container(
                      width: 88,
                      height: 88,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF06B6D4), Color(0xFF0E7490)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(Icons.local_laundry_service,
                          size: 48, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'H2O LAUNDRY',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    'PARAKAN',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 6,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Laundry bersih, wangi, dan rapi.\nAntar & ambil langsung di counter kami.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 36),
                  _RoleCard(
                    icon: Icons.person,
                    title: 'Saya Pelanggan',
                    subtitle: 'Pesan layanan laundry, antar ke counter, '
                        'dan lacak status cucian',
                    onTap: () => store.setRole('customer'),
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

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon,
                    size: 28, color: theme.colorScheme.onPrimaryContainer),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dialog pilih admin + PIN untuk masuk Mode Pemilik.
class _AdminLoginDialog extends StatefulWidget {
  const _AdminLoginDialog();

  @override
  State<_AdminLoginDialog> createState() => _AdminLoginDialogState();
}

class _AdminLoginDialogState extends State<_AdminLoginDialog> {
  late AdminUser _selected = store.admins.first;
  final _pin = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  void _submit() {
    if (_pin.text == _selected.pin) {
      Navigator.pop(context, _selected);
    } else {
      setState(() => _error = 'PIN salah, coba lagi.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Masuk Mode Pemilik'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<AdminUser>(
            initialValue: _selected,
            decoration: const InputDecoration(labelText: 'Admin'),
            items: [
              for (final a in store.admins)
                DropdownMenuItem(value: a, child: Text(a.name)),
            ],
            onChanged: (a) => setState(() {
              if (a != null) _selected = a;
              _error = null;
            }),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pin,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'PIN',
              counterText: '',
              errorText: _error,
              prefixIcon: const Icon(Icons.lock_outline),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal')),
        FilledButton(onPressed: _submit, child: const Text('Masuk')),
      ],
    );
  }
}
