import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

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
  static const _chips = <(String, String)>[
    ('', 'Hot'),
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _player?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final q = _searchCtrl.text.trim();
      final tracks = _searching && q.isNotEmpty
          ? await _search(q)
          : _chip.isEmpty
              ? await _hot()
              : await _byTag(_chip);
      if (!mounted) return;
      setState(() {
        _tracks = tracks;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Tidak bisa memuat musik. Periksa koneksi lalu coba lagi.';
      });
    }
  }

  Future<void> _play(int index) async {
    final track = _tracks[index];
    await _player?.dispose();
    final c =
        VideoPlayerController.networkUrl(Uri.parse(track.audioUrl));
    setState(() {
      _player = c;
      _playing = index;
      _buffering = true;
    });
    try {
      await c.initialize();
      if (!mounted) return;
      setState(() => _buffering = false);
      await c.play();
      c.addListener(() {
        if (!mounted) return;
        final v = c.value;
        // Lagu selesai → putar berikutnya.
        if (v.isInitialized &&
            !v.isPlaying &&
            v.duration > Duration.zero &&
            v.position >= v.duration - const Duration(milliseconds: 300)) {
          if (_playing < _tracks.length - 1) _play(_playing + 1);
        }
        setState(() {});
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _buffering = false);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lagu ini tidak bisa diputar.')));
    }
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
                              onTap: () => _play(i),
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
                              width: 42, height: 42, fit: BoxFit.cover),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                                  color: Colors.white70, fontSize: 11.5)),
                        ],
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
