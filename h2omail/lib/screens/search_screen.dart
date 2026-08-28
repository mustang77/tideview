import 'package:flutter/material.dart';

import '../jmap/jmap_client.dart';
import '../widgets/email_tile.dart';
import 'compose_screen.dart';
import 'message_view.dart';

class SearchScreen extends StatefulWidget {
  final JmapClient client;
  final String? sentMailboxId;
  final String? trashMailboxId;

  const SearchScreen({
    super.key,
    required this.client,
    this.sentMailboxId,
    this.trashMailboxId,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _query = TextEditingController();
  List<EmailHeader> _results = [];
  bool _busy = false;
  bool _searched = false;

  Future<void> _search() async {
    final q = _query.text.trim();
    if (q.isEmpty) return;
    setState(() => _busy = true);
    try {
      final results = await widget.client.searchEmails(q);
      if (!mounted) return;
      setState(() {
        _results = results;
        _searched = true;
      });
    } on JmapException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(EmailHeader h) async {
    try {
      final detail = await widget.client.getEmail(h.id);
      if (!h.seen) {
        h.seen = true;
        widget.client.setSeen(h.id, true).catchError((_) {});
      }
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(detail.header.subject, maxLines: 1)),
          body: MessageView(
            detail: detail,
            client: widget.client,
            onDelete: () async {
              final trash = widget.trashMailboxId;
              try {
                if (trash != null) {
                  await widget.client.moveToMailbox(detail.header.id, trash);
                } else {
                  await widget.client.destroyEmail(detail.header.id);
                }
              } catch (_) {}
              if (mounted) {
                setState(() =>
                    _results.removeWhere((e) => e.id == detail.header.id));
                Navigator.of(context).pop();
              }
            },
            onMarkUnread: () {
              widget.client.setSeen(detail.header.id, false).catchError((_) {});
              h.seen = false;
              Navigator.of(context).pop();
            },
            onReply: () {
              final sent = widget.sentMailboxId;
              if (sent == null) return;
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ComposeScreen(
                  client: widget.client,
                  sentMailboxId: sent,
                  replyTo: detail,
                ),
              ));
            },
          ),
        ),
      ));
      if (mounted) setState(() {});
    } on JmapException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _query,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _search(),
          decoration: const InputDecoration(
            hintText: 'Cari email...',
            border: InputBorder.none,
          ),
        ),
        actions: [
          IconButton(onPressed: _search, icon: const Icon(Icons.search)),
        ],
      ),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : !_searched
              ? const Center(
                  child: Text('Ketik kata kunci, lalu Enter.'))
              : _results.isEmpty
                  ? const Center(child: Text('Tidak ditemukan.'))
                  : ListView.separated(
                      itemCount: _results.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) => EmailTile(
                        email: _results[i],
                        onTap: () => _open(_results[i]),
                      ),
                    ),
    );
  }
}
