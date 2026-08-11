import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';

/// Layar "Tentang H2O Laundry": profil usaha, alamat, jam buka, dan
/// tombol WhatsApp/Maps. Pemilik bisa mengedit lewat tombol pensil.
class TentangScreen extends StatelessWidget {
  const TentangScreen({super.key});

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tentang'),
        actions: [
          if (store.role == 'owner')
            IconButton(
              tooltip: 'Edit Info Toko',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const TentangEditScreen())),
            ),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) {
            final a = store.about;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Kartu identitas bergradasi, senada kartu profil.
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF06B6D4), Color(0xFF0B4F6C)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(Icons.water_drop,
                            size: 42, color: Color(0xFF0E7490)),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        a.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800),
                      ),
                      if (a.tagline.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          a.tagline,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Column(
                    children: [
                      if (a.address.isNotEmpty)
                        ListTile(
                          leading: const Icon(Icons.location_on_outlined,
                              color: Color(0xFF0E7490)),
                          title: const Text('Alamat',
                              style:
                                  TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(a.address),
                          trailing: const Icon(Icons.map_outlined),
                          onTap: () => _open(a.maps.isNotEmpty
                              ? a.maps
                              : 'https://www.google.com/maps/search/?api=1'
                                  '&query=${Uri.encodeComponent(a.address)}'),
                        ),
                      if (a.wa.isNotEmpty) ...[
                        const Divider(height: 1, indent: 56),
                        ListTile(
                          leading: const Icon(Icons.chat_outlined,
                              color: Color(0xFF16A34A)),
                          title: const Text('WhatsApp',
                              style:
                                  TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text('+${waPhone(a.wa)}'),
                          trailing: const Icon(Icons.open_in_new, size: 18),
                          onTap: () =>
                              _open('https://wa.me/${waPhone(a.wa)}'),
                        ),
                      ],
                      if (a.hours.isNotEmpty) ...[
                        const Divider(height: 1, indent: 56),
                        ListTile(
                          leading: const Icon(Icons.schedule_outlined,
                              color: Color(0xFFD97706)),
                          title: const Text('Jam Buka',
                              style:
                                  TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(a.hours),
                        ),
                      ],
                      if (a.instagram.isNotEmpty) ...[
                        const Divider(height: 1, indent: 56),
                        ListTile(
                          leading: const Icon(Icons.camera_alt_outlined,
                              color: Color(0xFFDB2777)),
                          title: const Text('Instagram',
                              style:
                                  TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text('@${a.instagram
                              .replaceAll('@', '')
                              .replaceAll('https://instagram.com/', '')}'),
                          trailing: const Icon(Icons.open_in_new, size: 18),
                          onTap: () => _open(
                              'https://instagram.com/${a.instagram.replaceAll('@', '')}'),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Layanan Kami',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        for (final s in store.services)
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle,
                                    size: 16, color: Color(0xFF16A34A)),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(s.name,
                                        style:
                                            const TextStyle(fontSize: 13.5))),
                                Text(
                                  '${rupiah(s.price)}/${s.unit}',
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      color: theme
                                          .colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text('H2O Laundry Parakan v1.0',
                      style: theme.textTheme.bodySmall),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text('app.h2olaundry.com',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: const Color(0xFF0E7490))),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Form edit info toko (mode pemilik).
class TentangEditScreen extends StatefulWidget {
  const TentangEditScreen({super.key});

  @override
  State<TentangEditScreen> createState() => _TentangEditScreenState();
}

class _TentangEditScreenState extends State<TentangEditScreen> {
  late final TextEditingController _name;
  late final TextEditingController _tagline;
  late final TextEditingController _address;
  late final TextEditingController _wa;
  late final TextEditingController _hours;
  late final TextEditingController _maps;
  late final TextEditingController _ig;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final a = store.about;
    _name = TextEditingController(text: a.name);
    _tagline = TextEditingController(text: a.tagline);
    _address = TextEditingController(text: a.address);
    _wa = TextEditingController(text: a.wa);
    _hours = TextEditingController(text: a.hours);
    _maps = TextEditingController(text: a.maps);
    _ig = TextEditingController(text: a.instagram);
  }

  @override
  void dispose() {
    for (final c in [_name, _tagline, _address, _wa, _hours, _maps, _ig]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final err = await store.saveAbout(AboutInfo(
      name: _name.text.trim(),
      tagline: _tagline.text.trim(),
      address: _address.text.trim(),
      wa: _wa.text.trim(),
      hours: _hours.text.trim(),
      maps: _maps.text.trim(),
      instagram: _ig.text.trim(),
    ));
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err ?? 'Info toko tersimpan ✅')));
    if (err == null) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration deco(String label, IconData icon, {String? hint}) =>
        InputDecoration(
            labelText: label, prefixIcon: Icon(icon), hintText: hint);
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Info Toko')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
                controller: _name,
                decoration: deco('Nama Usaha', Icons.storefront_outlined)),
            const SizedBox(height: 12),
            TextField(
                controller: _tagline,
                decoration: deco('Slogan', Icons.auto_awesome_outlined)),
            const SizedBox(height: 12),
            TextField(
                controller: _address,
                maxLines: 2,
                decoration: deco('Alamat', Icons.location_on_outlined)),
            const SizedBox(height: 12),
            TextField(
                controller: _wa,
                keyboardType: TextInputType.phone,
                decoration: deco('No. WhatsApp', Icons.chat_outlined,
                    hint: '08xxxxxxxxxx')),
            const SizedBox(height: 12),
            TextField(
                controller: _hours,
                decoration: deco('Jam Buka', Icons.schedule_outlined,
                    hint: 'Senin–Minggu 07.00–21.00')),
            const SizedBox(height: 12),
            TextField(
                controller: _maps,
                keyboardType: TextInputType.url,
                decoration: deco(
                    'Tautan Google Maps (opsional)', Icons.map_outlined,
                    hint: 'https://maps.app.goo.gl/...')),
            const SizedBox(height: 12),
            TextField(
                controller: _ig,
                decoration: deco(
                    'Instagram (opsional)', Icons.camera_alt_outlined,
                    hint: 'namaakun')),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_outlined),
              label: const Text('Simpan'),
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ],
        ),
      ),
    );
  }
}
