import "package:flutter/material.dart";
import "package:youtube_player_iframe/youtube_player_iframe.dart";

class PlayerScreen extends StatefulWidget {
  final String videoId;
  final String title;
  const PlayerScreen({super.key, required this.videoId, required this.title});
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late YoutubePlayerController _controller;
  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.videoId,
      autoPlay: true,
      params: const YoutubePlayerParams(showFullscreenButton: true),
    );
  }
  @override
  void dispose() { _controller.close(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          YoutubePlayer(controller: _controller, aspectRatio: 16 / 9),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(widget.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
