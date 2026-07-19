import "dart:ui";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:share_plus/share_plus.dart";
import "package:youtube_player_iframe/youtube_player_iframe.dart";
import "youtube_service.dart";

const List<String> kShortsSeeds = [
  "cruise ship shorts",
  "cruise ship life shorts",
  "cruise ship crew shorts",
  "cruise ship tips shorts",
];

/// A TikTok-style vertical, full-screen, swipeable video feed.
///
/// [active] tells the feed whether its tab is currently visible (so it pauses
/// when you switch away). Only the current page — plus its immediate neighbour
/// for instant swiping — keeps a live player; the rest show their thumbnail.
class ShortsScreen extends StatefulWidget {
  final bool active;
  const ShortsScreen({super.key, this.active = true});
  @override
  State<ShortsScreen> createState() => _ShortsScreenState();
}

class _ShortsScreenState extends State<ShortsScreen> {
  final PageController _page = PageController();
  List<Video> _videos = [];
  bool _loading = true;
  String? _error;
  String? _nextToken;
  String _seed = kShortsSeeds[0];
  int _current = 0;
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ShortsScreen old) {
    super.didUpdateWidget(old);
    // Tab visibility changed — rebuild pages so the current one plays/pauses.
    if (old.active != widget.active) setState(() {});
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await YoutubeService.search(_seed, shortOnly: true);
      if (!mounted) return;
      setState(() { _videos = r.videos; _nextToken = r.nextPageToken; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _loadMore() async {
    if (_nextToken == null) return;
    try {
      final r = await YoutubeService.search(_seed, pageToken: _nextToken, shortOnly: true);
      if (!mounted) return;
      setState(() { _videos.addAll(r.videos); _nextToken = r.nextPageToken; });
    } catch (_) {}
  }

  void _share(Video v) {
    Share.share("${v.title}\nhttps://www.youtube.com/watch?v=${v.id}");
  }

  void _openComments(Video v) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CommentsSheet(videoId: v.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.white)));
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off_rounded, color: Colors.white54, size: 48),
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(onPressed: _load, child: const Text("Retry")),
              ],
            ),
          ),
        ),
      );
    }
    if (_videos.isEmpty) {
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: Text("No shorts found.", style: TextStyle(color: Colors.white))));
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _page,
            scrollDirection: Axis.vertical,
            itemCount: _videos.length,
            onPageChanged: (i) {
              setState(() => _current = i);
              if (i >= _videos.length - 3) _loadMore();
            },
            itemBuilder: (context, i) => _ShortPage(
              key: ValueKey(_videos[i].id),
              video: _videos[i],
              shouldPlay: i == _current && widget.active,
              preload: (i - _current).abs() <= 1,
              muted: _muted,
              onShare: () => _share(_videos[i]),
              onComments: () => _openComments(_videos[i]),
            ),
          ),
          // mute toggle (top-right)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 10,
            child: _RoundIcon(
              icon: _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              onTap: () => setState(() => _muted = !_muted),
            ),
          ),
          // small "Shorts" wordmark (top-left)
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            child: const Text("Shorts",
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800,
                shadows: [Shadow(color: Colors.black54, blurRadius: 6)])),
          ),
        ],
      ),
    );
  }
}

class _ShortPage extends StatefulWidget {
  final Video video;
  final bool shouldPlay;
  final bool preload;
  final bool muted;
  final VoidCallback onShare;
  final VoidCallback onComments;
  const _ShortPage({
    super.key,
    required this.video,
    required this.shouldPlay,
    required this.preload,
    required this.muted,
    required this.onShare,
    required this.onComments,
  });
  @override
  State<_ShortPage> createState() => _ShortPageState();
}

class _ShortPageState extends State<_ShortPage> with SingleTickerProviderStateMixin {
  YoutubePlayerController? _controller;
  bool _userPaused = false;
  bool _liked = false;
  VideoStats? _stats;
  bool _statsRequested = false;
  late final AnimationController _burst =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

  @override
  void initState() {
    super.initState();
    if (widget.preload) _create();
    if (widget.shouldPlay) _fetchStats();
  }

  void _create() {
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.video.id,
      autoPlay: widget.shouldPlay,
      params: YoutubePlayerParams(
        showControls: false,
        showFullscreenButton: false,
        enableCaption: false,
        loop: true,
        mute: widget.muted,
        strictRelatedVideos: true,
      ),
    );
  }

  void _disposeController() {
    _controller?.close();
    _controller = null;
  }

  Future<void> _fetchStats() async {
    if (_statsRequested) return;
    _statsRequested = true;
    try {
      final s = await YoutubeService.stats(widget.video.id);
      if (mounted) setState(() => _stats = s);
    } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant _ShortPage old) {
    super.didUpdateWidget(old);
    if (widget.preload && _controller == null) _create();
    if (!widget.preload && _controller != null) { _disposeController(); }
    if (widget.muted != old.muted) {
      if (widget.muted) { _controller?.mute(); } else { _controller?.unMute(); }
    }
    if (widget.shouldPlay != old.shouldPlay) {
      _userPaused = false;
      if (widget.shouldPlay) _fetchStats();
      _applyPlayback();
    }
  }

  void _applyPlayback() {
    final c = _controller;
    if (c == null) return;
    if (widget.shouldPlay && !_userPaused) { c.playVideo(); } else { c.pauseVideo(); }
  }

  @override
  void dispose() {
    _burst.dispose();
    _disposeController();
    super.dispose();
  }

  void _togglePlay() {
    setState(() => _userPaused = !_userPaused);
    _applyPlayback();
  }

  void _doubleLike() {
    HapticFeedback.lightImpact();
    setState(() => _liked = true);
    _burst.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.video;
    final thumb = v.thumbnail.isNotEmpty ? v.thumbnail : "https://img.youtube.com/vi/${v.id}/hqdefault.jpg";
    final c = _controller;
    return GestureDetector(
      onTap: _togglePlay,
      onDoubleTap: _doubleLike,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // blurred thumbnail backdrop — never a black flash while loading
          Image.network(thumb, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: Colors.black)),
          Positioned.fill(child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: Container(color: Colors.black.withValues(alpha: 0.35)),
          )),
          // the player (only for current/neighbour pages)
          if (c != null)
            Center(child: YoutubePlayer(controller: c, aspectRatio: 9 / 16))
          else
            Center(child: Image.network(thumb, fit: BoxFit.contain)),

          // top + bottom scrims for legibility
          const _Scrim(),

          // paused indicator
          if (_userPaused && widget.shouldPlay)
            const Center(child: Icon(Icons.play_arrow_rounded, size: 84, color: Colors.white70)),

          // double-tap heart burst
          AnimatedBuilder(
            animation: _burst,
            builder: (context, _) {
              if (_burst.isDismissed) return const SizedBox.shrink();
              final t = _burst.value;
              final scale = 0.6 + Curves.easeOutBack.transform((t * 1.4).clamp(0, 1)) * 0.7;
              final opacity = t < 0.7 ? 1.0 : (1 - (t - 0.7) / 0.3);
              return Center(child: Opacity(opacity: opacity.clamp(0, 1),
                child: Transform.scale(scale: scale,
                  child: const Icon(Icons.favorite, color: Colors.white, size: 110))));
            },
          ),

          // right action rail
          Positioned(
            right: 10,
            bottom: 96,
            child: Column(
              children: [
                _Author(channel: v.channel),
                const SizedBox(height: 22),
                _RailButton(
                  icon: _liked ? Icons.favorite : Icons.favorite_border,
                  color: _liked ? const Color(0xFFFF2D55) : Colors.white,
                  label: _stats?.likes ?? "Like",
                  onTap: () { setState(() => _liked = !_liked); if (_liked) _burst.forward(from: 0); },
                ),
                const SizedBox(height: 18),
                _RailButton(icon: Icons.mode_comment_outlined, label: "Comments", onTap: widget.onComments),
                const SizedBox(height: 18),
                _RailButton(icon: Icons.reply_rounded, mirror: true, label: "Share", onTap: widget.onShare),
                const SizedBox(height: 18),
                _SpinningDisc(spinning: widget.shouldPlay && !_userPaused),
              ],
            ),
          ),

          // bottom caption
          Positioned(
            left: 14,
            right: 84,
            bottom: 78,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  const Icon(Icons.person, size: 16, color: Colors.white),
                  const SizedBox(width: 4),
                  Flexible(child: Text("@${v.channel}",
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800,
                      shadows: [Shadow(color: Colors.black, blurRadius: 6)]))),
                ]),
                const SizedBox(height: 6),
                Text(_decode(v.title), maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 14,
                    shadows: [Shadow(color: Colors.black, blurRadius: 6)])),
                const SizedBox(height: 8),
                Row(children: const [
                  Icon(Icons.music_note, size: 15, color: Colors.white),
                  SizedBox(width: 6),
                  Text("original sound", style: TextStyle(color: Colors.white, fontSize: 12,
                    shadows: [Shadow(color: Colors.black, blurRadius: 6)])),
                ]),
              ],
            ),
          ),

          // progress bar (bottom)
          if (c != null)
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: _ProgressBar(controller: c),
            ),
        ],
      ),
    );
  }
}

String _decode(String s) => s
    .replaceAll("&#39;", "'").replaceAll("&quot;", '"').replaceAll("&amp;", "&")
    .replaceAll("&lt;", "<").replaceAll("&gt;", ">");

class _ProgressBar extends StatelessWidget {
  final YoutubePlayerController controller;
  const _ProgressBar({required this.controller});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<YoutubeVideoState>(
      stream: controller.videoStateStream,
      builder: (context, snapshot) {
        final pos = snapshot.data?.position.inMilliseconds ?? 0;
        final dur = controller.metadata.duration.inMilliseconds;
        final value = (dur > 0) ? (pos / dur).clamp(0.0, 1.0) : 0.0;
        return LinearProgressIndicator(
          value: value,
          minHeight: 3,
          backgroundColor: Colors.white24,
          valueColor: const AlwaysStoppedAnimation(Colors.white),
        );
      },
    );
  }
}

class _Scrim extends StatelessWidget {
  const _Scrim();
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Column(
        children: [
          Container(height: 90, decoration: const BoxDecoration(gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Colors.black45, Colors.transparent]))),
          const Spacer(),
          Container(height: 180, decoration: const BoxDecoration(gradient: LinearGradient(
            begin: Alignment.bottomCenter, end: Alignment.topCenter,
            colors: [Colors.black54, Colors.transparent]))),
        ],
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final bool mirror;
  const _RailButton({required this.icon, required this.label, required this.onTap,
    this.color = Colors.white, this.mirror = false});
  @override
  Widget build(BuildContext context) {
    final ic = Icon(icon, color: color, size: 34,
      shadows: const [Shadow(color: Colors.black54, blurRadius: 6)]);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          mirror ? Transform.flip(flipX: true, child: ic) : ic,
          const SizedBox(height: 4),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600,
              shadows: [Shadow(color: Colors.black54, blurRadius: 6)])),
        ],
      ),
    );
  }
}

class _Author extends StatelessWidget {
  final String channel;
  const _Author({required this.channel});
  @override
  Widget build(BuildContext context) {
    final letter = channel.isNotEmpty ? channel[0].toUpperCase() : "?";
    final hue = (channel.hashCode % 360).abs().toDouble();
    final bg = HSLColor.fromAHSL(1, hue, 0.55, 0.5).toColor();
    return SizedBox(
      width: 52, height: 62,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2)),
            alignment: Alignment.center,
            child: Text(letter, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          ),
          Positioned(
            bottom: 0,
            child: Container(
              width: 22, height: 22,
              decoration: const BoxDecoration(color: Color(0xFFFF2D55), shape: BoxShape.circle),
              child: const Icon(Icons.add, color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpinningDisc extends StatefulWidget {
  final bool spinning;
  const _SpinningDisc({required this.spinning});
  @override
  State<_SpinningDisc> createState() => _SpinningDiscState();
}

class _SpinningDiscState extends State<_SpinningDisc> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 4));
  @override
  void initState() { super.initState(); if (widget.spinning) _c.repeat(); }
  @override
  void didUpdateWidget(covariant _SpinningDisc old) {
    super.didUpdateWidget(old);
    if (widget.spinning && !_c.isAnimating) _c.repeat();
    if (!widget.spinning && _c.isAnimating) _c.stop();
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _c,
      child: Container(
        width: 46, height: 46,
        decoration: BoxDecoration(shape: BoxShape.circle,
          gradient: const LinearGradient(colors: [Color(0xFF333333), Color(0xFF111111)]),
          border: Border.all(color: Colors.white24, width: 4)),
        child: const Icon(Icons.music_note, color: Colors.white, size: 20),
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundIcon({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

class _CommentsSheet extends StatefulWidget {
  final String videoId;
  const _CommentsSheet({required this.videoId});
  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  late Future<List<Comment>> _future;
  @override
  void initState() { super.initState(); _future = YoutubeService.comments(widget.videoId); }
  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6, minChildSize: 0.4, maxChildSize: 0.92, expand: false,
      builder: (context, scroll) => Column(
        children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const Padding(padding: EdgeInsets.all(14),
            child: Text("Comments", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
          const Divider(height: 1, color: Colors.white12),
          Expanded(
            child: FutureBuilder<List<Comment>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator(color: Colors.white));
                }
                final comments = snap.data ?? [];
                if (comments.isEmpty) {
                  return const Center(child: Padding(padding: EdgeInsets.all(24),
                    child: Text("No comments yet (or comments are off).", style: TextStyle(color: Colors.white54))));
                }
                return ListView.builder(
                  controller: scroll,
                  itemCount: comments.length,
                  itemBuilder: (context, i) {
                    final cm = comments[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(radius: 18, backgroundColor: Colors.white12,
                            backgroundImage: cm.authorImage.isNotEmpty ? NetworkImage(cm.authorImage) : null),
                          const SizedBox(width: 12),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(cm.author, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 3),
                              Text(_stripHtml(cm.text), style: const TextStyle(color: Colors.white, fontSize: 14)),
                              const SizedBox(height: 4),
                              Row(children: [
                                const Icon(Icons.favorite_border, size: 14, color: Colors.white38),
                                const SizedBox(width: 4),
                                Text(cm.likeCount, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                              ]),
                            ],
                          )),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

String _stripHtml(String s) => s
    .replaceAll(RegExp(r"<br\s*/?>", caseSensitive: false), "\n")
    .replaceAll(RegExp(r"<[^>]*>"), "")
    .replaceAll("&#39;", "'").replaceAll("&quot;", '"').replaceAll("&amp;", "&")
    .replaceAll("&lt;", "<").replaceAll("&gt;", ">").trim();
