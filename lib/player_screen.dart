import "package:flutter/material.dart";
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

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.videoId,
      autoPlay: true,
      params: const YoutubePlayerParams(showFullscreenButton: true),
    );
    _loadRelated();
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  Future<void> _loadRelated() async {
    setState(() { _loadingRelated = true; });
    final words = widget.title.split(RegExp(r"\s+")).take(6).join(" ");
    try {
      final r = await YoutubeService.search(words);
      final filtered = r.videos.where((v) => v.id != widget.videoId).toList();
      setState(() { _related = filtered; _loadingRelated = false; _relatedLoaded = true; });
    } catch (e) {
      setState(() { _loadingRelated = false; _relatedLoaded = true; });
    }
  }

  void _openVideo(Video v) {
    Navigator.pushReplacement(context, MaterialPageRoute(
      builder: (_) => PlayerScreen(videoId: v.id, title: v.title),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: ListView(
        children: [
          YoutubePlayer(controller: _controller, aspectRatio: 16 / 9),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(widget.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
          ..._related.map((v) => ListTile(
            leading: SizedBox(
              width: 100,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(v.thumbnail, fit: BoxFit.cover),
              ),
            ),
            title: Text(v.title, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: Text(v.channel, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
            onTap: () => _openVideo(v),
          )),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
