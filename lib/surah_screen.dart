import "dart:async";

import "package:audioplayers/audioplayers.dart";
import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";
import "package:scrollable_positioned_list/scrollable_positioned_list.dart";
import "package:share_plus/share_plus.dart";

import "app_state.dart";
import "models.dart";
import "quran_data.dart";
import "quran_service.dart";

/// Reads one surah: Arabic + translation per ayah, verse audio with
/// continuous playback, bookmarking and sharing.
class SurahScreen extends StatefulWidget {
  final QuranService service;
  final int surahNumber;
  final int? scrollToAyah;

  const SurahScreen({
    super.key,
    required this.service,
    required this.surahNumber,
    this.scrollToAyah,
  });

  @override
  State<SurahScreen> createState() => _SurahScreenState();
}

class _SurahScreenState extends State<SurahScreen> {
  final _itemScrollController = ItemScrollController();
  final _player = AudioPlayer();
  StreamSubscription<void>? _completeSub;

  Future<SurahContent>? _future;
  String? _loadedTranslationId;
  SurahContent? _content;

  /// numberInSurah of the ayah currently playing, or null when idle.
  int? _playingAyah;
  bool _paused = false;
  bool _continuous = false;

  SurahInfo get _info => surahByNumber(widget.surahNumber);

  @override
  void initState() {
    super.initState();
    _completeSub = _player.onPlayerComplete.listen((_) => _onTrackDone());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AppScope.of(context)
          .setLastRead(VerseRef(widget.surahNumber, widget.scrollToAyah ?? 1));
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final translationId = AppScope.of(context).translationId;
    if (_loadedTranslationId != translationId) {
      _loadedTranslationId = translationId;
      _future = widget.service
          .loadSurah(widget.surahNumber, translationId)
          .then((c) {
        _content = c;
        return c;
      });
    }
  }

  @override
  void dispose() {
    _completeSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  // ---- Audio -------------------------------------------------------------

  Future<void> _playAyah(int numberInSurah, {bool continuous = false}) async {
    final content = _content;
    if (content == null) return;
    final ayah = content.ayahs[numberInSurah - 1];
    final reciter = AppScope.of(context).reciterId;
    setState(() {
      _playingAyah = numberInSurah;
      _paused = false;
      _continuous = continuous || _continuous;
    });
    AppScope.of(context)
        .setLastRead(VerseRef(widget.surahNumber, numberInSurah));
    try {
      await _player.stop();
      await _player.play(
          UrlSource(QuranService.audioUrl(reciter, ayah.globalNumber)));
    } catch (_) {
      if (mounted) {
        setState(() {
          _playingAyah = null;
          _continuous = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Could not play audio. Check your connection.")));
      }
    }
  }

  void _onTrackDone() {
    if (!mounted) return;
    final current = _playingAyah;
    final content = _content;
    if (current == null || content == null || !_continuous) {
      setState(() => _playingAyah = null);
      return;
    }
    if (current < content.ayahs.length) {
      final next = current + 1;
      _playAyah(next, continuous: true);
      _scrollToAyah(next);
    } else {
      setState(() {
        _playingAyah = null;
        _continuous = false;
      });
    }
  }

  Future<void> _togglePause() async {
    if (_paused) {
      await _player.resume();
    } else {
      await _player.pause();
    }
    setState(() => _paused = !_paused);
  }

  Future<void> _stopAudio() async {
    await _player.stop();
    setState(() {
      _playingAyah = null;
      _paused = false;
      _continuous = false;
    });
  }

  void _scrollToAyah(int numberInSurah) {
    if (!_itemScrollController.isAttached) return;
    _itemScrollController.scrollTo(
      index: numberInSurah, // header occupies index 0
      duration: const Duration(milliseconds: 350),
      alignment: 0.15,
    );
  }

  // ---- Actions -----------------------------------------------------------

  void _shareAyah(Ayah ayah) {
    final ref = "${_info.nameEnglish} (${widget.surahNumber}:"
        "${ayah.numberInSurah})";
    SharePlus.instance.share(
        ShareParams(text: "${ayah.arabic}\n\n${ayah.translation}\n\n— $ref"));
  }

  // ---- UI ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_info.nameEnglish,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(
              "${_info.revelation} • ${_info.ayahCount} ayahs",
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: "Play whole surah",
            icon: const Icon(Icons.play_circle_outline),
            onPressed: () {
              _continuous = true;
              _playAyah(1, continuous: true);
              _scrollToAyah(1);
            },
          ),
        ],
      ),
      body: FutureBuilder<SurahContent>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ErrorRetry(
              message: "Couldn't load the surah.\nCheck your connection.",
              onRetry: () => setState(() {
                _loadedTranslationId = null;
                didChangeDependencies();
              }),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final content = snapshot.data!;
          return ScrollablePositionedList.builder(
            itemScrollController: _itemScrollController,
            initialScrollIndex:
                (widget.scrollToAyah ?? 0).clamp(0, content.ayahs.length),
            itemCount: content.ayahs.length + 2, // header + ayahs + footer
            itemBuilder: (context, index) {
              if (index == 0) return _SurahHeader(info: _info);
              if (index == content.ayahs.length + 1) {
                return _SurahFooter(
                  surahNumber: widget.surahNumber,
                  onOpen: (n) => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) =>
                          SurahScreen(service: widget.service, surahNumber: n),
                    ),
                  ),
                );
              }
              final ayah = content.ayahs[index - 1];
              return _AyahCard(
                surahNumber: widget.surahNumber,
                ayah: ayah,
                state: state,
                isPlaying: _playingAyah == ayah.numberInSurah,
                onPlay: () {
                  if (_playingAyah == ayah.numberInSurah) {
                    _togglePause();
                  } else {
                    _playAyah(ayah.numberInSurah);
                  }
                },
                onShare: () => _shareAyah(ayah),
              );
            },
          );
        },
      ),
      bottomNavigationBar: _playingAyah == null
          ? null
          : _AudioBar(
              title: "${_info.nameEnglish} — Ayah $_playingAyah",
              subtitle: state.reciterName,
              paused: _paused,
              onTogglePause: _togglePause,
              onStop: _stopAudio,
            ),
    );
  }
}

class _SurahHeader extends StatelessWidget {
  final SurahInfo info;
  const _SurahHeader({required this.info});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final showBismillah = info.number != 1 && info.number != 9;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.primary, scheme.primary.withValues(alpha: 0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            info.nameArabic,
            style: GoogleFonts.amiri(
                fontSize: 34,
                color: scheme.onPrimary,
                fontWeight: FontWeight.w700),
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 4),
          Text(
            "${info.nameEnglish} • ${info.meaning}",
            style: TextStyle(color: scheme.onPrimary.withValues(alpha: 0.9)),
            textAlign: TextAlign.center,
          ),
          if (showBismillah) ...[
            Divider(
                height: 28, color: scheme.onPrimary.withValues(alpha: 0.3)),
            Text(
              bismillah,
              style: GoogleFonts.amiri(fontSize: 24, color: scheme.onPrimary),
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class _SurahFooter extends StatelessWidget {
  final int surahNumber;
  final ValueChanged<int> onOpen;
  const _SurahFooter({required this.surahNumber, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Row(
        children: [
          if (surahNumber > 1)
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.arrow_back),
                label: Text(surahByNumber(surahNumber - 1).nameEnglish,
                    overflow: TextOverflow.ellipsis),
                onPressed: () => onOpen(surahNumber - 1),
              ),
            ),
          if (surahNumber > 1 && surahNumber < 114) const SizedBox(width: 12),
          if (surahNumber < 114)
            Expanded(
              child: FilledButton.icon(
                icon: const Icon(Icons.arrow_forward),
                label: Text(surahByNumber(surahNumber + 1).nameEnglish,
                    overflow: TextOverflow.ellipsis),
                onPressed: () => onOpen(surahNumber + 1),
              ),
            ),
        ],
      ),
    );
  }
}

class _AyahCard extends StatelessWidget {
  final int surahNumber;
  final Ayah ayah;
  final AppState state;
  final bool isPlaying;
  final VoidCallback onPlay;
  final VoidCallback onShare;

  const _AyahCard({
    required this.surahNumber,
    required this.ayah,
    required this.state,
    required this.isPlaying,
    required this.onPlay,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ref = VerseRef(surahNumber, ayah.numberInSurah);
    final bookmarked = state.isBookmarked(ref);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: isPlaying
            ? scheme.primaryContainer.withValues(alpha: 0.55)
            : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: isPlaying
            ? Border.all(color: scheme.primary, width: 1.2)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: scheme.primary.withValues(alpha: 0.12),
                child: Text("${ayah.numberInSurah}",
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: scheme.primary)),
              ),
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: isPlaying ? "Pause" : "Play",
                icon: Icon(
                    isPlaying
                        ? Icons.pause_circle_outline
                        : Icons.play_circle_outline,
                    color: scheme.primary),
                onPressed: onPlay,
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: "Bookmark",
                icon: Icon(
                  bookmarked ? Icons.bookmark : Icons.bookmark_outline,
                  color: bookmarked ? scheme.primary : null,
                ),
                onPressed: () => state.toggleBookmark(ref),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: "Share",
                icon: const Icon(Icons.share_outlined),
                onPressed: onShare,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            ayah.arabic,
            style: GoogleFonts.amiri(
                fontSize: state.arabicFontSize, height: 1.9),
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
          ),
          if (state.showTransliteration) ...[
            const SizedBox(height: 8),
            Text(
              ayah.transliteration,
              style: TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 13.5,
                  color: scheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 10),
          Text(ayah.translation,
              style: const TextStyle(fontSize: 15, height: 1.5)),
        ],
      ),
    );
  }
}

class _AudioBar extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool paused;
  final VoidCallback onTogglePause;
  final VoidCallback onStop;

  const _AudioBar({
    required this.title,
    required this.subtitle,
    required this.paused,
    required this.onTogglePause,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: scheme.onPrimaryContainer)),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          color: scheme.onPrimaryContainer
                              .withValues(alpha: 0.8))),
                ],
              ),
            ),
            IconButton(
              icon: Icon(paused ? Icons.play_arrow : Icons.pause,
                  color: scheme.onPrimaryContainer),
              onPressed: onTogglePause,
            ),
            IconButton(
              icon: Icon(Icons.stop, color: scheme.onPrimaryContainer),
              onPressed: onStop,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorRetry({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off, size: 40),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text("Retry")),
        ],
      ),
    );
  }
}
