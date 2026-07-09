import "package:flutter/material.dart";
import "youtube_service.dart";
import "player_screen.dart";

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  List<Video> _results = [];
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  String _query = "";
  String? _nextToken;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 500) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _ctrl.text.trim();
    if (q.isEmpty) return;
    setState(() { _loading = true; _error = null; _results = []; _query = q; _nextToken = null; });
    try {
      final r = await YoutubeService.search(q);
      setState(() { _results = r.videos; _nextToken = r.nextPageToken; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _loading || _nextToken == null || _query.isEmpty) return;
    setState(() { _loadingMore = true; });
    try {
      final r = await YoutubeService.search(_query, pageToken: _nextToken);
      setState(() {
        _results.addAll(r.videos);
        _nextToken = r.nextPageToken;
        _loadingMore = false;
      });
    } catch (e) {
      setState(() { _loadingMore = false; });
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
                controller: _scroll,
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
          if (_loadingMore)
            const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
