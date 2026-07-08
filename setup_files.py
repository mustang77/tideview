import os
os.makedirs("lib", exist_ok=True)
files = {}
files["lib/api_key.dart"] = r"""const String kYoutubeApiKey = "PASTE_YOUR_KEY_HERE";
"""
files["lib/youtube_service.dart"] = r"""import "dart:convert";
import "package:http/http.dart" as http;
import "api_key.dart";

class Video {
  final String id;
  final String title;
  final String channel;
  final String thumbnail;
  Video({required this.id, required this.title, required this.channel, required this.thumbnail});
}

class YoutubeService {
  static Future<List<Video>> search(String query) async {
    final url = Uri.parse(
      "https://www.googleapis.com/youtube/v3/search"
      "?part=snippet&type=video&maxResults=24"
      "&q=${Uri.encodeComponent(query)}"
      "&key=$kYoutubeApiKey",
    );
    final res = await http.get(url);
    if (res.statusCode != 200) {
      throw Exception("API error ${res.statusCode}: ${res.body}");
    }
    final data = jsonDecode(res.body);
    final items = (data["items"] as List?) ?? [];
    return items
        .where((it) => it["id"]?["videoId"] != null)
        .map((it) {
          final s = it["snippet"];
          final thumbs = s["thumbnails"];
          final t = (thumbs["medium"] ?? thumbs["default"])["url"];
          return Video(
            id: it["id"]["videoId"],
            title: s["title"] ?? "",
            channel: s["channelTitle"] ?? "",
            thumbnail: t ?? "",
          );
        })
        .toList();
  }
}
"""
files["lib/player_screen.dart"] = r"""import "package:flutter/material.dart";
import "package:youtube_player_flutter/youtube_player_flutter.dart";

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
    _controller = YoutubePlayerController(
      initialVideoId: widget.videoId,
      flags: const YoutubePlayerFlags(autoPlay: true, mute: false),
    );
  }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return YoutubePlayerBuilder(
      player: YoutubePlayer(controller: _controller),
      builder: (context, player) {
        return Scaffold(
          appBar: AppBar(title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              player,
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(widget.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }
}
"""
files["lib/search_screen.dart"] = r"""import "package:flutter/material.dart";
import "youtube_service.dart";
import "player_screen.dart";

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  List<Video> _results = [];
  bool _loading = false;
  String? _error;
  Future<void> _search() async {
    final q = _ctrl.text.trim();
    if (q.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      final r = await YoutubeService.search(q);
      setState(() { _results = r; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("TideView")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    decoration: const InputDecoration(hintText: "Search videos...", border: OutlineInputBorder()),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _search, child: const Text("Search")),
              ],
            ),
          ),
          if (_error != null)
            Padding(padding: const EdgeInsets.all(12), child: Text(_error!, style: const TextStyle(color: Colors.red))),
          if (_loading) const Expanded(child: Center(child: CircularProgressIndicator())),
          if (!_loading)
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 320, childAspectRatio: 0.85, crossAxisSpacing: 12, mainAxisSpacing: 12),
                itemCount: _results.length,
                itemBuilder: (context, i) {
                  final v = _results[i];
                  return InkWell(
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => PlayerScreen(videoId: v.id, title: v.title))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AspectRatio(aspectRatio: 16 / 9, child: Image.network(v.thumbnail, fit: BoxFit.cover)),
                        const SizedBox(height: 6),
                        Text(v.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Text(v.channel, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
"""
files["lib/main.dart"] = r"""import "package:flutter/material.dart";
import "search_screen.dart";

void main() => runApp(const TideViewApp());

class TideViewApp extends StatelessWidget {
  const TideViewApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "TideView",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF9c6b26), useMaterial3: true),
      home: const SearchScreen(),
    );
  }
}
"""
for path, content in files.items():
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)
    print("Wrote:", path)
print("Done.")
