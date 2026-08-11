import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../format.dart';
import '../../store.dart';

/// Berita Indonesia terkini (agregasi RSS media nasional dari server)
/// dengan gambar unggulan; artikel terbuka di tab browser dalam-aplikasi.
class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsItem {
  _NewsItem({
    required this.title,
    required this.link,
    required this.source,
    required this.image,
    required this.at,
  });

  final String title;
  final String link;
  final String source;
  final String image;
  final DateTime at;

  factory _NewsItem.fromMap(Map<String, dynamic> m) => _NewsItem(
        title: m['title'] as String? ?? '',
        link: m['link'] as String? ?? '',
        source: m['source'] as String? ?? '',
        image: m['image'] as String? ?? '',
        at: DateTime.tryParse(m['at'] as String? ?? '')?.toLocal() ??
            DateTime.now(),
      );
}

class _NewsScreenState extends State<NewsScreen> {
  List<_NewsItem>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final a = store.api;
    if (a == null) {
      setState(() => _error = 'Berita membutuhkan koneksi ke server.');
      return;
    }
    try {
      final m = await a.getNews();
      if (!mounted) return;
      setState(() {
        _items = ((m['items'] as List?) ?? [])
            .map((e) =>
                _NewsItem.fromMap((e as Map).cast<String, dynamic>()))
            .toList();
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Tidak bisa memuat berita. Coba lagi.');
    }
  }

  /// Gambar lewat proxy server (CDN berita tidak mengirim CORS).
  String _imgUrl(String img) =>
      '${store.apiUrl}/api/newsimg?u=${Uri.encodeComponent(img)}';

  Future<void> _open(String link) async {
    final uri = Uri.tryParse(link);
    if (uri == null) return;
    var ok = false;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    } catch (_) {}
    if (!ok) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = _items;
    return Scaffold(
      appBar: AppBar(title: const Text('Berita Hari Ini')),
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
                    child: ListView.builder(
                      padding: const EdgeInsets.all(14),
                      itemCount: items.length,
                      itemBuilder: (context, i) {
                        final n = items[i];
                        return Card(
                          clipBehavior: Clip.antiAlias,
                          margin: const EdgeInsets.only(bottom: 14),
                          child: InkWell(
                            onTap: () => _open(n.link),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.stretch,
                              children: [
                                if (n.image.isNotEmpty)
                                  AspectRatio(
                                    aspectRatio: 16 / 9,
                                    child: Image.network(
                                      _imgUrl(n.image),
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) =>
                                          Container(
                                        color: const Color(0xFFE2E8F0),
                                        alignment: Alignment.center,
                                        child: const Icon(
                                            Icons.newspaper,
                                            size: 40,
                                            color: Color(0xFF94A3B8)),
                                      ),
                                    ),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                      14, 10, 14, 12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets
                                                .symmetric(
                                                horizontal: 8,
                                                vertical: 3),
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                  0xFFE0F2FE),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      999),
                                            ),
                                            child: Text(
                                              n.source,
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight:
                                                      FontWeight.w700,
                                                  color:
                                                      Color(0xFF0369A1)),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(timeAgo(n.at),
                                              style: theme
                                                  .textTheme.bodySmall),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        n.title,
                                        style: const TextStyle(
                                            fontSize: 15,
                                            height: 1.35,
                                            fontWeight: FontWeight.w700),
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
      ),
    );
  }
}
