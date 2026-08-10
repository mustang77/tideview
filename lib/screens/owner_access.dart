import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import '../store.dart';

/// Pintu masuk Mode Pemilik. Tanpa admin terdaftar langsung masuk;
/// bila sudah ada admin, wajib memilih admin dan memasukkan PIN.
Future<void> enterOwnerMode(BuildContext context) async {
  if (store.online) await store.refresh();
  if (!context.mounted) return;
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
  if (admin != null) await store.loginOwner(admin, pin: pinOf[admin.id]);
}

/// PIN yang berhasil dipakai login, untuk header autentikasi berikutnya.
final pinOf = <String, String>{};

/// Hitung ketukan rahasia pada logo (7x, jeda maksimal 2 detik).
/// Mengembalikan true bila ambang tercapai; petunjuk sisa ketukan
/// muncul setelah ketukan ke-4.
class SecretTapCounter {
  static const _tapsNeeded = 7;

  int _taps = 0;
  DateTime? _lastTap;

  bool registerTap(BuildContext context) {
    final now = DateTime.now();
    if (_lastTap == null ||
        now.difference(_lastTap!) > const Duration(seconds: 2)) {
      _taps = 0;
    }
    _lastTap = now;
    _taps++;

    if (_taps >= _tapsNeeded) {
      _taps = 0;
      return true;
    }
    if (_taps >= 4) {
      final sisa = _tapsNeeded - _taps;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('Ketuk $sisa kali lagi untuk Mode Pemilik'),
          duration: const Duration(seconds: 1),
        ));
    }
    return false;
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

  bool _busy = false;

  Future<void> _submit() async {
    if (_busy) return;
    if (!store.online) {
      if (_pin.text == _selected.pin) {
        pinOf[_selected.id] = _pin.text;
        Navigator.pop(context, _selected);
      } else {
        setState(() => _error = 'PIN salah, coba lagi.');
      }
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await store.api!.adminLogin(_selected.id, _pin.text);
      pinOf[_selected.id] = _pin.text;
      if (mounted) Navigator.pop(context, _selected);
    } on ApiException {
      if (mounted) setState(() => _error = 'PIN salah, coba lagi.');
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Tidak bisa terhubung ke server.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
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
