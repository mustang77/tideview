import 'package:flutter/material.dart';

import '../util/brand.dart';
import '../util/signature.dart';

/// Editor for the per-account email signature that Compose appends on send.
class SignatureScreen extends StatefulWidget {
  final String email;
  const SignatureScreen({super.key, required this.email});

  @override
  State<SignatureScreen> createState() => _SignatureScreenState();
}

class _SignatureScreenState extends State<SignatureScreen> {
  final _name = TextEditingController();
  final _title = TextEditingController();
  final _phone = TextEditingController();
  final _website = TextEditingController();
  final _address = TextEditingController();
  bool _enabled = true;
  bool _logo = true;
  bool _loading = true;
  bool _saving = false;

  bool get _hasLogo => Brand.defFor(widget.email).logoAsset != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await SignatureStore.load(widget.email);
    if (!mounted) return;
    setState(() {
      _name.text = s.name;
      _title.text = s.title;
      _phone.text = s.phone;
      _website.text = s.website;
      _address.text = s.address;
      _enabled = s.enabled;
      _logo = s.includeLogo;
      _loading = false;
    });
  }

  Signature get _current => Signature(
        enabled: _enabled,
        includeLogo: _logo,
        name: _name.text.trim(),
        title: _title.text.trim(),
        phone: _phone.text.trim(),
        website: _website.text.trim(),
        address: _address.text.trim(),
      );

  Future<void> _save() async {
    setState(() => _saving = true);
    await SignatureStore.save(widget.email, _current);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Tanda tangan disimpan ✓')));
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _name.dispose();
    _title.dispose();
    _phone.dispose();
    _website.dispose();
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tanda Tangan'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check, size: 18),
              label: const Text('Simpan'),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _enabled,
                      onChanged: (v) => setState(() => _enabled = v),
                      title: const Text('Aktifkan tanda tangan'),
                      subtitle: const Text(
                          'Otomatis ditambahkan di bawah setiap email keluar.'),
                    ),
                    if (_hasLogo)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _logo,
                        onChanged:
                            _enabled ? (v) => setState(() => _logo = v) : null,
                        secondary: const Icon(Icons.image_outlined),
                        title: const Text('Sertakan logo'),
                      ),
                    const SizedBox(height: 8),
                    _field(_name, 'Nama', 'mis. Yogi Guevara'),
                    _field(_title, 'Jabatan', 'mis. Human Resources'),
                    _field(_phone, 'Telepon / WA', 'mis. +62 812-3456-7890',
                        keyboard: TextInputType.phone),
                    _field(_website, 'Website', 'mis. mayaresortsubud.com',
                        keyboard: TextInputType.url),
                    _field(_address, 'Alamat', 'mis. Ubud, Bali, Indonesia'),
                    const SizedBox(height: 20),
                    Text('Pratinjau',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    _Preview(sig: _current, email: widget.email),
                    const SizedBox(height: 8),
                    Text(
                      'Email dikirim dalam format HTML + teks biasa, jadi tetap '
                      'rapi walau penerima mematikan gambar.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _field(TextEditingController c, String label, String hint,
      {TextInputType? keyboard}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        keyboardType: keyboard,
        onChanged: (_) => setState(() {}),
        enabled: _enabled,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  final Signature sig;
  final String email;
  const _Preview({required this.sig, required this.email});

  @override
  Widget build(BuildContext context) {
    final brand = Brand.defFor(email);
    final accent = brand.seed;
    const muted = Color(0xFF6b7c79);
    final web = sig.website.replaceFirst(RegExp(r'^https?://'), '');
    final logo = sig.includeLogo ? brand.logoAsset : null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (logo != null) ...[
            Image.asset(logo, width: 60, height: 60),
            const SizedBox(width: 14),
          ],
          Container(
            padding: const EdgeInsets.only(left: 14),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: accent, width: 2)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(brand.companyName,
                    style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                if (brand.tagline != null)
                  Text(brand.tagline!,
                      style: TextStyle(color: muted, fontSize: 12)),
                const SizedBox(height: 4),
                if (sig.name.isNotEmpty)
                  Text(sig.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1f2d2b))),
                if (sig.title.isNotEmpty)
                  Text(sig.title, style: TextStyle(color: muted)),
                const SizedBox(height: 4),
                if (sig.phone.isNotEmpty)
                  Text('☎  ${sig.phone}',
                      style: const TextStyle(color: Color(0xFF1f2d2b))),
                Text('✉  $email',
                    style: const TextStyle(color: Color(0xFF1f2d2b))),
                if (web.isNotEmpty)
                  Text('🌐  $web',
                      style: TextStyle(
                          color: accent, fontWeight: FontWeight.bold)),
                if (sig.address.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(sig.address,
                        style: TextStyle(color: muted, fontSize: 11)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
