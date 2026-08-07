import "package:flutter/material.dart";
import "package:share_plus/share_plus.dart";
import "package:youtube_player_iframe/youtube_player_iframe.dart";
import "youtube_service.dart";

// Brand accent (matches the app seed colour #9c6b26).
const Color _kGoldLight = Color(0xFFE8C77E);
const Color _kGold = Color(0xFF9C6B26);

const List<String> kShortsSeeds = [
  "cruise ship shorts",
  "cruise ship life shorts",
  "cruise ship crew shorts",
  "cruise ship tips shorts",
];

const List<String> kShortsLabels = ["For You", "Life", "Crew", "Tips"];

class ShortsScreen extends StatefulWidget {
  const ShortsScreen({super.key});
  @override
  State<ShortsScreen> createState() => _ShortsScreenState();
}

class _ShortsScreenState extends State<ShortsScreen> {
  final PageController _page = PageController();
  List<Video> _videos = [];
  bool _loading = true;
  String? _error;
  String? _nextToken;
  int _seedIndex = 0;

  String get _seed => kShortsSeeds[_seedIndex];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await YoutubeService.search(_seed, shortOnly: true);
      setState(() {
        _videos = r.videos;
        _nextToken = r.nextPageToken;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_nextToken == null) return;
    try {
      final r = await YoutubeService.search(_seed, pageToken: _nextToken, shortOnly: true);
      setState(() {
        _videos.addAll(r.videos);
        _nextToken = r.nextPageToken;
      });
    } catch (_) {}
  }

  void _selectSeed(int i) {
    if (i == _seedIndex) return;
    setState(() {
      _seedIndex = i;
      _videos = [];
    });
    if (_page.hasClients) _page.jumpToPage(0);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _feed(),
          // top scrim for legibility of the category tabs
          const IgnorePointer(
            child: SizedBox(
              height: 130,
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black54, Colors.transparent],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(child: _categoryTabs()),
        ],
      ),
    );
  }

  Widget _feed() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: _kGoldLight),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, color: Colors.white38, size: 40),
              const SizedBox(height: 12),
              Text(_error!,
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _kGold),
                onPressed: _load,
                child: const Text("Retry"),
              ),
            ],
          ),
        ),
      );
    }
    if (_videos.isEmpty) {
      return const Center(
        child: Text("No shorts found.", style: TextStyle(color: Colors.white)),
      );
    }
    return PageView.builder(
      controller: _page,
      scrollDirection: Axis.vertical,
      itemCount: _videos.length,
      onPageChanged: (i) {
        if (i >= _videos.length - 2) _loadMore();
      },
      itemBuilder: (context, i) => _ShortPage(
        key: ValueKey(_videos[i].id),
        video: _videos[i],
      ),
    );
  }

  Widget _categoryTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: SizedBox(
        height: 34,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: kShortsLabels.length,
          separatorBuilder: (_, index) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final active = i == _seedIndex;
            return GestureDetector(
              onTap: () => _selectSeed(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  gradient: active
                      ? const LinearGradient(colors: [_kGoldLight, _kGold])
                      : null,
                  color: active ? null : Colors.white.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  kShortsLabels[i],
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ShortPage extends StatefulWidget {
  final Video video;
  const _ShortPage({super.key, required this.video});
  @override
  State<_ShortPage> createState() => _ShortPageState();
}

class _ShortPageState extends State<_ShortPage> with AutomaticKeepAliveClientMixin {
  late YoutubePlayerController _controller;
  VideoStats? _stats;
  bool _liked = false;
  bool _following = false;
  bool _paused = false;

  @override
  bool get wantKeepAlive => false;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.video.id,
      autoPlay: true,
      params: const YoutubePlayerParams(
        showControls: false,
        showFullscreenButton: false,
        loop: true,
        enableCaption: false,
        strictRelatedVideos: true,
      ),
    );
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    try {
      final s = await YoutubeService.stats(widget.video.id);
      if (mounted) setState(() => _stats = s);
    } catch (_) {}
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  void _share() {
    SharePlus.instance.share(ShareParams(
      text: "Watch \"${widget.video.title}\" on TideView\nhttps://youtu.be/${widget.video.id}",
      subject: widget.video.title,
    ));
  }

  void _openComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommentsSheet(videoId: widget.video.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        // ---- Video in a clean rounded frame ----
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 56, 10, 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: Colors.black),
                  Center(
                    child: YoutubePlayer(
                        controller: _controller, aspectRatio: 9 / 16),
                  ),
                  // tap the video to play / pause
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _togglePlay,
                    ),
                  ),
                  if (_paused)
                    const IgnorePointer(
                      child: Center(
                        child: Icon(Icons.play_arrow_rounded,
                            size: 74, color: Colors.white70),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        // ---- Branded control bar (renders reliably below the player) ----
        _controlPanel(),
      ],
    );
  }

  void _togglePlay() {
    setState(() => _paused = !_paused);
    if (_paused) {
      _controller.pauseVideo();
    } else {
      _controller.playVideo();
    }
  }

  Widget _controlPanel() {
    return Container(
      width: double.infinity,
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // channel + follow
          Row(
            children: [
              _avatar(widget.video.channel, 18, ring: true),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.video.channel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (_stats != null)
                      Text(
                        "${_stats!.views} views",
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _followButton(),
            ],
          ),
          const SizedBox(height: 12),
          // title
          Text(
            widget.video.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),
          // action buttons
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  icon: _liked ? Icons.favorite : Icons.favorite_border,
                  label: _liked ? "Liked" : (_stats?.likes ?? "Like"),
                  active: _liked,
                  activeColor: const Color(0xFFFF3B5C),
                  onTap: () => setState(() => _liked = !_liked),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _actionButton(
                  icon: Icons.mode_comment_outlined,
                  label: "Comments",
                  onTap: _openComments,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _actionButton(
                  icon: Icons.reply_outlined,
                  label: "Share",
                  onTap: _share,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _followButton() {
    return GestureDetector(
      onTap: () => setState(() => _following = !_following),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: _following
              ? null
              : const LinearGradient(colors: [_kGoldLight, _kGold]),
          color: _following ? Colors.white24 : null,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          _following ? "Following" : "Follow",
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
    Color activeColor = _kGoldLight,
  }) {
    final color = active ? activeColor : Colors.white;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatar(String channel, double radius, {bool ring = false}) {
    final letter = channel.isNotEmpty ? channel[0].toUpperCase() : "?";
    return Container(
      width: radius * 2,
      height: radius * 2,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_kGoldLight, _kGold],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        border: ring ? Border.all(color: Colors.white, width: 2) : null,
      ),
      child: Text(
        letter,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: radius * 0.9,
        ),
      ),
    );
  }
}

// ---- Real comments, loaded from YouTube, in a draggable sheet ----
class _CommentsSheet extends StatelessWidget {
  final String videoId;
  const _CommentsSheet({required this.videoId});

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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: .25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                child: Row(
                  children: [
                    Text("Comments",
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface,
                        )),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: cs.onSurface.withValues(alpha: .08)),
              Expanded(
                child: FutureBuilder<List<Comment>>(
                  future: YoutubeService.comments(videoId),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: _kGold));
                    }
                    final comments = snap.data ?? [];
                    if (comments.isEmpty) {
                      return Center(
                        child: Text("No comments yet",
                            style: TextStyle(color: cs.onSurface.withValues(alpha: .5))),
                      );
                    }
                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: comments.length,
                      separatorBuilder: (_, index) => const SizedBox(height: 18),
                      itemBuilder: (context, i) {
                        final c = comments[i];
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _commentAvatar(c.authorImage, cs),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(c.author,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12.5,
                                        color: cs.onSurface.withValues(alpha: .75),
                                      )),
                                  const SizedBox(height: 3),
                                  Text(_clean(c.text),
                                      style: TextStyle(
                                        fontSize: 14,
                                        height: 1.35,
                                        color: cs.onSurface,
                                      )),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(Icons.favorite_border,
                                          size: 14,
                                          color: cs.onSurface.withValues(alpha: .5)),
                                      const SizedBox(width: 4),
                                      Text(c.likeCount,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: cs.onSurface.withValues(alpha: .5),
                                          )),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _commentAvatar(String url, ColorScheme cs) {
    return ClipOval(
      child: SizedBox(
        width: 36,
        height: 36,
        child: url.isEmpty
            ? Container(color: cs.onSurface.withValues(alpha: .1))
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) =>
                    Container(color: cs.onSurface.withValues(alpha: .1)),
              ),
      ),
    );
  }
}
