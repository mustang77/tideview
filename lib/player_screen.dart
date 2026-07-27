import "dart:ui";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:share_plus/share_plus.dart";
import "package:youtube_player_iframe/youtube_player_iframe.dart";
import "youtube_service.dart";

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
      if (mounted) setState(() { _stats = s; });
    } catch (_) {}
  }

  Future<void> _loadComments() async {
    setState(() { _loadingComments = true; });
    try {
      final c = await YoutubeService.comments(widget.videoId);
      if (mounted) setState(() { _comments = c; _loadingComments = false; });
    } catch (_) {
      if (mounted) setState(() { _loadingComments = false; });
    }
  }

  Future<void> _loadRelated() async {
    setState(() { _loadingRelated = true; });
    final words = widget.title.split(RegExp(r"\s+")).take(6).join(" ");
    try {
      final r = await YoutubeService.search(words);
      final filtered = r.videos.where((v) => v.id != widget.videoId).toList();
      if (mounted) setState(() { _related = filtered; _loadingRelated = false; _relatedLoaded = true; });
    } catch (e) {
      if (mounted) setState(() { _loadingRelated = false; _relatedLoaded = true; });
    }
  }

  void _share() {
    final url = "https://www.youtube.com/watch?v=${widget.videoId}";
    Share.share("${widget.title}\n$url");
  }

  void _openVideo(Video v) {
    Navigator.pushReplacement(context, MaterialPageRoute(
      builder: (_) => PlayerScreen(videoId: v.id, title: v.title),
    ));
  }

  Widget _statChip(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _blurredBar(String thumbUrl) {
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Transform.scale(
            scale: 1.2,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Image.network(thumbUrl, fit: BoxFit.cover),
            ),
          ),
          Container(color: Colors.black.withValues(alpha: 0.45)),
        ],
      ),
    );
  }

  // The iframe player letterboxes the 16:9 video against the screen and fills
  // the rest with black. These strips sit exactly on the letterbox areas
  // (never on the video itself) and pass all touches through to the player.
  Widget _fullscreenBars(BuildContext context, bool isFullscreen, String thumbUrl) {
    if (!isFullscreen) return const SizedBox.shrink();
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          const videoAspect = 16 / 9;
          final bars = <Widget>[];
          if (w / h > videoAspect) {
            final barW = (w - h * videoAspect) / 2;
            if (barW >= 1) {
              bars.add(Positioned(left: 0, top: 0, bottom: 0, width: barW, child: _blurredBar(thumbUrl)));
              bars.add(Positioned(right: 0, top: 0, bottom: 0, width: barW, child: _blurredBar(thumbUrl)));
            }
          } else {
            final barH = (h - w / videoAspect) / 2;
            if (barH >= 1) {
              bars.add(Positioned(top: 0, left: 0, right: 0, height: barH, child: _blurredBar(thumbUrl)));
              bars.add(Positioned(bottom: 0, left: 0, right: 0, height: barH, child: _blurredBar(thumbUrl)));
            }
          }
          if (bars.isEmpty) return const SizedBox.shrink();
          return Stack(children: bars);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final thumbUrl = "https://img.youtube.com/vi/${widget.videoId}/hqdefault.jpg";
    final player = YoutubePlayer(
      controller: _controller,
      aspectRatio: 16 / 9,
      controlsBuilder: (context, isFullscreen) => _fullscreenBars(context, isFullscreen, thumbUrl),
    );
    return Scaffold(
      appBar: AppBar(title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: Column(
        children: [
          Stack(
            children: [
              Positioned.fill(child: Image.network(thumbUrl, fit: BoxFit.cover)),
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                  child: Container(color: Colors.black.withValues(alpha: 0.35)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: player,
              ),
            ],
          ),
          Expanded(
            child: ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(widget.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                // Stats + action row.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      _statChip(Icons.visibility_outlined, _stats == null ? "…" : "${_stats!.views} views"),
                      _statChip(Icons.thumb_up_outlined, _stats == null ? "…" : _stats!.likes),
                      InkWell(
                        onTap: _share,
                        child: _statChip(Icons.share_outlined, "Share"),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                // Comments.
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text("Comments", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
                if (_loadingComments)
                  const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
                if (!_loadingComments && _comments.isEmpty)
                  const Padding(padding: EdgeInsets.all(16), child: Text("No comments (or comments are disabled).")),
                ...(_commentsExpanded ? _comments : _comments.take(1)).map((c) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(radius: 16, backgroundImage: NetworkImage(c.authorImage)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.author, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text(c.text, style: const TextStyle(fontSize: 13),
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Row(children: [
                              const Icon(Icons.thumb_up_outlined, size: 13, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(c.likeCount, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ]),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
                if (!_commentsExpanded && _comments.length > 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: TextButton(
                      onPressed: () => setState(() => _commentsExpanded = true),
                      child: Text("Show ${_comments.length - 1} more comments"),
                    ),
                  ),
                if (_commentsExpanded && _comments.length > 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: TextButton(
                      onPressed: () => setState(() => _commentsExpanded = false),
                      child: const Text("Show less"),
                    ),
                  ),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text("Related videos", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
                if (_loadingRelated)
                  const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
                if (_relatedLoaded && _related.isEmpty && !_loadingRelated)
                  const Padding(padding: EdgeInsets.all(16), child: Text("No related videos found.")),
                ..._related.map((v) => InkWell(
                  onTap: () => _openVideo(v),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Image.network(v.thumbnail, fit: BoxFit.cover, width: double.infinity),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(v.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(v.channel, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                )),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
