import 'dart:async';

import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../widgets.dart';

/// Layar chat "Layanan Pelanggan" untuk pelanggan: ngobrol langsung
/// dengan admin H2O Laundry, bergaya balon pesan WhatsApp.
class LayananPelangganScreen extends StatefulWidget {
  const LayananPelangganScreen({super.key});

  @override
  State<LayananPelangganScreen> createState() =>
      _LayananPelangganScreenState();
}

class _LayananPelangganScreenState extends State<LayananPelangganScreen> {
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    store.addListener(_onStore);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => store.markChatRead());
    // Polling lebih rapat selama layar chat terbuka supaya balasan
    // admin cepat muncul.
    _poll = Timer.periodic(
        const Duration(seconds: 5), (_) => store.refresh());
  }

  /// Balasan baru yang masuk saat layar terbuka langsung ditandai
  /// terbaca (markChatRead tidak melakukan apa pun bila sudah 0).
  void _onStore() => store.markChatRead();

  @override
  void dispose() {
    _poll?.cancel();
    store.removeListener(_onStore);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF6F8),
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            const CircleAvatar(
              radius: 18,
              backgroundColor: Color(0xFFB3E3F0),
              child: Icon(Icons.support_agent,
                  color: Color(0xFF0E7490), size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Layanan Pelanggan',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800)),
                  Text('H2O Laundry Parakan',
                      style: TextStyle(
                          fontSize: 11.5,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) => Column(
            children: [
              Expanded(
                child: store.chat.isEmpty
                    ? const _ChatGreeting()
                    : ListView.builder(
                        reverse: true,
                        padding:
                            const EdgeInsets.fromLTRB(14, 14, 14, 8),
                        itemCount: store.chat.length,
                        itemBuilder: (context, i) {
                          final m =
                              store.chat[store.chat.length - 1 - i];
                          return ChatBubble(
                              text: m.text,
                              at: m.at,
                              mine: !m.fromAdmin,
                              senderLabel: m.fromAdmin
                                  ? (m.adminName.isEmpty
                                      ? 'Admin'
                                      : m.adminName)
                                  : '');
                        },
                      ),
              ),
              ChatInputBar(onSend: store.sendChat),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sapaan saat belum ada pesan sama sekali.
class _ChatGreeting extends StatelessWidget {
  const _ChatGreeting();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircleAvatar(
              radius: 34,
              backgroundColor: Color(0xFFB3E3F0),
              child: Icon(Icons.support_agent,
                  size: 38, color: Color(0xFF0E7490)),
            ),
            const SizedBox(height: 16),
            const Text('Halo! Ada yang bisa kami bantu? 😊',
                textAlign: TextAlign.center,
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              'Tulis pertanyaan Anda di bawah — tim H2O Laundry '
              'akan segera membalas di sini.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// Balon pesan chat. [mine] = pesan pengirim di sisi kanan.
class ChatBubble extends StatelessWidget {
  const ChatBubble(
      {super.key,
      required this.text,
      required this.at,
      required this.mine,
      this.senderLabel = ''});

  final String text;
  final DateTime at;
  final bool mine;
  final String senderLabel;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(mine ? 16 : 4),
      bottomRight: Radius.circular(mine ? 4 : 16),
    );
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(13, 9, 13, 7),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.76),
        decoration: BoxDecoration(
          color: mine ? const Color(0xFF0E7490) : Colors.white,
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 1)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!mine && senderLabel.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(senderLabel,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0E7490))),
              ),
            Text(text,
                style: TextStyle(
                    fontSize: 14.5,
                    height: 1.35,
                    color: mine ? Colors.white : const Color(0xFF1E293B))),
            const SizedBox(height: 2),
            Text(timeAgo(at),
                style: TextStyle(
                    fontSize: 10,
                    color: mine
                        ? Colors.white70
                        : Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

/// Baris input pesan + tombol kirim. [onSend] mengembalikan pesan
/// error (null = sukses) — pola yang sama dengan metode store.
class ChatInputBar extends StatefulWidget {
  const ChatInputBar({super.key, required this.onSend});

  final Future<String?> Function(String text) onSend;

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final _ctrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final err = await widget.onSend(text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (err == null) {
      _ctrl.clear();
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Tulis pesan…',
                isDense: true,
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 11),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none),
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            tooltip: 'Kirim',
            onPressed: _sending ? null : _send,
            icon: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_rounded),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------ Sisi admin (pemilik)

/// Kotak masuk Layanan Pelanggan untuk pemilik: daftar utas per
/// pelanggan dengan jumlah pesan belum dibaca.
class ChatInboxScreen extends StatefulWidget {
  const ChatInboxScreen({super.key});

  @override
  State<ChatInboxScreen> createState() => _ChatInboxScreenState();
}

class _ChatInboxScreenState extends State<ChatInboxScreen> {
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(
        const Duration(seconds: 6), (_) => store.refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Layanan Pelanggan')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) {
            // Kelompokkan pesan per pelanggan; urutkan utas terbaru dulu.
            final byPhone = <String, List<ChatMessage>>{};
            for (final m in store.allChats) {
              byPhone.putIfAbsent(m.phone, () => []).add(m);
            }
            final threads = byPhone.values.toList()
              ..sort((a, b) => b.last.at.compareTo(a.last.at));
            if (threads.isEmpty) {
              return const Center(
                child: EmptyState(
                    icon: Icons.support_agent,
                    message: 'Belum ada pesan dari pelanggan.'),
              );
            }
            return ListView.separated(
              itemCount: threads.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, indent: 72),
              itemBuilder: (context, i) {
                final msgs = threads[i];
                final last = msgs.last;
                final name = msgs
                    .lastWhere((m) => !m.fromAdmin, orElse: () => last)
                    .name;
                final unread = msgs
                    .where((m) => !m.fromAdmin && !m.readByAdmin)
                    .length;
                return ListTile(
                  leading: CircleAvatar(
                    radius: 22,
                    backgroundColor: const Color(0xFFB3E3F0),
                    child: Text(
                        name.isEmpty ? '?' : name[0].toUpperCase(),
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0E7490))),
                  ),
                  title: Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: unread > 0
                              ? FontWeight.w800
                              : FontWeight.w600)),
                  subtitle: Text(
                    last.fromAdmin ? 'Anda: ${last.text}' : last.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: unread > 0
                            ? FontWeight.w600
                            : FontWeight.w400),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(timeAgo(last.at),
                          style: theme.textTheme.bodySmall),
                      const SizedBox(height: 4),
                      if (unread > 0)
                        Badge.count(count: unread)
                      else
                        const SizedBox(height: 16),
                    ],
                  ),
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => ChatRoomScreen(
                              phone: last.phone, name: name))),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// Ruang chat pemilik dengan satu pelanggan.
class ChatRoomScreen extends StatefulWidget {
  const ChatRoomScreen(
      {super.key, required this.phone, required this.name});

  final String phone;
  final String name;

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    store.addListener(_onStore);
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => store.adminMarkChatRead(widget.phone));
    _poll = Timer.periodic(
        const Duration(seconds: 5), (_) => store.refresh());
  }

  void _onStore() => store.adminMarkChatRead(widget.phone);

  @override
  void dispose() {
    _poll?.cancel();
    store.removeListener(_onStore);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF6F8),
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFFB3E3F0),
              child: Text(
                  widget.name.isEmpty
                      ? '?'
                      : widget.name[0].toUpperCase(),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0E7490))),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800)),
                  Text('+${widget.phone}',
                      style: TextStyle(
                          fontSize: 11.5,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) {
            final msgs = store.allChats
                .where((m) => m.phone == widget.phone)
                .toList();
            return Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                    itemCount: msgs.length,
                    itemBuilder: (context, i) {
                      final m = msgs[msgs.length - 1 - i];
                      return ChatBubble(
                          text: m.text,
                          at: m.at,
                          mine: m.fromAdmin,
                          senderLabel: m.fromAdmin ? '' : m.name);
                    },
                  ),
                ),
                ChatInputBar(
                    onSend: (t) => store.adminSendChat(widget.phone, t)),
              ],
            );
          },
        ),
      ),
    );
  }
}
