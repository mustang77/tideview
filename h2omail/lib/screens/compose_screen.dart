import 'package:flutter/material.dart';

import '../jmap/jmap_client.dart';
import '../util/format.dart';

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

  @override
  void initState() {
    super.initState();
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
      await widget.client.sendEmail(
        sentMailboxId: widget.sentMailboxId,
        to: to,
        cc: _splitAddresses(_cc.text),
        subject: _subject.text.trim().isEmpty
            ? '(tanpa subjek)'
            : _subject.text.trim(),
        textBody: _body.text,
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
