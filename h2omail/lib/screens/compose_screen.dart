import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../jmap/jmap_client.dart';
import '../util/brand.dart';
import '../util/format.dart';
import '../util/signature.dart';

class ComposeScreen extends StatefulWidget {
  final JmapClient client;
  final String sentMailboxId;
  final EmailDetail? replyTo;

  const ComposeScreen({
    super.key,
    required this.client,
    required this.sentMailboxId,
    this.replyTo,
  });

  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  final _to = TextEditingController();
  final _cc = TextEditingController();
  final _subject = TextEditingController();
  final _body = TextEditingController();
  bool _busy = false;

  Signature _sig = const Signature(enabled: false);
  bool _useSig = false;

  @override
  void initState() {
    super.initState();
    _loadSignature();
    final r = widget.replyTo;
    if (r != null) {
      final h = r.header;
      final replyAddr = h.from.isNotEmpty ? (h.from.first.email ?? '') : '';
      _to.text = replyAddr;
      _subject.text = h.subject.toLowerCase().startsWith('re:')
          ? h.subject
          : 'Re: ${h.subject}';
      final original = (r.text ?? '').trim();
      if (original.isNotEmpty) {
        final quoted =
            original.split('\n').map((l) => '> $l').join('\n');
        _body.text =
            '\n\nPada ${formatDateFull(h.receivedAt)}, $replyAddr menulis:\n$quoted';
        _body.selection = const TextSelection.collapsed(offset: 0);
      }
    }
  }

  Future<void> _loadSignature() async {
    final s = await SignatureStore.load(widget.client.username);
    if (!mounted) return;
    setState(() {
      _sig = s;
      _useSig = s.enabled;
    });
  }

  bool get _hasSignature =>
      !_sig.isEmpty || _sig.logoAvailableFor(widget.client.username);

  String _plainToHtml(String s) {
    final esc = s
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('\n', '<br>');
    return '<div style="font-family:Arial,Helvetica,sans-serif;'
        'font-size:14px;color:#222222;line-height:1.5;">$esc</div>';
  }

  List<String> _splitAddresses(String raw) => raw
      .split(RegExp(r'[,;\s]+'))
      .map((s) => s.trim())
      .where((s) => s.contains('@'))
      .toList();

  Future<void> _send() async {
    final to = _splitAddresses(_to.text);
    if (to.isEmpty) {
      _toast('Isi alamat tujuan (kolom Kepada).');
      return;
    }
    setState(() => _busy = true);
    try {
      final email = widget.client.username;
      final useSig = _useSig && _hasSignature;

      var textBody = _body.text;
      String? htmlBody;
      String? logoBlobId;

      if (useSig) {
        textBody = '${_body.text}\n\n${_sig.toText(email)}';
        if (_sig.logoAvailableFor(email)) {
          try {
            final data = await rootBundle.load(_sig.logoAssetFor(email)!);
            logoBlobId = await widget.client
                .uploadBlob(data.buffer.asUint8List(), 'image/png');
          } catch (_) {
            logoBlobId = null; // fall back to a signature without the logo
          }
        }
        htmlBody = '${_plainToHtml(_body.text)}<br><br>'
            '${_sig.toHtml(email, cidLogo: logoBlobId != null)}';
      }

      await widget.client.sendEmail(
        sentMailboxId: widget.sentMailboxId,
        to: to,
        cc: _splitAddresses(_cc.text),
        subject: _subject.text.trim().isEmpty
            ? '(tanpa subjek)'
            : _subject.text.trim(),
        textBody: textBody,
        htmlBody: htmlBody,
        inlineLogoBlobId: logoBlobId,
        inlineLogoCid: logoBlobId != null ? kSignatureLogoCid : null,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on JmapException catch (e) {
      _toast(e.message);
    } catch (e) {
      _toast('Gagal mengirim: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.replyTo == null ? 'Tulis Email' : 'Balas Email'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _busy ? null : _send,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send, size: 18),
              label: const Text('Kirim'),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _to,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Kepada',
                    hintText: 'nama@contoh.com (pisahkan dengan koma)',
                    border: UnderlineInputBorder(),
                  ),
                ),
                TextField(
                  controller: _cc,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Cc',
                    border: UnderlineInputBorder(),
                  ),
                ),
                TextField(
                  controller: _subject,
                  decoration: const InputDecoration(
                    labelText: 'Subjek',
                    border: UnderlineInputBorder(),
                  ),
                ),
                if (_hasSignature)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: _useSig,
                    onChanged: (v) => setState(() => _useSig = v),
                    secondary: const Icon(Icons.draw_outlined),
                    title: const Text('Sertakan tanda tangan'),
                    subtitle: Text(
                      _sig.name.isNotEmpty
                          ? _sig.name
                          : Brand.defFor(widget.client.username).companyName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                const SizedBox(height: 8),
                Expanded(
                  child: TextField(
                    controller: _body,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    decoration: const InputDecoration(
                      hintText: 'Tulis pesan...',
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
