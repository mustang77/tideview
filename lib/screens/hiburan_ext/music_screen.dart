import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

import '../../store.dart';
import 'luna_visualizer.dart';

/// Musik gratis (Creative Commons) dari Jamendo — mesin yang sama
/// dengan fitur musik wca_app, dikemas ulang ringkas untuk H2O.
const _jamendoApi = 'https://api.jamendo.com/v3.0';
const _jamendoClientId = 'dda48f8d';

/// Satu lagu Jamendo (model dibawa dari wca_app).
class Track {
  const Track({
    required this.id,
    required this.name,
    required this.artist,
    required this.audioUrl,
    required this.imageUrl,
    required this.durationSec,
  });

  final String id;
  final String name;
  final String artist;
  final String audioUrl;
  final String imageUrl;
  final int durationSec;

  factory Track.fromJson(Map<String, dynamic> j) => Track(
        id: (j['id'] ?? '').toString(),
        name: (j['name'] ?? 'Tanpa Judul').toString(),
        artist: (j['artist_name'] ?? 'Tidak dikenal').toString(),
        audioUrl: (j['audio'] ?? '').toString(),
        imageUrl: (j['image'] ?? j['album_image'] ?? '').toString(),
        durationSec: (j['duration'] is num)
            ? (j['duration'] as num).toInt()
            : int.tryParse('${j['duration']}') ?? 0,
      );
}

Future<List<Track>> _fetchTracks(Uri uri) async {
  final res = await http.get(uri).timeout(const Duration(seconds: 12));
  if (res.statusCode != 200) {
    throw Exception('Music API error ${res.statusCode}');
  }
  final body = jsonDecode(res.body) as Map<String, dynamic>;
  return ((body['results'] as List?) ?? const [])
      .whereType<Map<String, dynamic>>()
      .map(Track.fromJson)
      .where((t) => t.audioUrl.isNotEmpty)
      .toList();
}

Future<List<Track>> _hot({int limit = 30}) => _fetchTracks(Uri.parse(
    '$_jamendoApi/tracks/?client_id=$_jamendoClientId'
    '&format=json&limit=$limit&order=popularity_week&audioformat=mp32'));

Future<List<Track>> _byTag(String tags, {int limit = 40}) =>
    _fetchTracks(Uri.parse(
        '$_jamendoApi/tracks/?client_id=$_jamendoClientId'
        '&format=json&limit=$limit'
        '&fuzzytags=${Uri.encodeQueryComponent(tags)}'
        '&order=popularity_week&audioformat=mp32'));

Future<List<Track>> _search(String q, {int limit = 40}) =>
    _fetchTracks(Uri.parse(
        '$_jamendoApi/tracks/?client_id=$_jamendoClientId'
        '&format=json&limit=$limit'
        '&search=${Uri.encodeQueryComponent(q.trim())}&audioformat=mp32'));

/// Layar Musik: kategori + cari + daftar lagu, dengan pemutar mini di
/// bawah (putar/jeda/berikutnya). Audio diputar lewat video_player.
class MusicScreen extends StatefulWidget {
  const MusicScreen({super.key});

  @override
  State<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends State<MusicScreen> {
  /// '__indo' = katalog netlabel Indonesia dari server (bukan Jamendo).
  static const _chips = <(String, String)>[
    ('', 'Hot'),
    ('__indo', 'Indonesia 🇮🇩'),
    ('pop', 'Pop'),
    ('chillout lofi', 'Santai'),
    ('acoustic', 'Akustik'),
    ('dance electro', 'Dance'),
  ];

  String _chip = '';
  bool _searching = false;
  final _searchCtrl = TextEditingController();

  List<Track> _tracks = const [];
  bool _loading = true;
  String _error = '';

  VideoPlayerController? _player;
  int _playing = -1; // index di _tracks
  bool _buffering = false;

  /// Denyut perubahan pemutar — layar Now Playing yang sedang terbuka
  /// ikut membangun ulang lewat notifier ini (posisi, ganti lagu, dll).
  final ValueNotifier<int> _tick = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _player?.dispose();
    _tick.dispose();
    super.dispose();
  }

  /// Penjaga urutan: pemuatan lama yang baru selesai (mis. Jamendo
  /// timeout) tidak boleh menimpa hasil chip yang dipilih setelahnya.
  int _loadSeq = 0;

  Future<void> _load() async {
    final seq = ++_loadSeq;
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final q = _searchCtrl.text.trim();
      final List<Track> tracks;
      if (_searching && q.isNotEmpty) {
        tracks = await _search(q);
      } else if (_chip == '__indo') {
        // Musik Indonesia: netlabel CC (Yes No Wave dkk) via server.
        final a = store.api;
        if (a == null) throw Exception('offline');
        final m = await a.getMusikIndonesia();
        tracks = ((m['results'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(Track.fromJson)
            .where((t) => t.audioUrl.isNotEmpty)
            .toList();
      } else if (_chip.isEmpty) {
        tracks = await _hot();
      } else {
        tracks = await _byTag(_chip);
      }
      if (!mounted || seq != _loadSeq) return;
      setState(() {
        _tracks = tracks;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || seq != _loadSeq) return;
      setState(() {
        _loading = false;
        _error = 'Tidak bisa memuat musik. Periksa koneksi lalu coba lagi.';
      });
    }
  }

  /// Nomor urut pemutaran: ketukan lagu baru membatalkan pemutaran
  /// yang masih menyiapkan diri (anti balapan ketuk beruntun).
  int _playSeq = 0;

  Future<void> _play(int index) async {
    final track = _tracks[index];
    final seq = ++_playSeq;
    final old = _player;
    // Status di-set SEBELUM await pertama supaya layar Now Playing
    // yang dibuka bersamaan langsung menampilkan lagu yang benar.
    setState(() {
      _player = null;
      _playing = index;
      _buffering = true;
    });
    _tick.value++;
    await old?.dispose();
    final c =
        VideoPlayerController.networkUrl(Uri.parse(track.audioUrl));
    if (!mounted || seq != _playSeq) {
      await c.dispose();
      return;
    }
    setState(() => _player = c);
    try {
      await c.initialize();
      if (!mounted || seq != _playSeq) return;
      setState(() => _buffering = false);
      await c.play();
      c.addListener(() {
        if (!mounted || seq != _playSeq) return;
        final v = c.value;
        // Lagu selesai → putar berikutnya.
        if (v.isInitialized &&
            !v.isPlaying &&
            v.duration > Duration.zero &&
            v.position >= v.duration - const Duration(milliseconds: 300)) {
          if (_playing < _tracks.length - 1) _play(_playing + 1);
        }
        _tick.value++;
        setState(() {});
      });
      _tick.value++;
    } catch (_) {
      if (!mounted || seq != _playSeq) return;
      setState(() => _buffering = false);
      _tick.value++;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lagu ini tidak bisa diputar.')));
    }
  }

  void _toggle() {
    final p = _player;
    if (p == null || !p.value.isInitialized) return;
    setState(() {
      p.value.isPlaying ? p.pause() : p.play();
    });
    _tick.value++;
  }

  void _next() {
    if (_playing < _tracks.length - 1) _play(_playing + 1);
  }

  void _prev() {
    if (_playing > 0) _play(_playing - 1);
  }

  /// Layar Now Playing gaya Spotify (dibawa dari wca_app): sampul
  /// penuh layar, slider geser, kontrol besar, usap atas/bawah untuk
  /// ganti lagu.
  void _openNowPlaying() {
    if (_playing < 0) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => NowPlayingScreen(
        tick: _tick,
        trackOf: () => _playing >= 0 && _playing < _tracks.length
            ? _tracks[_playing]
            : null,
        playerOf: () => _player,
        bufferingOf: () => _buffering,
        onToggle: _toggle,
        onNext: _next,
        onPrev: _prev,
      ),
    ));
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final playingTrack =
        _playing >= 0 && _playing < _tracks.length ? _tracks[_playing] : null;
    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Cari lagu atau artis...',
                  border: InputBorder.none,
                  filled: false,
                ),
                onSubmitted: (_) => _load(),
              )
            : const Text('Musik'),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) {
                _searchCtrl.clear();
                _load();
              }
            }),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (!_searching)
              SizedBox(
                height: 46,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    for (final (tag, label) in _chips)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(label),
                          selected: _chip == tag,
                          onSelected: (_) {
                            setState(() => _chip = tag);
                            _load();
                          },
                        ),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: _loadingBody(playingTrack, theme),
            ),
            if (playingTrack != null) _miniPlayer(playingTrack),
          ],
        ),
      ),
    );
  }

  Widget _loadingBody(Track? playingTrack, ThemeData theme) {
    return _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error.isNotEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_error, textAlign: TextAlign.center),
                                const SizedBox(height: 12),
                                FilledButton(
                                    onPressed: _load,
                                    child: const Text('Coba Lagi')),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.only(
                              bottom: playingTrack != null ? 90 : 16),
                          itemCount: _tracks.length,
                          itemBuilder: (context, i) {
                            final t = _tracks[i];
                            final active = i == _playing;
                            return ListTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: t.imageUrl.isEmpty
                                    ? Container(
                                        width: 46,
                                        height: 46,
                                        color: const Color(0xFFB3E3F0),
                                        child: const Icon(
                                            Icons.music_note,
                                            color: Color(0xFF0E7490)),
                                      )
                                    : Image.network(t.imageUrl,
                                        width: 46,
                                        height: 46,
                                        fit: BoxFit.cover,
                                        errorBuilder: (c, _, _) =>
                                            Container(
                                              width: 46,
                                              height: 46,
                                              color:
                                                  const Color(0xFFB3E3F0),
                                              child: const Icon(
                                                  Icons.music_note,
                                                  color:
                                                      Color(0xFF0E7490)),
                                            )),
                              ),
                              title: Text(t.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontWeight: active
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                      color: active
                                          ? theme.colorScheme.primary
                                          : null)),
                              subtitle: Text(t.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              trailing: active
                                  ? Icon(
                                      _buffering
                                          ? Icons.downloading
                                          : (_player?.value.isPlaying ??
                                                  false)
                                              ? Icons.graphic_eq
                                              : Icons.pause,
                                      color: theme.colorScheme.primary)
                                  : Text(_fmt(
                                      Duration(seconds: t.durationSec))),
                              // Langsung buka Now Playing penuh —
                              // tanpa mampir ke pemutar mini.
                              onTap: () {
                                _play(i);
                                _openNowPlaying();
                              },
                            );
                          },
                        );
  }

  Widget _miniPlayer(Track playingTrack) {
    return Container(
              color: const Color(0xFF0E2A33),
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    // Ketuk sampul/judul untuk membuka Now Playing penuh.
                    Expanded(
                      child: InkWell(
                        onTap: _openNowPlaying,
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: playingTrack.imageUrl.isEmpty
                                  ? Container(
                                      width: 42,
                                      height: 42,
                                      color: Colors.white24,
                                      child: const Icon(Icons.music_note,
                                          color: Colors.white))
                                  : Image.network(playingTrack.imageUrl,
                                      width: 42,
                                      height: 42,
                                      fit: BoxFit.cover),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(playingTrack.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13.5)),
                                  Text(playingTrack.artist,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 11.5)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_previous,
                          color: Colors.white),
                      onPressed: _playing > 0
                          ? () => _play(_playing - 1)
                          : null,
                    ),
                    IconButton(
                      icon: _buffering
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Icon(
                              (_player?.value.isPlaying ?? false)
                                  ? Icons.pause_circle_filled
                                  : Icons.play_circle_filled,
                              color: Colors.white,
                              size: 34),
                      onPressed: () {
                        final p = _player;
                        if (p == null || !p.value.isInitialized) return;
                        setState(() {
                          p.value.isPlaying ? p.pause() : p.play();
                        });
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_next,
                          color: Colors.white),
                      onPressed: _playing < _tracks.length - 1
                          ? () => _play(_playing + 1)
                          : null,
                    ),
                  ],
                ),
              ),
            );
  }
}

/// Layar Now Playing gaya Spotify (dibawa dari wca_app): sampul lagu
/// jadi latar penuh layar dengan scrim gelap, slider geser dengan
/// waktu, kontrol besar, dan usapan vertikal untuk ganti lagu.
class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({
    super.key,
    required this.tick,
    required this.trackOf,
    required this.playerOf,
    required this.bufferingOf,
    required this.onToggle,
    required this.onNext,
    required this.onPrev,
  });

  /// Denyut dari layar Musik: setiap perubahan pemutar menaikkan nilai
  /// ini sehingga layar ini ikut segar (termasuk auto-lanjut lagu).
  final ValueNotifier<int> tick;
  final Track? Function() trackOf;
  final VideoPlayerController? Function() playerOf;
  final bool Function() bufferingOf;
  final VoidCallback onToggle;
  final VoidCallback onNext;
  final VoidCallback onPrev;

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  /// Posisi jempol saat slider sedang digeser (null = ikuti pemutar).
  double? _dragValue;

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// Latar saat lagu tanpa sampul: gradasi biru laut.
  Widget _bgFallback() => const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1B4E77),
              Color(0xFF0A1A2F),
              Color(0xFF060E18)
            ],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: widget.tick,
      builder: (context, _, _) {
        final track = widget.trackOf();
        final player = widget.playerOf();
        if (track == null) {
          return Scaffold(
              backgroundColor: const Color(0xFF0A1A2F),
              appBar: AppBar(backgroundColor: Colors.transparent));
        }
        final v = player?.value;
        final pos = v?.position ?? Duration.zero;
        final dur = (v?.duration ?? Duration.zero) > Duration.zero
            ? v!.duration
            : Duration(seconds: track.durationSec);
        final total = dur.inMilliseconds;
        final value = total == 0
            ? 0.0
            : (pos.inMilliseconds / total).clamp(0.0, 1.0);
        final playing = v?.isPlaying ?? false;
        final buffering = widget.bufferingOf();

        return Scaffold(
          backgroundColor: const Color(0xFF0A1A2F),
          body: GestureDetector(
            // Usap ke atas = lagu berikutnya; ke bawah = sebelumnya.
            onVerticalDragEnd: (d) {
              final vel = d.primaryVelocity ?? 0;
              if (vel < -300) {
                widget.onNext();
              } else if (vel > 300) {
                widget.onPrev();
              }
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Sampul jadi latar penuh layar.
                if (track.imageUrl.isNotEmpty)
                  Image.network(
                    track.imageUrl,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) => _bgFallback(),
                  )
                else
                  _bgFallback(),
                // Scrim: gelap di bawah agar teks putih selalu terbaca.
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x66000000),
                        Color(0x99060E18),
                        Color(0xF2060E18),
                      ],
                      stops: [0.0, 0.5, 0.86],
                    ),
                  ),
                ),
                SafeArea(
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          icon: const Icon(Icons.keyboard_arrow_down,
                              color: Colors.white, size: 30),
                          onPressed: () =>
                              Navigator.of(context).maybePop(),
                        ),
                      ),
                      // Visualizer LUNA: piringan sampul berputar +
                      // cincin batang spektrum menari.
                      Expanded(
                        child: Center(
                          child: LayoutBuilder(
                            builder: (context, box) => LunaVisualizer(
                              seed: track.name,
                              imageUrl: track.imageUrl,
                              playing: playing,
                              position: pos,
                              size: math.min(
                                  math.min(box.maxWidth - 56,
                                      box.maxHeight - 16),
                                  340),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding:
                            const EdgeInsets.fromLTRB(24, 0, 24, 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment:
                              CrossAxisAlignment.stretch,
                          children: [
                            Text(track.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white)),
                            const SizedBox(height: 4),
                            Text(track.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 15,
                                    color: Colors.white70)),
                            const SizedBox(height: 14),
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 3,
                                activeTrackColor: Colors.white,
                                inactiveTrackColor: Colors.white24,
                                thumbColor: Colors.white,
                                overlayColor: Colors.white24,
                                thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 6),
                              ),
                              child: Slider(
                                value: _dragValue ?? value,
                                onChanged: (nv) {
                                  // Geser jempolnya saja; seek baru
                                  // dikirim saat geseran selesai.
                                  setState(() => _dragValue = nv);
                                },
                                onChangeEnd: (nv) {
                                  final ms = (nv * total).round();
                                  player?.seekTo(
                                      Duration(milliseconds: ms));
                                  setState(() => _dragValue = null);
                                },
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                      _fmt(_dragValue == null
                                          ? pos
                                          : Duration(
                                              milliseconds: (_dragValue! *
                                                      total)
                                                  .round())),
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.white60)),
                                  Text(_fmt(dur),
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.white60)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  iconSize: 40,
                                  color: Colors.white,
                                  icon:
                                      const Icon(Icons.skip_previous),
                                  onPressed: widget.onPrev,
                                ),
                                const SizedBox(width: 20),
                                buffering
                                    ? const SizedBox(
                                        width: 72,
                                        height: 72,
                                        child: Padding(
                                          padding: EdgeInsets.all(18),
                                          child:
                                              CircularProgressIndicator(
                                                  color: Colors.white,
                                                  strokeWidth: 3),
                                        ),
                                      )
                                    : IconButton(
                                        iconSize: 72,
                                        color: Colors.white,
                                        icon: Icon(playing
                                            ? Icons.pause_circle_filled
                                            : Icons
                                                .play_circle_filled),
                                        onPressed: widget.onToggle,
                                      ),
                                const SizedBox(width: 20),
                                IconButton(
                                  iconSize: 40,
                                  color: Colors.white,
                                  icon: const Icon(Icons.skip_next),
                                  onPressed: widget.onNext,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Center(
                              child: Text(
                                'Usap ke atas: lagu berikutnya',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white38),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
