import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';

/// Kelola daftar admin Mode Pemilik (Admin 1, Admin 2, dst.).
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  Future<void> _editAdmin(BuildContext context, {AdminUser? admin}) async {
    final name = TextEditingController(
        text: admin?.name ?? 'Admin ${store.admins.length + 1}');
    final pin = TextEditingController();
    String? error;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(admin == null ? 'Tambah Admin' : 'Ubah Admin'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nama admin'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pin,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: 'PIN (4-6 angka)',
                  counterText: '',
                  errorText: error,
                  helperText: admin == null
                      ? null
                      : 'Kosongkan bila PIN tidak diganti',
                  prefixIcon: const Icon(Icons.lock_outline),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Batal')),
            FilledButton(
              onPressed: () {
                final p = pin.text.trim();
                final pinRequired = admin == null;
                final pinValid = p.length >= 4 &&
                    p.length <= 6 &&
                    int.tryParse(p) != null;
                if ((pinRequired || p.isNotEmpty) && !pinValid) {
                  setState(() => error = 'PIN harus 4-6 angka.');
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;
    final nm = name.text.trim();
    if (nm.isEmpty) return;
    if (admin == null) {
      await store.addAdmin(nm, pin.text.trim());
    } else {
      await store.updateAdmin(admin, name: nm, pin: pin.text.trim());
    }
  }

  Future<void> _confirmDelete(BuildContext context, AdminUser a) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus admin?'),
        content: Text('"${a.name}" tidak akan bisa masuk Mode Pemilik lagi.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (yes == true) await store.deleteAdmin(a);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Kelola Admin')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    color: theme.colorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: theme.colorScheme.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              store.admins.isEmpty
                                  ? 'Belum ada admin. Selama kosong, Mode '
                                      'Pemilik terbuka tanpa PIN — tambahkan '
                                      'minimal satu admin untuk menguncinya.'
                                  : 'Masuk Mode Pemilik kini butuh memilih '
                                      'admin dan PIN. Setiap perubahan status '
                                      'pesanan dicatat atas nama admin yang '
                                      'sedang masuk.',
                              style: TextStyle(
                                  color:
                                      theme.colorScheme.onPrimaryContainer,
                                  fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final a in store.admins)
                    Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.badge_outlined,
                              color: theme.colorScheme.onPrimaryContainer),
                        ),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(a.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                            ),
                            if (a.id == store.currentAdminId) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Sedang masuk',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: theme.colorScheme.primary),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: const Text('PIN ••••'),
                        trailing: IconButton(
                          tooltip: 'Hapus ${a.name}',
                          onPressed: () => _confirmDelete(context, a),
                          icon: const Icon(Icons.delete_outline, size: 20),
                        ),
                        onTap: () => _editAdmin(context, admin: a),
                      ),
                    ),
                  const SizedBox(height: 4),
                  FilledButton.icon(
                    onPressed: () => _editAdmin(context),
                    icon: const Icon(Icons.person_add_alt),
                    label: const Text('Tambah Admin'),
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
