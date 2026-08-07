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

// Brand accent (matches the app seed colour #9c6b26).
const Color _kGoldLight = Color(0xFFE8C77E);
const Color _kGold = Color(0xFF9C6B26);

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
      _loading = true;
      _error = null;
      _results = [];
      _query = q;
      _nextToken = null;
      _activeChip = chipIndex;
    });
    try {
      final r = await YoutubeService.search(q);
      setState(() {
        _results = r.videos;
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

  void _searchFromBox() {
    _runSearch(_ctrl.text.trim(), chipIndex: -1);
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _loading || _nextToken == null || _query.isEmpty) return;
    setState(() {
      _loadingMore = true;
    });
    try {
      final r = await YoutubeService.search(_query, pageToken: _nextToken);
      setState(() {
        _results.addAll(r.videos);
        _nextToken = r.nextPageToken;
        _loadingMore = false;
      });
    } catch (e) {
      setState(() {
        _loadingMore = false;
      });
    }
  }

  void _open(Video v) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PlayerScreen(videoId: v.id, title: v.title)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(context),
            _searchBar(cs),
            const SizedBox(height: 10),
            _chips(cs),
            const SizedBox(height: 6),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_error!, style: TextStyle(color: cs.error)),
              ),
            Expanded(child: _content(cs)),
          ],
        ),
      ),
    );
  }

  // ---- Header: gradient wordmark + tagline + theme toggle ----
  Widget _header(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text("🌊", style: TextStyle(fontSize: 22)),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                  colors: [_kGoldLight, _kGold],
                ).createShader(b),
                child: const Text(
                  "TideView",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: Colors.white,
                  ),
                ),
              ),
              Text(
                "Life at sea, on demand",
                style: TextStyle(
                  fontSize: 11.5,
                  color: cs.onSurface.withValues(alpha:0.5),
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            tooltip: "Toggle theme",
            style: IconButton.styleFrom(
              backgroundColor: cs.onSurface.withValues(alpha:0.06),
            ),
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
              size: 20,
            ),
            onPressed: widget.onToggleTheme,
          ),
        ],
      ),
    );
  }

  // ---- Search bar: soft pill with inline send button ----
  Widget _searchBar(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: cs.onSurface.withValues(alpha:0.055),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: cs.onSurface.withValues(alpha:0.06)),
        ),
        padding: const EdgeInsets.only(left: 16, right: 6),
        child: Row(
          children: [
            Icon(Icons.search, size: 20, color: cs.onSurface.withValues(alpha:0.55)),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _ctrl,
                textAlignVertical: TextAlignVertical.center,
                style: const TextStyle(fontSize: 14.5),
                decoration: const InputDecoration(
                  hintText: "Search cruise videos…",
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
                onSubmitted: (_) => _searchFromBox(),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [_kGoldLight, _kGold]),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: _searchFromBox,
                icon: const Icon(Icons.arrow_forward, size: 20, color: Colors.white),
                tooltip: "Search",
                constraints: const BoxConstraints.tightFor(width: 40, height: 40),
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Category chips: gradient when active ----
  Widget _chips(ColorScheme cs) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: kCategories.length,
        separatorBuilder: (_, index) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final active = i == _activeChip;
          return GestureDetector(
            onTap: () => _runSearch(kCategories[i], chipIndex: i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                gradient: active
                    ? const LinearGradient(colors: [_kGoldLight, _kGold])
                    : null,
                color: active ? null : cs.onSurface.withValues(alpha:0.055),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: active ? Colors.transparent : cs.onSurface.withValues(alpha:0.08),
                ),
              ),
              child: Text(
                kCategories[i],
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? Colors.white : cs.onSurface.withValues(alpha:0.75),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ---- Content: skeleton, empty, or hero + grid ----
  Widget _content(ColorScheme cs) {
    if (_loading) return _skeleton(cs);
    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.travel_explore, size: 48, color: cs.onSurface.withValues(alpha:0.3)),
            const SizedBox(height: 12),
            Text("No videos found",
                style: TextStyle(color: cs.onSurface.withValues(alpha:0.6), fontSize: 15)),
          ],
        ),
      );
    }

    final featured = _results.first;
    final rest = _results.length > 1 ? _results.sublist(1) : <Video>[];

    return CustomScrollView(
      controller: _scroll,
      slivers: [
        SliverToBoxAdapter(child: _heroCard(featured, cs)),
        SliverToBoxAdapter(child: _sectionTitle(cs)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 360,
              childAspectRatio: 0.80,
              crossAxisSpacing: 14,
              mainAxisSpacing: 18,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) => _videoCard(rest[i], cs),
              childCount: rest.length,
            ),
          ),
        ),
        if (_loadingMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(bottom: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
      ],
    );
  }

  Widget _sectionTitle(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Row(
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
          Text(
            "More to explore",
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  // ---- Featured hero card ----
  Widget _heroCard(Video v, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
      child: GestureDetector(
        onTap: () => _open(v),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: AspectRatio(
            aspectRatio: 16 / 10,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _thumb(v.thumbnail),
                // dark gradient for text legibility
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black54, Colors.black87],
                      stops: [0.35, 0.75, 1.0],
                    ),
                  ),
                ),
                // FEATURED pill
                Positioned(
                  top: 14,
                  left: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [_kGoldLight, _kGold]),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded, size: 14, color: Colors.white),
                        SizedBox(width: 4),
                        Text("FEATURED",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8)),
                      ],
                    ),
                  ),
                ),
                // bottom content
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 16,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              v.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                height: 1.15,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _avatar(v.channel, 11),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    v.channel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [_kGoldLight, _kGold]),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _kGold.withValues(alpha:0.5),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.play_arrow_rounded,
                            color: Colors.white, size: 32),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---- Grid video card ----
  Widget _videoCard(Video v, ColorScheme cs) {
    return GestureDetector(
      onTap: () => _open(v),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _thumb(v.thumbnail),
                  Center(
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha:0.42),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha:0.85), width: 1.5),
                      ),
                      child: const Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 26),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _avatar(v.channel, 14),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      v.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        height: 1.25,
                        color: cs.onSurface,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      v.channel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha:0.55),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---- Small circular channel avatar from the first letter ----
  Widget _avatar(String channel, double radius) {
    final letter = channel.isNotEmpty ? channel[0].toUpperCase() : "?";
    return Container(
      width: radius * 2,
      height: radius * 2,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kGoldLight, _kGold],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
      ),
      child: Text(
        letter,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: radius * 0.95,
        ),
      ),
    );
  }

  // ---- Network thumbnail with fade-in + graceful fallbacks ----
  Widget _thumb(String url) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(color: Colors.black.withValues(alpha:0.06));
      },
      errorBuilder: (context, error, stack) => Container(
        color: Colors.black.withValues(alpha:0.08),
        child: const Center(
          child: Icon(Icons.broken_image_outlined, color: Colors.white54),
        ),
      ),
    );
  }

  // ---- Shimmering skeleton while the first search loads ----
  Widget _skeleton(ColorScheme cs) {
    final c = cs.onSurface.withValues(alpha:0.08);
    Widget box(double h, {double? w, double r = 12}) => Container(
          height: h,
          width: w,
          decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(r)),
        );
    return _Shimmer(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          AspectRatio(aspectRatio: 16 / 10, child: box(0, r: 22)),
          const SizedBox(height: 24),
          box(18, w: 160),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 0.80,
            crossAxisSpacing: 14,
            mainAxisSpacing: 18,
            children: List.generate(4, (_) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(aspectRatio: 16 / 9, child: box(0, r: 16)),
                  const SizedBox(height: 10),
                  box(12, w: double.infinity),
                  const SizedBox(height: 6),
                  box(12, w: 90),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

// Gentle pulsing shimmer wrapper (no external package).
class _Shimmer extends StatefulWidget {
  final Widget child;
  const _Shimmer({required this.child});
  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Opacity(
        opacity: 0.4 + 0.5 * _c.value,
        child: child,
      ),
      child: widget.child,
    );
  }
}
