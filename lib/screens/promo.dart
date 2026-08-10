import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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
                    itemCount: store.posts.length,
                    itemBuilder: (context, i) => Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: PromoCard(post: store.posts[i]),
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
    final bgPost =
        PromoBg.isColored(post.bgStyle) && post.imageUrl.isEmpty;
    final canLike = store.role == 'customer' && store.online;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Flexible(
                        child: Text(
                          'H2O Laundry',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 14.5),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.verified,
                          size: 15, color: Color(0xFF06B6D4)),
                      const SizedBox(width: 6),
                      Text('· ${timeAgo(post.createdAt)}',
                          style: TextStyle(color: muted, fontSize: 12.5)),
                      const Spacer(),
                      if (isOwner)
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
                    if (post.imageUrl.isNotEmpty) ...[
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

/// Pilihan reaksi emoji — harus sama dengan daftar REACTIONS di server.
const kReactionEmojis = ['❤️', '👍', '🔥', '🎉', '😂', '😮'];

/// Tombol reaksi pos: ketuk untuk memilih emoji (bukan hanya hati).
/// Menampilkan reaksi milik sendiri + ringkasan emoji terbanyak.
class _ReactionChip extends StatefulWidget {
  const _ReactionChip({required this.post, required this.enabled});

  final PromoPost post;
  final bool enabled;

  @override
  State<_ReactionChip> createState() => _ReactionChipState();
}

class _ReactionChipState extends State<_ReactionChip> {
  Offset _tapPos = Offset.zero;

  Future<void> _pick() async {
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final chosen = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        _tapPos.dx,
        _tapPos.dy - 64,
        overlay.size.width - _tapPos.dx,
        overlay.size.height - _tapPos.dy,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      color: Colors.white,
      items: [
        PopupMenuItem<String>(
          enabled: false,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final e in kReactionEmojis)
                InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => Navigator.pop(context, e),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: widget.post.myReaction == e
                        ? BoxDecoration(
                            color: const Color(0xFFE0F5FA),
                            borderRadius: BorderRadius.circular(999))
                        : null,
                    child: Text(e, style: const TextStyle(fontSize: 24)),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
    // Memilih emoji yang sama dengan reaksi saat ini = menghapusnya
    // (ditangani reactPromo).
    if (chosen != null) await store.reactPromo(widget.post, chosen);
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final summary = post.reactions.take(3).map((r) => r.emoji).join();
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTapDown: (d) => _tapPos = d.globalPosition,
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
  String _bg = '';
  XFile? _image;
  bool _busy = false;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final x = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 1280, imageQuality: 78);
    if (x != null) setState(() => _image = x);
  }

  Future<void> _submit() async {
    if (_busy) return;
    final caption = _caption.text.trim();
    if (caption.isEmpty && _image == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Tulis sesuatu atau pilih foto dulu.')));
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
    final error = await store.createPromo(
        caption: caption,
        bgStyle: _image == null ? _bg : '',
        imageBase64: imageBase64,
        imageExt: imageExt);
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
      appBar: AppBar(title: const Text('Buat Promo')),
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
                if (_image == null) ...[
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
                OutlinedButton.icon(
                  onPressed: _busy ? null : _pickImage,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(
                      _image == null ? 'Tambahkan Foto' : 'Ganti Foto'),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _busy ? null : _submit,
                  icon: const Icon(Icons.campaign_outlined),
                  label: Text(_busy ? 'Mengunggah...' : 'Posting Promo'),
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
