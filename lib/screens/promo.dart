import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../widgets.dart';

/// Layar feed Info & Promo untuk pelanggan (semua pos).
class PromoFeedScreen extends StatelessWidget {
  const PromoFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Info & Promo')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) => RefreshIndicator(
            onRefresh: () async => store.refresh(),
            child: store.posts.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 120),
                      EmptyState(
                          icon: Icons.campaign_outlined,
                          message: 'Belum ada info atau promo.'),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: store.posts.length + 1,
                    itemBuilder: (context, i) => Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: i == 0
                            ? const ReelsStrip()
                            : PromoCard(post: store.posts[i - 1]),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Layar pemilik: kelola semua pos promo (buat & hapus).
class PromoManageScreen extends StatelessWidget {
  const PromoManageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Info & Promo')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const PromoComposeScreen())),
        icon: const Icon(Icons.add),
        label: const Text('Buat Promo'),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) => RefreshIndicator(
            onRefresh: () async => store.refresh(),
            child: store.posts.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 120),
                      EmptyState(
                          icon: Icons.campaign_outlined,
                          message: 'Belum ada promo. Ketuk "Buat Promo" '
                              'untuk membuat yang pertama!'),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                    itemCount: store.posts.length,
                    itemBuilder: (context, i) => Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child:
                            PromoCard(post: store.posts[i], isOwner: true),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Feed "Info & Promo" — versi laundry dari Mingle di wca_app:
/// pemilik memposting promo (teks berlatar warna atau foto),
/// pelanggan menyukai dan berkomentar.

/// Latar pos teks berwarna, disalin dari MingleBg wca_app.
/// Kuncinya tersimpan di server agar semua perangkat merender sama.
class PromoBg {
  PromoBg._();

  static const List<String> keys = [
    '', 'ocean', 'sunset', 'night', 'candy', 'teal',
  ];

  static BoxDecoration decorationFor(String key) {
    switch (key) {
      case 'teal':
        return const BoxDecoration(color: Color(0xFF00A896));
      case 'sunset':
        return const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFF6A00), Color(0xFFEE0979)],
          ),
        );
      case 'ocean':
        return const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2193B0), Color(0xFF6DD5ED)],
          ),
        );
      case 'night':
        return const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
          ),
        );
      case 'candy':
        return const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFF9A9E), Color(0xFFA18CD1)],
          ),
        );
      default:
        return const BoxDecoration();
    }
  }

  static bool isColored(String key) => key.isNotEmpty && keys.contains(key);
}

/// Kartu pos promo bergaya Mingle (cuit): avatar kiri, nama + waktu,
/// isi, lalu baris aksi tipis di bawah.
class PromoCard extends StatelessWidget {
  const PromoCard({super.key, required this.post, this.isOwner = false});

  final PromoPost post;
  final bool isOwner;

  Future<void> _confirmDelete(BuildContext context) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus promo?'),
        content: const Text(
            'Pos ini beserta suka dan komentarnya akan dihapus.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (yes == true) await store.deletePromo(post);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final bgPost = PromoBg.isColored(post.bgStyle) &&
        post.imageUrl.isEmpty &&
        post.videoUrl.isEmpty &&
        post.linkUrl.isEmpty;
    final canLike = store.role == 'customer' && store.online;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (post.byAdmin)
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF06B6D4), Color(0xFF0E7490)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Icon(Icons.local_laundry_service,
                    color: Colors.white, size: 22),
              )
            else
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFFB3E3F0),
                child: Text(
                  post.authorName.isEmpty
                      ? '?'
                      : post.authorName[0].toUpperCase(),
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0E7490)),
                ),
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          post.byAdmin ? 'H2O Laundry' : post.authorName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 14.5),
                        ),
                      ),
                      if (post.byAdmin) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified,
                            size: 15, color: Color(0xFF06B6D4)),
                      ],
                      const SizedBox(width: 6),
                      Text('· ${timeAgo(post.createdAt)}',
                          style: TextStyle(color: muted, fontSize: 12.5)),
                      const Spacer(),
                      if (isOwner || post.mine)
                        GestureDetector(
                          onTap: () => _confirmDelete(context),
                          child: Icon(Icons.delete_outline,
                              size: 19, color: muted),
                        ),
                    ],
                  ),
                  if (bgPost) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(minHeight: 170),
                        decoration: PromoBg.decorationFor(post.bgStyle),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 28),
                        alignment: Alignment.center,
                        child: Text(
                          post.caption,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: post.caption.length > 90 ? 17 : 22,
                            fontWeight: FontWeight.w800,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    if (post.caption.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(post.caption,
                          style:
                              const TextStyle(fontSize: 14.5, height: 1.35)),
                    ],
                    // Foto berdiri sendiri hanya bila bukan pos tautan,
                    // atau tautan sudah punya gambar unggulannya sendiri
                    // (foto admin dipakai kartu tautan bila og:image absen).
                    if (post.imageUrl.isNotEmpty &&
                        (post.linkUrl.isEmpty ||
                            post.linkImage.isNotEmpty)) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 340),
                          child: Image.network(
                            store.mediaUrl(post.imageUrl),
                            width: double.infinity,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, p) => p == null
                                ? child
                                : Container(
                                    height: 180,
                                    color: const Color(0xFFE8F1F5),
                                    child: const Center(
                                        child:
                                            CircularProgressIndicator()),
                                  ),
                            errorBuilder: (context, _, _) => Container(
                              height: 120,
                              color: const Color(0xFFE8F1F5),
                              child: Icon(Icons.broken_image_outlined,
                                  color: muted),
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (post.videoUrl.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _VideoTeaser(post: post),
                    ],
                    if (post.linkUrl.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _LinkCard(post: post),
                    ],
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _ReactionChip(post: post, enabled: canLike),
                      const SizedBox(width: 18),
                      _ActionChip(
                        icon: Icons.mode_comment_outlined,
                        color: muted,
                        label: '${post.comments.length}',
                        onTap: () => showPromoComments(context, post.id),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kartu tautan gaya Mingle: gambar unggulan + judul + domain,
/// diketuk untuk membuka tautannya.
class _LinkCard extends StatelessWidget {
  const _LinkCard({required this.post});

  final PromoPost post;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final featured =
        post.linkImage.isNotEmpty ? post.linkImage : post.imageUrl;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        // Tautan lama bisa saja tersimpan tanpa skema; lengkapi agar
        // tetap bisa dibuka.
        final raw = post.linkUrl.startsWith('http')
            ? post.linkUrl
            : 'https://${post.linkUrl}';
        final uri = Uri.tryParse(raw);
        if (uri == null) return;
        var ok = false;
        try {
          ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (_) {}
        if (!ok) {
          try {
            ok = await launchUrl(uri);
          } catch (_) {}
        }
        if (!ok && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Tidak bisa membuka $raw')));
        }
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black12),
          borderRadius: BorderRadius.circular(14),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (featured.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: Image.network(
                  store.mediaUrl(featured),
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, _, _) =>
                      const SizedBox.shrink(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.linkTitle.isNotEmpty
                        ? post.linkTitle
                        : post.linkUrl,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13.5),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.link, size: 13, color: muted),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          post.linkHost.isNotEmpty
                              ? post.linkHost
                              : post.linkUrl,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11.5, color: muted),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pilihan reaksi emoji — harus sama dengan daftar REACTIONS di server.
const kReactionEmojis = ['❤️', '👍', '🔥', '🎉', '😂', '😮'];

/// Tombol reaksi pos: ketuk untuk memilih emoji (bukan hanya hati).
/// Menampilkan reaksi milik sendiri + ringkasan emoji terbanyak.
class _ReactionChip extends StatefulWidget {
  const _ReactionChip(
      {required this.post, required this.enabled, this.light = false});

  final PromoPost post;
  final bool enabled;

  /// true = teks/ikon putih (overlay video reels).
  final bool light;

  @override
  State<_ReactionChip> createState() => _ReactionChipState();
}

class _ReactionChipState extends State<_ReactionChip> {
  Future<void> _pick() async {
    // Jangkarkan gelembung emoji tepat di atas tombol ini.
    final box = context.findRenderObject() as RenderBox;
    final anchor = box.localToGlobal(Offset(box.size.width / 2, 0));
    final chosen = await showDialog<String>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (dialog) {
        final size = MediaQuery.of(dialog).size;
        const bubbleWidth = 6 * 44.0 + 16;
        final left =
            (anchor.dx - bubbleWidth / 2).clamp(8.0, size.width - bubbleWidth - 8.0);
        var top = anchor.dy - 68;
        if (top < 8) top = anchor.dy + 24;
        return Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              child: Material(
                elevation: 10,
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final e in kReactionEmojis)
                        InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: () => Navigator.pop(dialog, e),
                          child: Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            decoration: widget.post.myReaction == e
                                ? BoxDecoration(
                                    color: const Color(0xFFE0F5FA),
                                    borderRadius:
                                        BorderRadius.circular(999))
                                : null,
                            child: Text(e,
                                style: const TextStyle(fontSize: 25)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
    // Memilih emoji yang sama dengan reaksi saat ini = menghapusnya
    // (ditangani reactPromo).
    if (chosen == null || !mounted) return;
    final error = await store.reactPromo(widget.post, chosen);
    if (error != null && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final muted = widget.light
        ? Colors.white
        : Theme.of(context).colorScheme.onSurfaceVariant;
    // Emoji milik sendiri sudah tampil sebagai ikon tombol — jangan
    // diulang di ringkasan (mencegah "🔥 🔥 1").
    final summary = post.reactions
        .where((r) => r.emoji != post.myReaction)
        .take(3)
        .map((r) => r.emoji)
        .join();
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: widget.enabled ? _pick : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          children: [
            post.myReaction.isNotEmpty
                ? Text(post.myReaction,
                    style: const TextStyle(fontSize: 17))
                : Icon(Icons.favorite_border, size: 19, color: muted),
            const SizedBox(width: 5),
            Text(
              post.reactionCount == 0
                  ? '0'
                  : summary.isEmpty
                      ? '${post.reactionCount}'
                      : '$summary ${post.reactionCount}',
              style: TextStyle(color: muted, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.color,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 19, color: color),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(color: color, fontSize: 12.5)),
          ],
        ),
      ),
    );
  }
}

/// Lembar komentar gaya Mingle: daftar komentar + kolom tulis.
void showPromoComments(BuildContext context, String postId) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (sheet) => Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(sheet).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(sheet).size.height * 0.7,
        child: _CommentsSheet(postId: postId),
      ),
    ),
  );
}

class _CommentsSheet extends StatefulWidget {
  const _CommentsSheet({required this.postId});

  final String postId;

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  bool _busy = false;

  /// Komentar yang sedang dibalas ('' = komentar utama baru).
  String _replyToId = '';
  String _replyToName = '';

  /// Emoji cepat untuk kolom komentar.
  static const _quickEmojis = [
    '😀', '😂', '🤩', '❤️', '👍', '🙏', '🔥', '🎉', '😍', '😮', '🥳', '✨',
  ];

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  PromoPost? get _post {
    for (final p in store.posts) {
      if (p.id == widget.postId) return p;
    }
    return null;
  }

  void _startReply(PromoComment c) {
    setState(() {
      // Balasan selalu menempel ke komentar utama (satu tingkat),
      // tapi nama yang dibalas tetap nama penulis aslinya.
      _replyToId = c.replyTo.isEmpty ? c.id : c.replyTo;
      _replyToName = c.name;
    });
    _focus.requestFocus();
  }

  void _insertEmoji(String e) {
    _text.text += e;
    _text.selection = TextSelection.collapsed(offset: _text.text.length);
    _focus.requestFocus();
  }

  Future<void> _send() async {
    final post = _post;
    final text = _text.text.trim();
    if (post == null || text.isEmpty || _busy) return;
    setState(() => _busy = true);
    final error =
        await store.addPromoComment(post, text, replyTo: _replyToId);
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    _text.clear();
    setState(() {
      _replyToId = '';
      _replyToName = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOwner = store.role == 'owner';
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final post = _post;
        final comments = post?.comments ?? const <PromoComment>[];

        // Susun utas: komentar utama diikuti balasannya (menjorok).
        // Balasan yang induknya sudah dihapus tampil sebagai utama.
        final parents =
            comments.where((c) => c.replyTo.isEmpty).toList();
        final replies = <String, List<PromoComment>>{};
        final orphans = <PromoComment>[];
        for (final c in comments) {
          if (c.replyTo.isEmpty) continue;
          if (parents.any((p0) => p0.id == c.replyTo)) {
            replies.putIfAbsent(c.replyTo, () => []).add(c);
          } else {
            orphans.add(c);
          }
        }
        final rows = <({PromoComment c, bool isReply})>[];
        for (final p0 in parents) {
          rows.add((c: p0, isReply: false));
          for (final r in replies[p0.id] ?? const <PromoComment>[]) {
            rows.add((c: r, isReply: true));
          }
        }
        for (final o in orphans) {
          rows.add((c: o, isReply: false));
        }

        return Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 12),
            Text('Komentar (${comments.length})',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const Divider(height: 20),
            Expanded(
              child: rows.isEmpty
                  ? Center(
                      child: Text('Belum ada komentar. Jadilah yang pertama!',
                          style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 13)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: rows.length,
                      itemBuilder: (context, i) => _commentRow(
                          theme, post, rows[i].c, rows[i].isReply, isOwner),
                    ),
            ),
            // Baris emoji cepat.
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final e in _quickEmojis)
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _insertEmoji(e),
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 6),
                        child: Center(
                            child: Text(e,
                                style: const TextStyle(fontSize: 22))),
                      ),
                    ),
                ],
              ),
            ),
            if (_replyToId.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 4),
                child: Row(
                  children: [
                    Icon(Icons.reply,
                        size: 15,
                        color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Membalas $_replyToName',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () => setState(() {
                        _replyToId = '';
                        _replyToName = '';
                      }),
                    ),
                  ],
                ),
              ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 8, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _text,
                        focusNode: _focus,
                        minLines: 1,
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: _replyToId.isEmpty
                              ? 'Tulis komentar...'
                              : 'Tulis balasan...',
                          isDense: true,
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    IconButton(
                      onPressed: _busy ? null : _send,
                      icon: Icon(Icons.send_rounded,
                          color: theme.colorScheme.primary),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _commentRow(ThemeData theme, PromoPost? post, PromoComment c,
      bool isReply, bool isOwner) {
    final muted = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: EdgeInsets.only(bottom: 12, left: isReply ? 36 : 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: isReply ? 13 : 16,
            backgroundColor: c.byAdmin
                ? const Color(0xFF0E7490)
                : const Color(0xFFB3E3F0),
            child: c.byAdmin
                ? Icon(Icons.local_laundry_service,
                    size: isReply ? 13 : 16, color: Colors.white)
                : Text(
                    c.name.isEmpty ? '?' : c.name[0].toUpperCase(),
                    style: TextStyle(
                        fontSize: isReply ? 11 : 13,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0E7490)),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(c.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                    if (c.byAdmin) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F5FA),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text('Admin',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0E7490))),
                      ),
                    ],
                    const SizedBox(width: 6),
                    Text(timeAgo(c.at),
                        style: TextStyle(color: muted, fontSize: 11)),
                  ],
                ),
                if (isReply && c.replyToName.isNotEmpty)
                  Text('membalas ${c.replyToName}',
                      style: TextStyle(color: muted, fontSize: 11)),
                const SizedBox(height: 2),
                Text(c.text,
                    style: const TextStyle(fontSize: 13.5, height: 1.3)),
                if (store.online)
                  InkWell(
                    onTap: () => _startReply(c),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text('Balas',
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.primary)),
                    ),
                  ),
              ],
            ),
          ),
          if (post != null && (c.mine || isOwner))
            GestureDetector(
              onTap: () => store.deletePromoComment(post, c),
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(Icons.delete_outline, size: 17, color: muted),
              ),
            ),
        ],
      ),
    );
  }
}

/// Layar pemilik untuk membuat pos promo: tulis teks, pilih latar
/// warna (gaya Mingle) atau lampirkan foto.
class PromoComposeScreen extends StatefulWidget {
  const PromoComposeScreen({super.key});

  @override
  State<PromoComposeScreen> createState() => _PromoComposeScreenState();
}

class _PromoComposeScreenState extends State<PromoComposeScreen> {
  final _caption = TextEditingController();
  final _link = TextEditingController();
  String _bg = '';
  XFile? _image;
  XFile? _video;
  int _videoBytes = 0;
  bool _busy = false;

  @override
  void dispose() {
    _caption.dispose();
    _link.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final x = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 1280, imageQuality: 78);
    if (x != null) {
      setState(() {
        _image = x;
        _video = null;
      });
    }
  }

  Future<void> _pickVideo() async {
    final x = await ImagePicker().pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 90));
    if (x == null) return;
    final len = await x.length();
    if (len > 30 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Video maksimal 30 MB (kira-kira 60-90 '
                'detik). Pilih video yang lebih pendek.')));
      }
      return;
    }
    setState(() {
      _video = x;
      _videoBytes = len;
      _image = null;
    });
  }

  Future<void> _submit() async {
    if (_busy) return;
    final caption = _caption.text.trim();
    final link = _link.text.trim();
    if (caption.isEmpty &&
        _image == null &&
        _video == null &&
        link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Tulis sesuatu atau pilih foto/video dulu.')));
      return;
    }
    setState(() => _busy = true);
    String? imageBase64;
    String? imageExt;
    if (_image != null) {
      final bytes = await _image!.readAsBytes();
      imageBase64 = base64Encode(bytes);
      final name = _image!.name.toLowerCase();
      imageExt = name.endsWith('.png')
          ? 'png'
          : name.endsWith('.webp')
              ? 'webp'
              : 'jpg';
    }
    String? videoBase64;
    String? videoExt;
    if (_video != null) {
      final bytes = await _video!.readAsBytes();
      videoBase64 = base64Encode(bytes);
      final name = _video!.name.toLowerCase();
      videoExt = name.endsWith('.webm')
          ? 'webm'
          : name.endsWith('.mov')
              ? 'mov'
              : name.endsWith('.m4v')
                  ? 'm4v'
                  : 'mp4';
    }
    final error = await store.createPromo(
        caption: caption,
        bgStyle: _image == null && _video == null ? _bg : '',
        link: link,
        imageBase64: imageBase64,
        imageExt: imageExt,
        videoBase64: videoBase64,
        videoExt: videoExt);
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colored = _image == null && PromoBg.isColored(_bg);
    return Scaffold(
      appBar: AppBar(
          title: Text(
              store.role == 'owner' ? 'Buat Promo' : 'Buat Postingan')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (colored)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 190),
                      decoration: PromoBg.decorationFor(_bg),
                      padding: const EdgeInsets.all(18),
                      alignment: Alignment.center,
                      child: TextField(
                        controller: _caption,
                        maxLines: null,
                        maxLength: 300,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w800),
                        cursorColor: Colors.white,
                        decoration: const InputDecoration(
                          hintText: 'Tulis promo Anda...',
                          hintStyle: TextStyle(color: Colors.white70),
                          counterStyle: TextStyle(color: Colors.white70),
                          filled: false,
                          border: InputBorder.none,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  )
                else
                  TextField(
                    controller: _caption,
                    minLines: 3,
                    maxLines: 8,
                    maxLength: 300,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText:
                          'Tulis promo atau info untuk pelanggan...',
                    ),
                  ),
                const SizedBox(height: 14),
                TextField(
                  controller: _link,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Tautan (opsional)',
                    hintText: 'https://...',
                    helperText:
                        'Kartu tautan dengan gambar & judul otomatis',
                    prefixIcon: Icon(Icons.link),
                  ),
                ),
                const SizedBox(height: 14),
                if (_image == null && _video == null) ...[
                  Text('Latar warna (untuk pos teks)',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: PromoBg.keys.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final key = PromoBg.keys[i];
                        final selected = _bg == key;
                        return GestureDetector(
                          onTap: () => setState(() => _bg = key),
                          child: Container(
                            width: 44,
                            decoration: (key.isEmpty
                                    ? BoxDecoration(
                                        color: const Color(0xFFEDF2F5))
                                    : PromoBg.decorationFor(key))
                                .copyWith(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selected
                                    ? theme.colorScheme.primary
                                    : Colors.black12,
                                width: selected ? 2.5 : 1,
                              ),
                            ),
                            child: key.isEmpty
                                ? const Icon(Icons.format_color_reset,
                                    size: 18, color: Colors.grey)
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                if (_image != null) ...[
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: FutureBuilder(
                          future: _image!.readAsBytes(),
                          builder: (context, snap) => snap.hasData
                              ? Image.memory(snap.data!,
                                  width: double.infinity,
                                  height: 220,
                                  fit: BoxFit.cover)
                              : const SizedBox(height: 220),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: IconButton.filled(
                          onPressed: () => setState(() => _image = null),
                          icon: const Icon(Icons.close, size: 18),
                          style: IconButton.styleFrom(
                              backgroundColor: Colors.black54),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],
                if (_video != null) ...[
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.movie_outlined),
                      title: Text(_video!.name,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                          '${(_videoBytes / (1024 * 1024)).toStringAsFixed(1)} MB — tampil di Reels'),
                      trailing: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _video = null),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _pickImage,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: Text(
                            _image == null ? 'Foto' : 'Ganti Foto'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _pickVideo,
                        icon: const Icon(Icons.video_library_outlined),
                        label: Text(
                            _video == null ? 'Video Reel' : 'Ganti Video'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _busy ? null : _submit,
                  icon: const Icon(Icons.campaign_outlined),
                  label: Text(_busy
                      ? (_video != null
                          ? 'Mengunggah video... (bisa 1-2 menit)'
                          : 'Mengunggah...')
                      : (store.role == 'owner'
                          ? 'Posting Promo'
                          : 'Posting')),
                  style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pratinjau video di kartu feed: kotak gelap dengan tombol putar —
/// diketuk untuk menonton di layar Reels.
class _VideoTeaser extends StatelessWidget {
  const _VideoTeaser({required this.post});

  final PromoPost post;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ReelsScreen(initialPostId: post.id))),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 190,
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF203A43), Color(0xFF0F2027)],
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            fit: StackFit.expand,
            children: [
              if (post.videoThumbUrl.isNotEmpty)
                Image.network(
                  store.mediaUrl(post.videoThumbUrl),
                  fit: BoxFit.cover,
                  errorBuilder: (context, _, _) =>
                      const SizedBox.shrink(),
                ),
              Center(
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 40),
                ),
              ),
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.movie_outlined,
                          size: 13, color: Colors.white),
                      SizedBox(width: 4),
                      Text('Reel',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Strip Reels: ubin video yang bisa digulir mendatar, tampil di
/// bawah judul Info & Promo. Diketuk untuk membuka layar Reels.
class ReelsStrip extends StatelessWidget {
  const ReelsStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final reels =
        store.posts.where((p) => p.videoUrl.isNotEmpty).toList();
    if (reels.isEmpty) return const SizedBox.shrink();
    return Container(
      height: 150,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: reels.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final p = reels[i];
          return InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ReelsScreen(initialPostId: p.id))),
            child: Container(
              width: 104,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF2C5364), Color(0xFF0F2027)],
                ),
                borderRadius: BorderRadius.circular(14),
                image: p.videoThumbUrl.isNotEmpty
                    ? DecorationImage(
                        image:
                            NetworkImage(store.mediaUrl(p.videoThumbUrl)),
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(
                            Colors.black.withValues(alpha: 0.35),
                            BlendMode.darken),
                      )
                    : null,
              ),
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 24),
                  ),
                  const Spacer(),
                  Text(
                    p.caption.isEmpty ? 'Reel H2O' : p.caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        height: 1.25),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Layar Reels: video vertikal layar penuh, geser atas/bawah untuk
/// ganti video — gaya reels wca_app.
class ReelsScreen extends StatefulWidget {
  const ReelsScreen({super.key, this.initialPostId = ''});

  final String initialPostId;

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  PageController? _page;
  int _current = 0;

  List<PromoPost> get _reels =>
      store.posts.where((p) => p.videoUrl.isNotEmpty).toList();

  @override
  void initState() {
    super.initState();
    final reels = _reels;
    final i = reels.indexWhere((p) => p.id == widget.initialPostId);
    _current = i < 0 ? 0 : i;
    _page = PageController(initialPage: _current);
  }

  @override
  void dispose() {
    _page?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final reels = _reels;
          return Stack(
            children: [
              if (reels.isEmpty)
                const Center(
                  child: Text('Belum ada video reel.',
                      style: TextStyle(color: Colors.white70)),
                )
              else
                PageView.builder(
                  controller: _page,
                  scrollDirection: Axis.vertical,
                  onPageChanged: (i) => setState(() => _current = i),
                  itemCount: reels.length,
                  itemBuilder: (context, i) => _ReelPage(
                    key: ValueKey(reels[i].id),
                    post: reels[i],
                    active: i == _current,
                  ),
                ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back,
                            color: Colors.white),
                        style: IconButton.styleFrom(
                            backgroundColor: Colors.black38),
                      ),
                      const SizedBox(width: 8),
                      const Text('Reels',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16)),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ReelPage extends StatefulWidget {
  const _ReelPage({super.key, required this.post, required this.active});

  final PromoPost post;
  final bool active;

  @override
  State<_ReelPage> createState() => _ReelPageState();
}

class _ReelPageState extends State<_ReelPage> {
  VideoPlayerController? _c;

  /// Web memblokir autoplay bersuara — mulai bisu di web, ada tombol
  /// pengeras suara untuk menyalakannya.
  bool _muted = kIsWeb;

  @override
  void initState() {
    super.initState();
    final c = VideoPlayerController.networkUrl(
        Uri.parse(store.mediaUrl(widget.post.videoUrl)));
    _c = c;
    c.setLooping(true);
    c.initialize().then((_) {
      if (!mounted) return;
      c.setVolume(_muted ? 0 : 1);
      if (widget.active) c.play();
      setState(() {});
    }).catchError((Object e) {
      debugPrint('REEL ERROR: $e');
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant _ReelPage old) {
    super.didUpdateWidget(old);
    final c = _c;
    if (c == null || !c.value.isInitialized) return;
    if (widget.active && !old.active) {
      c.seekTo(Duration.zero);
      c.play();
    } else if (!widget.active && old.active) {
      c.pause();
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    final c = _c;
    if (c == null || !c.value.isInitialized) return;
    setState(() {
      c.value.isPlaying ? c.pause() : c.play();
    });
  }

  void _toggleMute() {
    final c = _c;
    if (c == null) return;
    setState(() {
      _muted = !_muted;
      c.setVolume(_muted ? 0 : 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final ready = c != null && c.value.isInitialized;
    final canLike = store.role == 'customer' && store.online;
    return GestureDetector(
      onTap: _togglePlay,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (ready)
            Center(
              child: AspectRatio(
                aspectRatio: c.value.aspectRatio == 0
                    ? 9 / 16
                    : c.value.aspectRatio,
                child: VideoPlayer(c),
              ),
            )
          else
            const Center(
                child: CircularProgressIndicator(color: Colors.white)),
          if (ready && !c.value.isPlaying)
            Center(
              child: Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  color: Colors.black38,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow_rounded,
                    color: Colors.white, size: 52),
              ),
            ),
          // Overlay bawah: keterangan + aksi.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 40, 16, 18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                            widget.post.byAdmin
                                ? 'H2O Laundry'
                                : widget.post.authorName,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 14)),
                        if (widget.post.byAdmin) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified,
                              size: 14, color: Color(0xFF06B6D4)),
                        ],
                        const SizedBox(width: 6),
                        Text('· ${timeAgo(widget.post.createdAt)}',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                    if (widget.post.caption.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        widget.post.caption,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            height: 1.3),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _ReactionChip(
                            post: widget.post,
                            enabled: canLike,
                            light: true),
                        const SizedBox(width: 18),
                        _ActionChip(
                          icon: Icons.mode_comment_outlined,
                          color: Colors.white,
                          label: '${widget.post.comments.length}',
                          onTap: () => showPromoComments(
                              context, widget.post.id),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: _toggleMute,
                          icon: Icon(
                            _muted
                                ? Icons.volume_off
                                : Icons.volume_up,
                            color: Colors.white,
                          ),
                          style: IconButton.styleFrom(
                              backgroundColor: Colors.black38),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
