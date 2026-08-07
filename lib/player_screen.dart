import "dart:ui";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:share_plus/share_plus.dart";
import "package:youtube_player_iframe/youtube_player_iframe.dart";
import "youtube_service.dart";

// Brand accent (matches the app seed colour #9c6b26).
const Color _kGoldLight = Color(0xFFE8C77E);
const Color _kGold = Color(0xFF9C6B26);

class PlayerScreen extends StatefulWidget {
  final String videoId;
  final String title;
  const PlayerScreen({super.key, required this.videoId, required this.title});
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late YoutubePlayerController _controller;
  List<Video> _related = [];
  bool _loadingRelated = false;
  bool _relatedLoaded = false;

  VideoStats? _stats;
  List<Comment> _comments = [];
  bool _loadingComments = false;
  bool _commentsExpanded = false;

  bool _liked = false;
  bool _saved = false;
  bool _subscribed = false;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.videoId,
      autoPlay: true,
      params: const YoutubePlayerParams(showFullscreenButton: true),
    );
    _controller.setFullScreenListener((isFullScreen) {
      if (isFullScreen) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    });
    _loadRelated();
    _loadStats();
    _loadComments();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _controller.close();
    super.dispose();
  }

  Future<void> _loadStats() async {
    try {
      final s = await YoutubeService.stats(widget.videoId);
      if (mounted) setState(() => _stats = s);
    } catch (_) {}
  }

  Future<void> _loadComments() async {
    setState(() => _loadingComments = true);
    try {
      final c = await YoutubeService.comments(widget.videoId);
      if (mounted) setState(() { _comments = c; _loadingComments = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingComments = false);
    }
  }

  Future<void> _loadRelated() async {
    setState(() => _loadingRelated = true);
    final words = widget.title.split(RegExp(r"\s+")).take(6).join(" ");
    try {
      final r = await YoutubeService.search(words);
      final filtered = r.videos.where((v) => v.id != widget.videoId).toList();
      if (mounted) {
        setState(() { _related = filtered; _loadingRelated = false; _relatedLoaded = true; });
      }
    } catch (e) {
      if (mounted) setState(() { _loadingRelated = false; _relatedLoaded = true; });
    }
  }

  void _share() {
    SharePlus.instance.share(ShareParams(
      text: "${widget.title}\nhttps://www.youtube.com/watch?v=${widget.videoId}",
      subject: widget.title,
    ));
  }

  void _openVideo(Video v) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => PlayerScreen(videoId: v.id, title: v.title)),
    );
  }

  String _clean(String raw) {
    return raw
        .replaceAll(RegExp(r"<[^>]*>"), "")
        .replaceAll("&#39;", "'")
        .replaceAll("&quot;", "\"")
        .replaceAll("&amp;", "&")
        .replaceAll("&lt;", "<")
        .replaceAll("&gt;", ">")
        .trim();
  }

  String _channelFrom(String title) {
    // Best-effort: related list gives channels; the current video's channel
    // isn't passed in, so show a friendly fallback derived from stats context.
    return "Cruise Channel";
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final thumbUrl = "https://img.youtube.com/vi/${widget.videoId}/hqdefault.jpg";
    return YoutubePlayerScaffold(
      controller: _controller,
      aspectRatio: 16 / 9,
      builder: (context, player) {
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _playerHeader(player, thumbUrl),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      _titleBlock(cs),
                      _actionBar(cs),
                      _channelCard(cs),
                      _sectionDivider(cs),
                      _commentsSection(cs),
                      _sectionDivider(cs),
                      _relatedSection(cs),
                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---- Player with blurred backdrop + floating back button ----
  Widget _playerHeader(Widget player, String thumbUrl) {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.network(thumbUrl, fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const ColoredBox(color: Colors.black)),
        ),
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(color: Colors.black.withValues(alpha: 0.38)),
          ),
        ),
        Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: player),
        Positioned(
          top: 8,
          left: 8,
          child: Material(
            color: Colors.black38,
            shape: const CircleBorder(),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.maybePop(context),
            ),
          ),
        ),
      ],
    );
  }

  // ---- Title + meta line ----
  Widget _titleBlock(ColorScheme cs) {
    final meta = _stats == null
        ? "Loading…"
        : "${_stats!.views} views  ·  ${_stats!.likes} likes";
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              height: 1.25,
              letterSpacing: -0.3,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            meta,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: cs.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Horizontal pill action bar ----
  Widget _actionBar(ColorScheme cs) {
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        children: [
          _pill(
            cs,
            icon: _liked ? Icons.thumb_up : Icons.thumb_up_outlined,
            label: _liked ? "Liked" : (_stats?.likes ?? "Like"),
            active: _liked,
            onTap: () => setState(() => _liked = !_liked),
          ),
          _pill(cs, icon: Icons.share_outlined, label: "Share", onTap: _share),
          _pill(
            cs,
            icon: _saved ? Icons.bookmark : Icons.bookmark_border,
            label: _saved ? "Saved" : "Save",
            active: _saved,
            onTap: () {
              setState(() => _saved = !_saved);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_saved ? "Saved to your list" : "Removed from your list"),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),
          _pill(cs, icon: Icons.download_outlined, label: "Download", onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Download coming soon"),
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 1),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _pill(ColorScheme cs,
      {required IconData icon,
      required String label,
      bool active = false,
      required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: active ? const LinearGradient(colors: [_kGoldLight, _kGold]) : null,
            color: active ? null : cs.onSurface.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(21),
            border: Border.all(
              color: active ? Colors.transparent : cs.onSurface.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: active ? Colors.white : cs.onSurface),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : cs.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- Channel card with subscribe ----
  Widget _channelCard(ColorScheme cs) {
    final channel = _related.isNotEmpty ? _related.first.channel : _channelFrom(widget.title);
    final letter = channel.isNotEmpty ? channel[0].toUpperCase() : "?";
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_kGoldLight, _kGold],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Text(letter,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 19)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(channel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w700, color: cs.onSurface)),
                Text("Cruise videos & vlogs",
                    style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.5))),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _subscribed = !_subscribed),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                gradient: _subscribed ? null : const LinearGradient(colors: [_kGoldLight, _kGold]),
                color: _subscribed ? cs.onSurface.withValues(alpha: 0.1) : null,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _subscribed ? "Subscribed" : "Subscribe",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: _subscribed ? cs.onSurface.withValues(alpha: 0.7) : Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionDivider(ColorScheme cs) {
    return Divider(height: 28, thickness: 8, color: cs.onSurface.withValues(alpha: 0.04));
  }

  // ---- Comments ----
  Widget _commentsSection(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              _railLabel("Comments", cs),
              if (_comments.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text("${_comments.length}",
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface.withValues(alpha: 0.45))),
              ],
            ],
          ),
        ),
        if (_loadingComments)
          const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(color: _kGold))),
        if (!_loadingComments && _comments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text("No comments (or comments are disabled).",
                style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5))),
          ),
        ...(_commentsExpanded ? _comments : _comments.take(2)).map((c) => _commentTile(c, cs)),
        if (_comments.length > 2)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextButton(
              style: TextButton.styleFrom(foregroundColor: _kGold, padding: EdgeInsets.zero),
              onPressed: () => setState(() => _commentsExpanded = !_commentsExpanded),
              child: Text(_commentsExpanded
                  ? "Show less"
                  : "View all ${_comments.length} comments"),
            ),
          ),
      ],
    );
  }

  Widget _commentTile(Comment c, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipOval(
            child: SizedBox(
              width: 34,
              height: 34,
              child: c.authorImage.isEmpty
                  ? Container(color: cs.onSurface.withValues(alpha: 0.1))
                  : Image.network(c.authorImage, fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(color: cs.onSurface.withValues(alpha: 0.1))),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.author,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface.withValues(alpha: 0.75))),
                const SizedBox(height: 3),
                Text(_clean(c.text),
                    style: TextStyle(fontSize: 14, height: 1.35, color: cs.onSurface)),
                const SizedBox(height: 6),
                Row(children: [
                  Icon(Icons.favorite_border, size: 14, color: cs.onSurface.withValues(alpha: 0.5)),
                  const SizedBox(width: 4),
                  Text(c.likeCount,
                      style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.5))),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---- Related / Up next ----
  Widget _relatedSection(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: _railLabel("Up next", cs),
        ),
        if (_loadingRelated)
          const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: _kGold))),
        if (_relatedLoaded && _related.isEmpty && !_loadingRelated)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text("No related videos found.",
                style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5))),
          ),
        ..._related.map((v) => _relatedTile(v, cs)),
      ],
    );
  }

  Widget _relatedTile(Video v, ColorScheme cs) {
    return InkWell(
      onTap: () => _openVideo(v),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 150,
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(v.thumbnail, fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          Container(color: cs.onSurface.withValues(alpha: 0.08))),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(v.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                          color: cs.onSurface)),
                  const SizedBox(height: 5),
                  Text(v.channel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.55))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _railLabel(String text, ColorScheme cs) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_kGoldLight, _kGold],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(text,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: cs.onSurface)),
      ],
    );
  }
}
