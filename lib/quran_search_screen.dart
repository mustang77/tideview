import "package:flutter/material.dart";

import "app_state.dart";
import "models.dart";
import "quran_data.dart";
import "quran_service.dart";
import "surah_screen.dart";

/// Full-text search over the selected translation.
class QuranSearchScreen extends StatefulWidget {
  final QuranService service;
  const QuranSearchScreen({super.key, required this.service});

  @override
  State<QuranSearchScreen> createState() => _QuranSearchScreenState();
}

class _QuranSearchScreenState extends State<QuranSearchScreen> {
  final _controller = TextEditingController();
  List<SearchMatch>? _results;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.length < 3) {
      setState(() {
        _error = "Type at least 3 characters.";
        _results = null;
      });
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    // Search runs against the selected translation when it is supported by
    // the API's search index, otherwise falls back to English.
    final translationId = AppScope.of(context).translationId;
    final searchEdition =
        translationId.startsWith("en.") || translationId.startsWith("id.")
            ? translationId
            : "en.sahih";
    try {
      final results = await widget.service.search(query, searchEdition);
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = "Search failed. Check your connection and try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    return Scaffold(
      appBar: AppBar(
          title: const Text("Search the Quran",
              style: TextStyle(fontWeight: FontWeight.w700))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: "e.g. mercy, patience, paradise…",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: _search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                filled: true,
              ),
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_error!,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          if (results != null && !_loading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  results.isEmpty
                      ? "No matches found."
                      : "${results.length} matches",
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
            ),
          Expanded(
            child: results == null
                ? _EmptyHint()
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: results.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, indent: 16, endIndent: 16),
                    itemBuilder: (context, i) {
                      final m = results[i];
                      final surah = surahByNumber(m.surah);
                      return ListTile(
                        title: Text(
                            "${surah.nameEnglish} ${m.surah}:${m.ayahInSurah}",
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(m.text,
                            maxLines: 3, overflow: TextOverflow.ellipsis),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SurahScreen(
                              service: widget.service,
                              surahNumber: m.surah,
                              scrollToAyah: m.ayahInSurah,
                            ),
                          ),
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

class _EmptyHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.manage_search, size: 48, color: scheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text("Search for a word or phrase\nin the translation.",
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
