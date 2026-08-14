import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../format.dart';
import '../../store.dart';

/// Video musik Indonesia dari channel YouTube resmi musisi/label
/// (daftar dirangkai server dari RSS publik, tanpa API key).
/// Pemutaran memakai player embed resmi YouTube — legal, lisensi
/// tetap di pemilik channel.
class VideoMusikScreen extends StatefulWidget {
  const VideoMusikScreen({super.key});

  @override
  State<VideoMusikScreen> createState() => _VideoMusikScreenState();
}

class MusikVideo {
  MusikVideo({
    required this.id,
    required this.title,
    required this.channel,
    required this.at,
  });

  final String id;
  final String title;
  final String channel;
  final DateTime at;

  factory MusikVideo.fromMap(Map<String, dynamic> m) => MusikVideo(
        id: m['id'] as String? ?? '',
        title: m['title'] as String? ?? '',
        channel: m['channel'] as String? ?? '',
        at: DateTime.tryParse(m['at'] as String? ?? '')?.toLocal() ??
            DateTime.now(),
      );
}

/// Thumbnail lewat proxy server (i.ytimg.com tidak mengirim CORS).
String musikVideoThumb(String id) => '${store.apiUrl}/api/ytimg?v=$id';

class _VideoMusikScreenState extends State<VideoMusikScreen> {
  List<MusikVideo>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final a = store.api;
    if (a == null) {
      setState(
          () => _error = 'Video musik membutuhkan koneksi ke server.');
      return;
    }
    try {
      final m = await a.getMusikVideo();
      if (!mounted) return;
      setState(() {
        _items = ((m['items'] as List?) ?? [])
            .map((e) =>
                MusikVideo.fromMap((e as Map).cast<String, dynamic>()))
            .where((v) => v.id.isNotEmpty)
            .toList();
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Tidak bisa memuat video. Coba lagi.');
    }
  }

  void _openPlayer(MusikVideo v) {
    final items = _items ?? [];
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(video: v, playlist: items)));
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      appBar: AppBar(title: const Text('Video Musik')),
      body: SafeArea(
        child: _error != null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                        onPressed: () {
                          setState(() => _error = null);
                          _load();
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Coba lagi')),
                  ],
                ),
              )
            : items == null
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: GridView.builder(
                      padding: const EdgeInsets.all(14),
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount:
                            MediaQuery.sizeOf(context).width > 680
                                ? 3
                                : MediaQuery.sizeOf(context).width > 440
                                    ? 2
                                    : 1,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 16 / 13.5,
                      ),
                      itemCount: items.length,
                      itemBuilder: (context, i) =>
                          _VideoCard(v: items[i], onTap: _openPlayer),
                    ),
                  ),
      ),
    );
  }
}

class _VideoCard extends StatelessWidget {
  const _VideoCard({required this.v, required this.onTap});

  final MusikVideo v;
  final void Function(MusikVideo) onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => onTap(v),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    musikVideoThumb(v.id),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: const Color(0xFF0F172A),
                      alignment: Alignment.center,
                      child: const Icon(Icons.music_video,
                          size: 40, color: Color(0xFF64748B)),
                    ),
                  ),
                  Center(
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 32),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      v.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.25,
                          fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    Text(
                      '${v.channel} • ${timeAgo(v.at)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Layar pemutar: player embed resmi YouTube di atas, daftar video
/// lain di bawah untuk lanjut menonton tanpa keluar layar.
class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen(
      {super.key, required this.video, required this.playlist});

  final MusikVideo video;
  final List<MusikVideo> playlist;

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late MusikVideo _current = widget.video;
  late final YoutubePlayerController _controller =
      YoutubePlayerController.fromVideoId(
    videoId: widget.video.id,
    autoPlay: true,
    params: const YoutubePlayerParams(
      showFullscreenButton: true,
      strictRelatedVideos: true,
    ),
  );

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  void _play(MusikVideo v) {
    _controller.loadVideoById(videoId: v.id);
    setState(() => _current = v);
  }

  @override
  Widget build(BuildContext context) {
    final others =
        widget.playlist.where((v) => v.id != _current.id).toList();
    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      appBar: AppBar(
        // Tema global memakai AppBar terang + judul gelap; layar pemutar
        // gelap, jadi warna dikunci eksplisit di sini.
        backgroundColor: const Color(0xFF0B1220),
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        // Gaya inline pada Text (bukan titleTextStyle) supaya fontFamily
        // ikut DefaultTextStyle — titleTextStyle membuat teks tak
        // terlihat pada build --no-web-resources-cdn.
        title: const Text('Video Musik',
            style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            YoutubePlayer(
                controller: _controller, aspectRatio: 16 / 9),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _current.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15.5,
                        height: 1.3,
                        fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_current.channel} • ${timeAgo(_current.at)} • '
                    'YouTube',
                    style: const TextStyle(
                        color: Color(0xFF94A3B8), fontSize: 12.5),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFF1E293B)),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
                itemCount: others.length,
                itemBuilder: (context, i) {
                  final v = others[i];
                  return InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _play(v),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 6),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 116,
                              height: 65,
                              child: Image.network(
                                musikVideoThumb(v.id),
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(
                                  color: const Color(0xFF1E293B),
                                  alignment: Alignment.center,
                                  child: const Icon(Icons.music_video,
                                      color: Color(0xFF64748B)),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  v.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      height: 1.25,
                                      fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  v.channel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 11.5),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
