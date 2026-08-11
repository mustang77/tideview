import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../widgets.dart';
import 'promo.dart';

/// Kisi mini postingan (3 kolom) untuk layar profil — video membuka
/// Reels, foto/teks membuka komentar posnya.
class PostMiniGrid extends StatelessWidget {
  const PostMiniGrid({super.key, required this.posts, this.emptyText = ''});

  final List<PromoPost> posts;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: Text(
            emptyText.isEmpty ? 'Belum ada.' : emptyText,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13),
          ),
        ),
      );
    }
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      children: [for (final p in posts) _MiniTile(post: p)],
    );
  }
}

class _MiniTile extends StatelessWidget {
  const _MiniTile({required this.post});

  final PromoPost post;

  @override
  Widget build(BuildContext context) {
    final isVideo = post.videoUrl.isNotEmpty;
    final image = isVideo && post.videoThumbUrl.isNotEmpty
        ? post.videoThumbUrl
        : post.imageUrl;
    return InkWell(
      onTap: () {
        if (isVideo) {
          Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ReelsScreen(initialPostId: post.id)));
        } else {
          showPromoComments(context, post.id);
        }
      },
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          image: image.isNotEmpty
              ? DecorationImage(
                  image: NetworkImage(store.mediaUrl(image)),
                  fit: BoxFit.cover)
              : null,
          gradient: image.isEmpty
              ? (PromoBg.isColored(post.bgStyle)
                  ? null
                  : const LinearGradient(
                      colors: [Color(0xFF2C5364), Color(0xFF0F2027)]))
              : null,
        ),
        foregroundDecoration: image.isEmpty &&
                PromoBg.isColored(post.bgStyle)
            ? null
            : null,
        child: Container(
          decoration: image.isEmpty && PromoBg.isColored(post.bgStyle)
              ? PromoBg.decorationFor(post.bgStyle)
                  .copyWith(borderRadius: BorderRadius.circular(8))
              : null,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(6),
          child: isVideo
              ? const Icon(Icons.play_circle_fill,
                  color: Colors.white, size: 30)
              : image.isEmpty
                  ? Text(
                      post.caption,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700),
                    )
                  : null,
        ),
      ),
    );
  }
}

/// Avatar pengguna: foto bila ada, selain itu inisial nama.
class UserAvatar extends StatelessWidget {
  const UserAvatar(
      {super.key,
      required this.name,
      required this.photoUrl,
      this.radius = 20});

  final String name;
  final String photoUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    if (photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFFB3E3F0),
        backgroundImage: NetworkImage(store.mediaUrl(photoUrl)),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFB3E3F0),
      child: Text(
        name.isEmpty ? '?' : name[0].toUpperCase(),
        style: TextStyle(
            fontSize: radius * 0.8,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0E7490)),
      ),
    );
  }
}

/// Profil publik pelanggan lain: foto, pengikut/mengikuti, tombol
/// ikuti, dan kisi postingannya — gaya profil wca_app.
class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen(
      {super.key, required this.uid, required this.name});

  final String uid;
  final String name;

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  UserInfo? _user;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final u = await store.fetchUser(widget.uid);
    if (mounted) setState(() => _user = u);
  }

  Future<void> _toggleFollow() async {
    if (_busy) return;
    setState(() => _busy = true);
    final u = await store.toggleFollow(widget.uid);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (u != null) _user = u;
    });
    if (u == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Gagal. Periksa koneksi lalu coba lagi.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final u = _user;
    final isMe = store.me?.uid == widget.uid;
    return Scaffold(
      appBar: AppBar(title: Text(widget.name)),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) {
            final userPosts = store.posts
                .where((p) => p.authorUid == widget.uid)
                .toList();
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    UserAvatar(
                        name: widget.name,
                        photoUrl: u?.photoUrl ?? '',
                        radius: 36),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceAround,
                        children: [
                          _Stat(
                              label: 'Postingan',
                              value: '${userPosts.length}'),
                          _Stat(
                              label: 'Pengikut',
                              value: '${u?.followers ?? 0}'),
                          _Stat(
                              label: 'Mengikuti',
                              value: '${u?.following ?? 0}'),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(widget.name,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                if (!isMe && store.role == 'customer')
                  FilledButton.icon(
                    onPressed: _busy || u == null ? null : _toggleFollow,
                    icon: Icon(u?.followedByMe ?? false
                        ? Icons.check
                        : Icons.person_add_alt),
                    label: Text(u?.followedByMe ?? false
                        ? 'Mengikuti'
                        : 'Ikuti'),
                    style: u?.followedByMe ?? false
                        ? FilledButton.styleFrom(
                            backgroundColor:
                                theme.colorScheme.surfaceContainerHighest,
                            foregroundColor: theme.colorScheme.onSurface)
                        : null,
                  ),
                const SizedBox(height: 16),
                const SectionTitle('Postingan'),
                PostMiniGrid(
                    posts: userPosts,
                    emptyText: 'Belum ada postingan.'),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                fontSize: 11.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }
}
