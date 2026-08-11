// TV Live — dibawa dari wca_app: panduan channel TV gratis (free-to-air)
// dari indeks publik iptv-org + pemutar HLS live.
//
// Model legalnya sama seperti Musik (Jamendo): iptv-org hanya membuat
// katalog siaran gratis yang memang dipublikasikan; aplikasi memutar
// langsung dari server penyiarnya. Tidak ada yang di-rehost, tanpa API
// key. Siaran gratis bisa mati/dibatasi wilayah sewaktu-waktu — pemutar
// menampilkannya sebagai "coba channel lain", bukan error aplikasi.
//
// Catatan web: Chrome tidak memutar HLS bawaan, jadi TV Live paling pas
// dipakai di aplikasi Android; di web sebagian besar channel akan jatuh
// ke pesan "coba channel lain".

import 'package:chewie/chewie.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

class TvChannel {
  final String name;
  final String url;
  final String logo;
  final String category;

  /// Sebagian penyiar hanya melayani stream bila header Referer ini
  /// dikirim (atribut http-referrer di playlist). Kosong = tidak perlu.
  final String referrer;

  const TvChannel({
    required this.name,
    required this.url,
    this.logo = '',
    this.category = 'TV',
    this.referrer = '',
  });
}

class TvRepository {
  // iptv-org menerbitkan satu playlist per negara; punya Indonesia kecil
  // dan sudah memuat logo + kategori, jadi satu fetch = satu panduan.
  static const _playlists = <String>[
    'https://iptv-org.github.io/iptv/countries/id.m3u',
  ];

  static List<TvChannel>? _cache;

  static Future<List<TvChannel>> load({bool refresh = false}) async {
    if (!refresh && _cache != null) return _cache!;
    for (final src in _playlists) {
      try {
        final r = await http
            .get(Uri.parse(src))
            .timeout(const Duration(seconds: 15));
        if (r.statusCode != 200) continue;
        final channels = parseM3u(r.body);
        if (channels.isNotEmpty) {
          _cache = channels;
          return channels;
        }
      } catch (_) {
        // lanjut ke sumber berikutnya / hasil kosong
      }
    }
    return _cache ?? const [];
  }

  /// Parse playlist M3U: baris #EXTINF membawa atribut (tvg-logo,
  /// group-title) dan nama setelah koma terakhir; baris non-komentar
  /// berikutnya adalah URL stream-nya. Publik agar bisa diuji.
  @visibleForTesting
  static List<TvChannel> parseM3u(String body) {
    final out = <TvChannel>[];
    String? name;
    String? logo;
    String? group;
    String? referrer;
    for (final raw in body.split('\n')) {
      final line = raw.trim();
      if (line.startsWith('#EXTINF')) {
        logo = RegExp(r'tvg-logo="([^"]*)"').firstMatch(line)?.group(1);
        group = RegExp(r'group-title="([^"]*)"').firstMatch(line)?.group(1);
        referrer =
            RegExp(r'http-referrer="([^"]*)"').firstMatch(line)?.group(1);
        final comma = line.lastIndexOf(',');
        name = comma >= 0 ? line.substring(comma + 1).trim() : '';
      } else if (line.startsWith('#EXTVLCOPT:http-referrer=')) {
        referrer ??= line.substring('#EXTVLCOPT:http-referrer='.length);
      } else if (line.isNotEmpty && !line.startsWith('#')) {
        if (name != null && name.isNotEmpty) {
          // group-title bisa "News;General" — tag pertama jadi kategori.
          var cat = (group ?? '').split(';').first.trim();
          if (cat.isEmpty || cat.toLowerCase() == 'undefined') cat = 'Umum';
          out.add(TvChannel(
            name: _cleanName(name),
            url: line,
            logo: logo ?? '',
            category: cat,
            referrer: referrer ?? '',
          ));
        }
        name = null;
        logo = null;
        group = null;
        referrer = null;
      }
    }
    return out;
  }

  /// Bersihkan nama: sufiks kualitas "(1080p)" dan tag "[Not 24/7]".
  static String _cleanName(String n) {
    return n
        .replaceAll(RegExp(r'\s*\(\d+p\)'), '')
        .replaceAll(RegExp(r'\s*\[[^\]]*\]'), '')
        .trim();
  }

  // ---- pemeriksaan siaran ------------------------------------------------
  // Siaran gratis mati dan dibatasi wilayah tanpa kabar; memeriksa
  // playlist tiap channel memberi tahu mana yang benar-benar MENGUDARA.
  // Di web dilewati (CORS membuat semua pemeriksaan gagal semu).

  /// url -> hidup. Tidak ada = belum diperiksa; hanya url .m3u8.
  static final Map<String, bool> liveStatus = {};
  static int _probedAt = 0;

  static Future<void> probeAll(
      List<TvChannel> channels, void Function() onUpdate) async {
    if (kIsWeb) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _probedAt >= 10 * 60 * 1000) liveStatus.clear();
    _probedAt = now;
    final targets = channels
        .where((c) =>
            c.url.contains('m3u8') && !liveStatus.containsKey(c.url))
        .toList();
    if (targets.isEmpty) return;
    var i = 0;
    Future<void> worker() async {
      while (i < targets.length) {
        final c = targets[i++];
        liveStatus[c.url] = await _probe(c);
        onUpdate();
      }
    }

    await Future.wait([for (var k = 0; k < 8; k++) worker()]);
  }

  static Future<bool> _probe(TvChannel c) async {
    try {
      final r = await http
          .get(Uri.parse(c.url),
              headers:
                  c.referrer.isEmpty ? null : {'Referer': c.referrer})
          .timeout(const Duration(seconds: 6));
      return r.statusCode == 200 && r.body.contains('#EXTM3U');
    } catch (_) {
      return false;
    }
  }

  /// Kategori unik sesuai urutan katalog, 'Semua' di depan.
  static List<String> categories(List<TvChannel> channels) {
    final seen = <String>{};
    final out = <String>['Semua'];
    for (final c in channels) {
      if (seen.add(c.category)) out.add(c.category);
    }
    return out;
  }
}

class TvScreen extends StatefulWidget {
  const TvScreen({super.key});

  @override
  State<TvScreen> createState() => _TvScreenState();
}

class _TvScreenState extends State<TvScreen> {
  List<TvChannel>? _channels;
  bool _failed = false;
  String _cat = 'Semua';
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    setState(() {
      _channels = null;
      _failed = false;
    });
    final list = await TvRepository.load(refresh: refresh);
    if (!mounted) return;
    setState(() {
      _channels = list;
      _failed = list.isEmpty;
    });
    // Periksa channel yang mengudara; gambar ulang bertahap (di-throttle).
    var pending = 0;
    TvRepository.probeAll(list, () {
      pending++;
      if (pending % 5 == 0 && mounted) setState(() {});
    }).then((_) {
      if (mounted) setState(() {});
    });
  }

  List<TvChannel> get _visible {
    final all = _channels ?? const <TvChannel>[];
    final q = _query.trim().toLowerCase();
    final filtered = all.where((c) {
      if (_cat != 'Semua' && c.category != _cat) return false;
      if (q.isNotEmpty && !c.name.toLowerCase().contains(q)) return false;
      return true;
    }).toList();
    // Mengudara dulu, lalu belum diketahui, mati paling bawah.
    int rank(TvChannel c) {
      final s = TvRepository.liveStatus[c.url];
      if (s == true) return 0;
      if (s == null) return 1;
      return 2;
    }

    filtered.sort((a, b) => rank(a).compareTo(rank(b)));
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1220),
        foregroundColor: Colors.white,
        title: const Text('TV Live',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            icon: const Icon(Icons.refresh),
            onPressed: () => _load(refresh: true),
          ),
        ],
      ),
      body: SafeArea(
        child: _channels == null
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white))
            : _failed
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('📡', style: TextStyle(fontSize: 40)),
                        const SizedBox(height: 12),
                        const Text('Gagal memuat daftar channel.',
                            style: TextStyle(color: Colors.white70)),
                        TextButton(
                            onPressed: _load,
                            child: const Text('Coba lagi')),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                        child: TextField(
                          onChanged: (v) => setState(() => _query = v),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Cari channel...',
                            hintStyle:
                                const TextStyle(color: Colors.white38),
                            prefixIcon: const Icon(Icons.search,
                                color: Colors.white38),
                            filled: true,
                            fillColor: Colors.white10,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none),
                            isDense: true,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 40,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          children: [
                            for (final c
                                in TvRepository.categories(_channels!))
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4),
                                child: ChoiceChip(
                                  label: Text(c),
                                  selected: _cat == c,
                                  onSelected: (_) =>
                                      setState(() => _cat = c),
                                  labelStyle: TextStyle(
                                      color: _cat == c
                                          ? Colors.black
                                          : Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600),
                                  selectedColor:
                                      const Color(0xFF6EE7F0),
                                  backgroundColor:
                                      const Color(0xFF24395E),
                                  side: BorderSide.none,
                                  showCheckmark: false,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: _visible.isEmpty
                            ? const Center(
                                child: Text('Tidak ada channel.',
                                    style: TextStyle(
                                        color: Colors.white38)))
                            : GridView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                    12, 8, 12, 16),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  mainAxisSpacing: 10,
                                  crossAxisSpacing: 10,
                                  childAspectRatio: 0.86,
                                ),
                                itemCount: _visible.length,
                                itemBuilder: (context, i) =>
                                    _ChannelCard(
                                  channel: _visible[i],
                                  onTap: () =>
                                      Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            _TvPlayerScreen(
                                                channel: _visible[i])),
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _ChannelCard extends StatelessWidget {
  final TvChannel channel;
  final VoidCallback onTap;
  const _ChannelCard({required this.channel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Opacity(
        // Channel yang terdeteksi mati tetap bisa diketuk (pemeriksaan
        // bisa keliru) tapi tampak redup.
        opacity: TvRepository.liveStatus[channel.url] == false ? 0.35 : 1,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF16233F),
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.all(10),
          child: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: channel.logo.isEmpty
                        ? const Center(
                            child: Icon(Icons.live_tv,
                                color: Colors.white38, size: 36))
                        : Image.network(
                            channel.logo,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const Center(
                                child: Icon(Icons.live_tv,
                                    color: Colors.white38, size: 36)),
                          ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    channel.name,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              if (TvRepository.liveStatus[channel.url] == true)
                const Positioned(top: 0, left: 0, child: _LiveBadge()),
            ],
          ),
        ),
      ),
    );
  }
}

/// Titik merah berdenyut + label LIVE untuk channel yang mengudara.
class _LiveBadge extends StatefulWidget {
  const _LiveBadge();

  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _anim,
            builder: (context, _) {
              final t = 0.45 + 0.55 * _anim.value;
              return Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFF3B30).withValues(alpha: t),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF3B30)
                          .withValues(alpha: 0.6 * _anim.value),
                      blurRadius: 6,
                      spreadRadius: 1.5 * _anim.value,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 4),
          const Text('LIVE',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8)),
        ],
      ),
    );
  }
}

/// Pemutar live. Siaran gratis mati/dibatasi wilayah tanpa kabar — semua
/// kegagalan berujung pesan ramah "coba channel lain", bukan layar merah.
class _TvPlayerScreen extends StatefulWidget {
  final TvChannel channel;
  const _TvPlayerScreen({required this.channel});

  @override
  State<_TvPlayerScreen> createState() => _TvPlayerScreenState();
}

class _TvPlayerScreenState extends State<_TvPlayerScreen> {
  VideoPlayerController? _video;
  ChewieController? _chewie;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final v = VideoPlayerController.networkUrl(
        Uri.parse(widget.channel.url),
        httpHeaders: widget.channel.referrer.isEmpty
            ? const <String, String>{}
            : {'Referer': widget.channel.referrer},
      );
      _video = v;
      await v.initialize().timeout(const Duration(seconds: 20));
      if (!mounted) return;
      _chewie = ChewieController(
        videoPlayerController: v,
        autoPlay: true,
        isLive: true,
        allowFullScreen: true,
        allowPlaybackSpeedChanging: false,
        aspectRatio:
            v.value.aspectRatio > 0.1 ? v.value.aspectRatio : 16 / 9,
      );
      setState(() {});
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  void dispose() {
    _chewie?.dispose();
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.channel.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 15)),
      ),
      body: Center(
        child: _error
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('📺', style: TextStyle(fontSize: 40)),
                    const SizedBox(height: 12),
                    const Text(
                      'Channel ini sedang tidak bisa diputar.\n'
                      'Siaran gratis kadang mati atau dibatasi wilayah.\n'
                      'Coba channel lain ya.',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Kembali')),
                  ],
                ),
              )
            : _chewie == null
                ? const CircularProgressIndicator(color: Colors.white)
                : Chewie(controller: _chewie!),
      ),
    );
  }
}
