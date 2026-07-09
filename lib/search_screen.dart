import "package:flutter/material.dart";
import "youtube_service.dart";
import "player_screen.dart";

const List<String> kCategories = [
  "Cruise ship life",
  "Cruise ship jobs",
  "Behind the scenes cruise ship",
  "Cruise ship tour",
  "Working on a cruise ship",
  "Cruise ship crew",
  "Luxury cruise ships",
  "Cruise ship engine room",
];

class SearchScreen extends StatefulWidget {
  final VoidCallback? onToggleTheme;
  const SearchScreen({super.key, this.onToggleTheme});
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
  int _activeChip = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 500) {
        _loadMore();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runSearch(kCategories[0], chipIndex: 0);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String q, {int chipIndex = -1}) async {
    if (q.isEmpty) return;
    setState(() {
      _loading = true; _error = null; _results = [];
      _query = q; _nextToken = null; _activeChip = chipIndex;
    });
    try {
      final r = await YoutubeService.search(q);
      setState(() { _results = r.videos; _nextToken = r.nextPageToken; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _searchFromBox() {
    _runSearch(_ctrl.text.trim(), chipIndex: -1);
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
      appBar: AppBar(
        title: const Text("TideView"),
        actions: [
          IconButton(
            tooltip: "Toggle theme",
            icon: Icon(Theme.of(context).brightness == Brightness.dark
                ? Icons.light_mode
                : Icons.dark_mode),
            onPressed: widget.onToggleTheme,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    textAlignVertical: TextAlignVertical.center,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: "Search videos...",
                      isDense: true,
                      prefixIcon: const Icon(Icons.search, size: 20),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                    ),
                    onSubmitted: (_) => _searchFromBox(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _searchFromBox,
                  icon: const Icon(Icons.arrow_forward),
                  tooltip: "Search",
                ),
              ],
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: kCategories.length,
              separatorBuilder: (a, b) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final active = i == _activeChip;
                return Center(
                  child: ChoiceChip(
                    label: Text(kCategories[i]),
                    selected: active,
                    onSelected: (_) => _runSearch(kCategories[i], chipIndex: i),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 4),
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
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: AspectRatio(aspectRatio: 16 / 9, child: Image.network(v.thumbnail, fit: BoxFit.cover)),
                        ),
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
