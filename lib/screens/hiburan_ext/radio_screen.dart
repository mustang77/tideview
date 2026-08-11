// Radio Online — dibawa dari wca_app: direktori komunitas
// radio-browser.info (gratis & terbuka) + pencarian, dengan daftar
// cadangan bawaan supaya layar tidak pernah kosong. Pemutar memakai
// video_player sebagai backend audio (pola yang sama dengan Musik).

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

class RadioStation {
  final String name;
  final String city; // kota / tag, hanya untuk tampilan
  final String streamUrl;
  final String logoUrl;

  const RadioStation({
    required this.name,
    this.city = '',
    required this.streamUrl,
    this.logoUrl = '',
  });

  factory RadioStation.fromApi(Map<String, dynamic> j) {
    final tags = (j['tags'] ?? '') as String;
    final state = (j['state'] ?? '') as String;
    return RadioStation(
      name: ((j['name'] ?? '') as String).trim(),
      city: state.isNotEmpty ? state : tags.split(',').take(2).join(', '),
      streamUrl: ((j['url_resolved'] ?? j['url'] ?? '') as String).trim(),
      logoUrl: (j['favicon'] ?? '') as String,
    );
  }
}

class RadioRepository {
  // Cermin radio-browser.info, dicoba berurutan — proyeknya meminta
  // klien menyebar beban antar cermin.
  static const _mirrors = [
    'de1.api.radio-browser.info',
    'nl1.api.radio-browser.info',
    'at1.api.radio-browser.info',
  ];

  static Future<List<RadioStation>> _get(String pathAndQuery) async {
    for (final host in _mirrors) {
      try {
        final r = await http.get(
          Uri.parse('https://$host$pathAndQuery'),
          headers: const {'User-Agent': 'H2OLaundry/1.0'},
        ).timeout(const Duration(seconds: 10));
        if (r.statusCode != 200) continue;
        final list = jsonDecode(r.body) as List;
        final out = <RadioStation>[];
        final seen = <String>{};
        for (final j in list) {
          final s = RadioStation.fromApi(j as Map<String, dynamic>);
          if (s.name.isEmpty || s.streamUrl.isEmpty) continue;
          // Direktorinya penuh relay kembar; simpan satu per nama.
          if (!seen.add(s.name.toLowerCase())) continue;
          out.add(s);
        }
        return out;
      } catch (_) {
        // Coba cermin berikutnya.
      }
    }
    return [];
  }

  /// Stasiun Indonesia paling banyak didengar, stream sehat saja.
  static Future<List<RadioStation>> fetchIndonesian({int limit = 120}) =>
      _get('/json/stations/bycountrycodeexact/ID'
          '?hidebroken=true&order=clickcount&reverse=true&limit=$limit');

  /// Cari berdasarkan nama (tidak dibatasi Indonesia).
  static Future<List<RadioStation>> search(String q) => _get(
      '/json/stations/search?name=${Uri.encodeComponent(q.trim())}'
      '&hidebroken=true&order=clickcount&reverse=true&limit=60');

  /// Cadangan bawaan (mount publik terkenal) bila direktori tak
  /// terjangkau.
  static const fallback = <RadioStation>[
    RadioStation(
        name: 'Prambors FM',
        city: 'Jakarta',
        streamUrl:
            'https://playerservices.streamtheworld.com/api/livestream-redirect/PRAMBORSFM.mp3'),
    RadioStation(
        name: 'Gen FM',
        city: 'Jakarta',
        streamUrl:
            'https://playerservices.streamtheworld.com/api/livestream-redirect/GENFM.mp3'),
    RadioStation(
        name: 'Delta FM',
        city: 'Jakarta',
        streamUrl:
            'https://playerservices.streamtheworld.com/api/livestream-redirect/DELTAFM.mp3'),
    RadioStation(
        name: 'Radio Elshinta',
        city: 'Jakarta',
        streamUrl: 'http://streaming.elshinta.com:8000/live'),
  ];
}

class RadioScreen extends StatefulWidget {
  const RadioScreen({super.key});

  @override
  State<RadioScreen> createState() => _RadioScreenState();
}

class _RadioScreenState extends State<RadioScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  List<RadioStation>? _directory; // null = memuat
  List<RadioStation>? _results; // non-null saat mencari

  // Pemutar: video_player sebagai backend audio stream (mp3/aac).
  VideoPlayerController? _player;
  RadioStation? _nowPlaying;
  bool _connecting = false;

  @override
  void initState() {
    super.initState();
    _loadDirectory();
  }

  Future<void> _loadDirectory() async {
    final list = await RadioRepository.fetchIndonesian();
    if (!mounted) return;
    setState(() => _directory =
        list.isEmpty ? List.of(RadioRepository.fallback) : list);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _player?.dispose();
    super.dispose();
  }

  void _onSearch(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() => _results = null);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      final r = await RadioRepository.search(q);
      if (mounted && _searchCtrl.text.trim() == q.trim()) {
        setState(() => _results = r);
      }
    });
  }

  Future<void> _play(RadioStation s) async {
    final old = _player;
    setState(() {
      _nowPlaying = s;
      _connecting = true;
      _player = null;
    });
    await old?.dispose();
    try {
      final v = VideoPlayerController.networkUrl(Uri.parse(s.streamUrl));
      await v.initialize().timeout(const Duration(seconds: 15));
      await v.play();
      if (!mounted) {
        await v.dispose();
        return;
      }
      setState(() {
        _player = v;
        _connecting = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _connecting = false;
        _nowPlaying = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Stasiun tidak merespons. Coba yang lain.')));
    }
  }

  Future<void> _togglePause() async {
    final v = _player;
    if (v == null) return;
    if (v.value.isPlaying) {
      await v.pause();
    } else {
      await v.play();
    }
    setState(() {});
  }

  Future<void> _stop() async {
    final v = _player;
    setState(() {
      _player = null;
      _nowPlaying = null;
      _connecting = false;
    });
    await v?.dispose();
  }

  Widget _tile(RadioStation s) {
    final active = _nowPlaying?.streamUrl == s.streamUrl;
    return ListTile(
      dense: true,
      onTap: () => _play(s),
      leading: ClipOval(
        child: SizedBox(
          width: 40,
          height: 40,
          child: s.logoUrl.isEmpty
              ? Container(
                  color: Colors.white10,
                  child: const Icon(Icons.radio,
                      color: Colors.white38, size: 20))
              : Image.network(
                  s.logoUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                      color: Colors.white10,
                      child: const Icon(Icons.radio,
                          color: Colors.white38, size: 20)),
                ),
        ),
      ),
      title: Text(s.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              color: active ? const Color(0xFFF6C445) : Colors.white,
              fontSize: 14,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
      subtitle: s.city.isEmpty
          ? null
          : Text(s.city,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white38, fontSize: 11)),
      trailing: Icon(active ? Icons.graphic_eq : Icons.play_arrow,
          color: active ? const Color(0xFFF6C445) : Colors.white38,
          size: 20),
    );
  }

  Widget _header(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1)),
      );

  /// Bar "sedang diputar" di dasar layar (di dalam body, aman dari
  /// bilah navigasi sistem).
  Widget _nowPlayingBar() {
    final s = _nowPlaying;
    if (s == null) return const SizedBox.shrink();
    final playing = _player?.value.isPlaying ?? false;
    return Container(
      color: const Color(0xFF16233F),
      padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
      child: Row(
        children: [
          const Icon(Icons.radio, color: Color(0xFFF6C445), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700)),
                Text(_connecting ? 'Menyambung...' : 'Siaran langsung',
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 11)),
              ],
            ),
          ),
          if (_connecting)
            const Padding(
              padding: EdgeInsets.all(10),
              child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white)),
            )
          else
            IconButton(
              onPressed: _togglePause,
              icon: Icon(playing ? Icons.pause : Icons.play_arrow,
                  color: Colors.white),
            ),
          IconButton(
            onPressed: _stop,
            icon: const Icon(Icons.close, color: Colors.white54),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1220),
        foregroundColor: Colors.white,
        title: const Text('Radio',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearch,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Cari stasiun radio...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon:
                      const Icon(Icons.search, color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  isDense: true,
                ),
              ),
            ),
            Expanded(
              child: _results != null
                  ? (_results!.isEmpty
                      ? const Center(
                          child: Text('Tidak ketemu.',
                              style: TextStyle(color: Colors.white38)))
                      : ListView(
                          children: [for (final s in _results!) _tile(s)]))
                  : ListView(
                      children: [
                        _header('RADIO INDONESIA'),
                        if (_directory == null)
                          const Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(
                                child: CircularProgressIndicator(
                                    color: Colors.white)),
                          )
                        else
                          for (final s in _directory!) _tile(s),
                        const SizedBox(height: 16),
                      ],
                    ),
            ),
            _nowPlayingBar(),
          ],
        ),
      ),
    );
  }
}
