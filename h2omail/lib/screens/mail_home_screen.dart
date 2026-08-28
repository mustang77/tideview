import 'package:flutter/material.dart';

import '../jmap/jmap_client.dart';
import '../util/auth_store.dart';
import '../util/format.dart';
import 'compose_screen.dart';
import 'login_screen.dart';
import 'message_view.dart';

class MailHomeScreen extends StatefulWidget {
  final JmapClient client;
  const MailHomeScreen({super.key, required this.client});

  @override
  State<MailHomeScreen> createState() => _MailHomeScreenState();
}

class _MailHomeScreenState extends State<MailHomeScreen> {
  List<JmapMailbox> _mailboxes = [];
  JmapMailbox? _selected;
  List<EmailHeader> _emails = [];
  int _total = 0;
  bool _loadingList = false;
  bool _loadingMore = false;
  EmailDetail? _openDetail;
  bool _loadingDetail = false;

  JmapClient get client => widget.client;

  JmapMailbox? _byRole(String role) {
    for (final m in _mailboxes) {
      if (m.role == role) return m;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final boxes = await client.getMailboxes();
      if (!mounted) return;
      setState(() => _mailboxes = boxes);
      final inbox = _byRole('inbox') ?? (boxes.isNotEmpty ? boxes.first : null);
      if (inbox != null) await _selectMailbox(inbox);
    } on JmapException catch (e) {
      _toast(e.message);
    }
  }

  Future<void> _selectMailbox(JmapMailbox m) async {
    setState(() {
      _selected = m;
      _emails = [];
      _total = 0;
      _openDetail = null;
      _loadingList = true;
    });
    try {
      final page = await client.queryEmails(m.id);
      if (!mounted) return;
      setState(() {
        _emails = page.emails;
        _total = page.total;
      });
    } on JmapException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _loadingList = false);
    }
  }

  Future<void> _loadMore() async {
    final m = _selected;
    if (m == null || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await client.queryEmails(m.id, position: _emails.length);
      if (!mounted) return;
      setState(() {
        _emails = [..._emails, ...page.emails];
        _total = page.total;
      });
    } on JmapException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _refresh() async {
    final m = _selected;
    try {
      final boxes = await client.getMailboxes();
      if (mounted) setState(() => _mailboxes = boxes);
    } on JmapException catch (_) {}
    if (m != null) await _selectMailbox(m);
  }

  Future<void> _openEmail(EmailHeader h, {required bool wide}) async {
    setState(() => _loadingDetail = true);
    try {
      final detail = await client.getEmail(h.id);
      if (!h.seen) {
        h.seen = true;
        // Fire and forget; UI already updated.
        client.setSeen(h.id, true).catchError((_) {});
      }
      if (!mounted) return;
      if (wide) {
        setState(() => _openDetail = detail);
      } else {
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: Text(detail.header.subject, maxLines: 1)),
            body: _buildMessageView(detail, inPane: false),
          ),
        ));
        if (mounted) setState(() {});
      }
    } on JmapException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _loadingDetail = false);
    }
  }

  Future<void> _deleteEmail(EmailDetail d) async {
    final trash = _byRole('trash');
    try {
      final inTrash = trash != null && d.header.mailboxIds[trash.id] == true;
      if (trash == null || inTrash) {
        await client.destroyEmail(d.header.id);
      } else {
        await client.moveToMailbox(d.header.id, trash.id);
      }
      if (!mounted) return;
      setState(() {
        _emails.removeWhere((e) => e.id == d.header.id);
        _total = _total > 0 ? _total - 1 : 0;
        if (_openDetail?.header.id == d.header.id) _openDetail = null;
      });
      _toast('Email dihapus.');
    } on JmapException catch (e) {
      _toast(e.message);
    }
  }

  Future<void> _markUnread(EmailDetail d) async {
    try {
      await client.setSeen(d.header.id, false);
      if (!mounted) return;
      setState(() {
        for (final e in _emails) {
          if (e.id == d.header.id) e.seen = false;
        }
        _openDetail = null;
      });
    } on JmapException catch (e) {
      _toast(e.message);
    }
  }

  Future<void> _compose({EmailDetail? replyTo}) async {
    final sent = _byRole('sent');
    if (sent == null) {
      _toast('Folder Sent tidak ditemukan.');
      return;
    }
    final sentOk = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => ComposeScreen(
        client: client,
        sentMailboxId: sent.id,
        replyTo: replyTo,
      ),
    ));
    if (sentOk == true) _toast('Email terkirim ✓');
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _logout() async {
    await AuthStore.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  // ---------- UI ----------

  IconData _mailboxIcon(JmapMailbox m) => switch (m.role) {
        'inbox' => Icons.inbox,
        'drafts' => Icons.edit_note,
        'sent' => Icons.send,
        'junk' => Icons.report_gmailerrorred,
        'trash' => Icons.delete_outline,
        'archive' => Icons.archive_outlined,
        _ => Icons.folder_outlined,
      };

  Widget _buildNav({required bool inDrawer}) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Icon(Icons.water_drop,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(client.username,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
            ],
          ),
        ),
        for (final m in _mailboxes)
          ListTile(
            dense: true,
            selected: _selected?.id == m.id,
            leading: Icon(_mailboxIcon(m)),
            title: Text(m.name, overflow: TextOverflow.ellipsis),
            trailing: m.unreadEmails > 0
                ? Badge(label: Text('${m.unreadEmails}'))
                : null,
            onTap: () {
              if (inDrawer) Navigator.of(context).pop();
              _selectMailbox(m);
            },
          ),
        const Divider(),
        ListTile(
          dense: true,
          leading: const Icon(Icons.logout),
          title: const Text('Keluar'),
          onTap: _logout,
        ),
      ],
    );
  }

  Widget _buildList({required bool wide}) {
    if (_loadingList) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_emails.isEmpty) {
      return const Center(child: Text('Tidak ada email di folder ini.'));
    }
    final hasMore = _emails.length < _total;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        itemCount: _emails.length + (hasMore ? 1 : 0),
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          if (i >= _emails.length) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _loadingMore
                    ? const CircularProgressIndicator()
                    : TextButton(
                        onPressed: _loadMore,
                        child: Text(
                            'Muat lagi (${_emails.length} dari $_total)')),
              ),
            );
          }
          final e = _emails[i];
          final fromText =
              e.from.isNotEmpty ? e.from.first.display : '(tanpa pengirim)';
          final bold = e.seen ? FontWeight.normal : FontWeight.bold;
          final selected = _openDetail?.header.id == e.id;
          return ListTile(
            selected: wide && selected,
            leading: CircleAvatar(
              child: Text(fromText.isNotEmpty
                  ? fromText.characters.first.toUpperCase()
                  : '?'),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(fromText,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: bold)),
                ),
                const SizedBox(width: 8),
                Text(formatDateShort(e.receivedAt),
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(e.subject,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: bold)),
                    ),
                    if (e.hasAttachment)
                      const Icon(Icons.attach_file, size: 14),
                  ],
                ),
                Text(e.preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            onTap: () => _openEmail(e, wide: wide),
          );
        },
      ),
    );
  }

  Widget _buildMessageView(EmailDetail d, {required bool inPane}) {
    return MessageView(
      detail: d,
      client: client,
      onDelete: () {
        _deleteEmail(d);
        if (!inPane) Navigator.of(context).pop();
      },
      onMarkUnread: () {
        _markUnread(d);
        if (!inPane) Navigator.of(context).pop();
      },
      onReply: () => _compose(replyTo: d),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _selected?.name ?? 'H2O Mail';
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 1100;
      final appBar = AppBar(
        title: Text(title),
        actions: [
          if (_loadingDetail)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Center(
                  child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))),
            ),
          IconButton(
              onPressed: _refresh,
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh)),
        ],
      );
      final fab = FloatingActionButton.extended(
        onPressed: () => _compose(),
        icon: const Icon(Icons.edit),
        label: const Text('Tulis'),
      );

      if (!wide) {
        return Scaffold(
          appBar: appBar,
          drawer: Drawer(child: SafeArea(child: _buildNav(inDrawer: true))),
          floatingActionButton: fab,
          body: _buildList(wide: false),
        );
      }

      return Scaffold(
        appBar: appBar,
        floatingActionButton: fab,
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: 250, child: _buildNav(inDrawer: false)),
            const VerticalDivider(width: 1),
            SizedBox(width: 380, child: _buildList(wide: true)),
            const VerticalDivider(width: 1),
            Expanded(
              child: _openDetail == null
                  ? const Center(
                      child: Text('Pilih email untuk dibaca',
                          style: TextStyle(fontSize: 16)))
                  : _buildMessageView(_openDetail!, inPane: true),
            ),
          ],
        ),
      );
    });
  }
}
