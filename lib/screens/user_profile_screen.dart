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

/// Daftar pengikut atau mengikuti seorang pengguna.
class FollowListScreen extends StatefulWidget {
  const FollowListScreen(
      {super.key, required this.uid, required this.followers});

  final String uid;

  /// true = daftar pengikut, false = daftar mengikuti.
  final bool followers;

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen> {
  List<MiniUser>? _users;
  bool _private = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await store.fetchFollowList(widget.uid, widget.followers);
    if (!mounted) return;
    setState(() {
      if (r == null) {
        _failed = true;
      } else {
        _private = r.private;
        _users = r.users;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.followers ? 'Pengikut' : 'Mengikuti';
    final theme = Theme.of(context);
    Widget body;
    if (_failed) {
      body = Center(
          child: Text('Tidak bisa terhubung ke server.',
              style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant)));
    } else if (_users == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_private) {
      body = const _PrivateNotice();
    } else if (_users!.isEmpty) {
      body = Center(
        child: Text(
            widget.followers
                ? 'Belum ada pengikut.'
                : 'Belum mengikuti siapa pun.',
            style:
                TextStyle(color: theme.colorScheme.onSurfaceVariant)),
      );
    } else {
      body = ListView.separated(
        itemCount: _users!.length,
        separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
        itemBuilder: (context, i) {
          final u = _users![i];
          return ListTile(
            leading:
                UserAvatar(name: u.name, photoUrl: u.photoUrl, radius: 22),
            title: Text(u.name,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) =>
                    UserProfileScreen(uid: u.uid, name: u.name))),
          );
        },
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(child: body),
    );
  }
}

/// Pemberitahuan profil privat (dipakai daftar pengikut & profil).
class _PrivateNotice extends StatelessWidget {
  const _PrivateNotice();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 30,
              backgroundColor: Color(0xFFE2E8F0),
              child:
                  Icon(Icons.lock_outline, size: 30, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 14),
            const Text('Maaf, profil ini privat 🔒',
                style:
                    TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              'Pemilik profil menyembunyikan postingan dan '
              'daftar pengikutnya.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
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
            // Profil privat: sembunyikan postingan & daftar dari
            // pengunjung (pemiliknya tetap bisa melihat).
            final hidden = (u?.isPrivate ?? false) && !isMe;
            void openList(bool followers) {
              if (hidden) return;
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => FollowListScreen(
                      uid: widget.uid, followers: followers)));
            }

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
                              value: hidden ? '•' : '${userPosts.length}'),
                          _Stat(
                              label: 'Pengikut',
                              value: '${u?.followers ?? 0}',
                              onTap: () => openList(true)),
                          _Stat(
                              label: 'Mengikuti',
                              value: '${u?.following ?? 0}',
                              onTap: () => openList(false)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Flexible(
                      child: Text(widget.name,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800)),
                    ),
                    if (u?.isPrivate ?? false) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.lock_outline,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant),
                    ],
                  ],
                ),
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
                if (hidden)
                  const _PrivateNotice()
                else ...[
                  const SectionTitle('Postingan'),
                  PostMiniGrid(
                      posts: userPosts,
                      emptyText: 'Belum ada postingan.'),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.onTap});

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 11.5,
                    color:
                        Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
