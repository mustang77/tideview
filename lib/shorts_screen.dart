import "package:flutter/material.dart";
import "package:youtube_player_iframe/youtube_player_iframe.dart";
import "youtube_service.dart";

const List<String> kShortsSeeds = [
  "cruise ship shorts",
  "cruise ship life shorts",
  "cruise ship crew shorts",
  "cruise ship tips shorts",
];

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
  String _seed = kShortsSeeds[0];

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
    setState(() { _loading = true; _error = null; });
    try {
      final r = await YoutubeService.search(_seed, shortOnly: true);
      setState(() { _videos = r.videos; _nextToken = r.nextPageToken; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _loadMore() async {
    if (_nextToken == null) return;
    try {
      final r = await YoutubeService.search(_seed, pageToken: _nextToken, shortOnly: true);
      setState(() { _videos.addAll(r.videos); _nextToken = r.nextPageToken; });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
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
                Text(_error!, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: _load, child: const Text("Retry")),
              ],
            ),
          ),
        ),
      );
    }
    if (_videos.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: Text("No shorts found.", style: TextStyle(color: Colors.white))),
      );
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _page,
        scrollDirection: Axis.vertical,
        itemCount: _videos.length,
        onPageChanged: (i) {
          if (i >= _videos.length - 2) _loadMore();
        },
        itemBuilder: (context, i) => _ShortPage(video: _videos[i]),
      ),
    );
  }
}

class _ShortPage extends StatefulWidget {
  final Video video;
  const _ShortPage({required this.video});
  @override
  State<_ShortPage> createState() => _ShortPageState();
}

class _ShortPageState extends State<_ShortPage> with AutomaticKeepAliveClientMixin {
  late YoutubePlayerController _controller;

  @override
  bool get wantKeepAlive => false;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.video.id,
      autoPlay: true,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: false,
        loop: true,
      ),
    );
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: Colors.black),
        Center(
          child: YoutubePlayer(controller: _controller, aspectRatio: 9 / 16),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.video.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black, blurRadius: 6)]),
              ),
              const SizedBox(height: 4),
              Text(
                widget.video.channel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 13,
                  shadows: [Shadow(color: Colors.black, blurRadius: 6)]),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
