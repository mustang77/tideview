import "dart:io";

import "package:flutter/material.dart";
import "package:flutter/scheduler.dart";
import "package:image_picker/image_picker.dart";
import "package:video_player/video_player.dart";

import "../src/demo_project.dart";
import "../src/edit_controller.dart";
import "../src/filters.dart";
import "../src/model.dart";
import "../src/project_codec.dart";
import "preview_stage.dart";
import "timeline_view.dart";

/// The CapCut-style editor screen: a composited preview on top, transport +
/// tool bar in the middle, and the multi-track timeline at the bottom. The
/// timeline is the master clock; a [Ticker] advances the playhead and the video
/// preview is kept in sync with it.
class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen>
    with SingleTickerProviderStateMixin {
  late final EditController _c;
  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;

  VideoPlayerController? _video;
  String? _loadedPath;
  String? _activeClipId;
  bool _videoReady = false;

  @override
  void initState() {
    super.initState();
    _c = EditController(DemoProject.build());
    _c.addListener(_onControllerChanged);
    _ticker = createTicker(_onTick);
    _syncVideoSource();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _c.removeListener(_onControllerChanged);
    _c.dispose();
    _video?.dispose();
    super.dispose();
  }

  int get _playhead => _c.playheadMs;

  void _onControllerChanged() {
    if (mounted) setState(() {});
    _syncVideoSource();
  }

  void _onTick(Duration elapsed) {
    if (!_c.isPlaying) return;
    final int dtMs = (elapsed - _lastElapsed).inMilliseconds;
    _lastElapsed = elapsed;
    if (dtMs <= 0) return;
    final int next = _playhead + dtMs;
    if (next >= _c.durationMs) {
      _c.seek(_c.durationMs);
      _pause();
    } else {
      _c.seek(next);
    }
  }

  // ---- playback ------------------------------------------------------------

  void _togglePlay() => _c.isPlaying ? _pause() : _play();

  void _play() {
    if (_c.durationMs == 0) return;
    if (_playhead >= _c.durationMs) _c.seek(0);
    _lastElapsed = Duration.zero;
    _ticker.start();
    _c.setPlaying(true);
    _resumeVideo();
  }

  void _pause() {
    _ticker.stop();
    _c.setPlaying(false);
    _video?.pause();
  }

  Future<void> _resumeVideo() async {
    final VideoPlayerController? v = _video;
    final Clip? clip = _c.videoClipAt(_playhead);
    if (v == null || !_videoReady || clip == null) return;
    await v.setPlaybackSpeed(clip.speed);
    await v.play();
  }

  /// Load / swap / seek the underlying video to match the active clip. Avoids
  /// per-frame seeking during playback: it only seeks when scrubbing (paused)
  /// or when the playhead crosses into a different clip.
  Future<void> _syncVideoSource() async {
    final Clip? clip = _c.videoClipAt(_playhead);
    final String? path = clip?.sourcePath;

    if (clip == null || path == null) {
      _activeClipId = null;
      if (_video != null && _video!.value.isPlaying) {
        await _video!.pause();
      }
      return;
    }

    // Image bases are painted directly by PreviewStage — no video source.
    if (clip.type != ClipType.video) {
      _activeClipId = clip.id;
      if (_video != null && _video!.value.isPlaying) await _video!.pause();
      return;
    }

    if (path != _loadedPath) {
      await _loadVideo(path, clip);
      _activeClipId = clip.id;
      return;
    }
    if (!_videoReady || _video == null) return;

    final bool crossedClip = clip.id != _activeClipId;
    _activeClipId = clip.id;
    if (crossedClip || !_c.isPlaying) {
      await _video!.seekTo(Duration(milliseconds: clip.sourceTimeAt(_playhead)));
      if (_c.isPlaying) {
        await _video!.setPlaybackSpeed(clip.speed);
        await _video!.play();
      }
    }
  }

  Future<void> _loadVideo(String path, Clip clip) async {
    _loadedPath = path;
    _videoReady = false;
    if (mounted) setState(() {});
    final VideoPlayerController? old = _video;
    final VideoPlayerController next = _controllerFor(path);
    try {
      await next.initialize();
      await next.setLooping(false);
      if (!mounted || _loadedPath != path) {
        await next.dispose();
        return;
      }
      _video = next;
      _videoReady = true;
      await next.seekTo(Duration(milliseconds: clip.sourceTimeAt(_playhead)));
      if (_c.isPlaying) {
        await next.setPlaybackSpeed(clip.speed);
        await next.play();
      }
      if (mounted) setState(() {});
    } catch (_) {
      _videoReady = false;
      if (mounted) setState(() {});
    } finally {
      if (old != null && old != _video) {
        await old.dispose();
      }
    }
  }

  VideoPlayerController _controllerFor(String path) {
    final Uri uri = Uri.parse(path);
    if (uri.scheme == "http" || uri.scheme == "https") {
      return VideoPlayerController.networkUrl(uri);
    }
    return VideoPlayerController.file(File(path));
  }

  // ---- media import --------------------------------------------------------

  final ImagePicker _picker = ImagePicker();

  Future<void> _importVideo() async {
    try {
      final XFile? file = await _picker.pickVideo(source: ImageSource.gallery);
      if (file == null) return;
      final int durationMs = await _probeDuration(file.path);
      _c.importClip(
        type: ClipType.video,
        path: file.path,
        durationMs: durationMs,
      );
      _toast("Imported video");
    } catch (e) {
      _toast("Import failed: $e");
    }
  }

  Future<void> _importPhoto() async {
    try {
      final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
      if (file == null) return;
      _c.importClip(
        type: ClipType.image,
        path: file.path,
        durationMs: 3000,
      );
      _toast("Imported photo");
    } catch (e) {
      _toast("Import failed: $e");
    }
  }

  /// Read a video file's duration by briefly initializing a throwaway
  /// controller. Falls back to 5s if the probe fails.
  Future<int> _probeDuration(String path) async {
    final VideoPlayerController probe = _controllerFor(path);
    try {
      await probe.initialize();
      final int ms = probe.value.duration.inMilliseconds;
      return ms > 0 ? ms : 5000;
    } catch (_) {
      return 5000;
    } finally {
      await probe.dispose();
    }
  }

  void _showImportMenu() {
    _sheet(
      "Import media",
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: <Widget>[
          _importOption(Icons.video_library, "Video", () {
            Navigator.of(context).pop();
            _importVideo();
          }),
          _importOption(Icons.photo_library, "Photo", () {
            Navigator.of(context).pop();
            _importPhoto();
          }),
        ],
      ),
    );
  }

  Widget _importOption(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, color: Colors.white, size: 34),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  // ---- edit target ---------------------------------------------------------

  /// The clip tools act on: the explicit selection, else the video clip under
  /// the playhead.
  String? get _targetId => _c.selectedClipId ?? _c.videoClipAt(_playhead)?.id;
  Clip? get _target {
    final String? id = _targetId;
    return id == null ? null : _c.project.locate(id)?.clip;
  }

  // ---- build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _appBar(),
            Expanded(
              child: PreviewStage(
                controller: _c,
                videoController: _video,
                videoReady: _videoReady,
              ),
            ),
            _transportBar(),
            const Divider(height: 1, color: Colors.white12),
            TimelineView(controller: _c),
            _toolBar(),
          ],
        ),
      ),
    );
  }

  Widget _appBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Row(
        children: <Widget>[
          const Text("Editor",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(10)),
            child: Text(_c.project.name,
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ),
          const Spacer(),
          IconButton(
            tooltip: "Import media",
            onPressed: _showImportMenu,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            color: Colors.white,
          ),
          IconButton(
            tooltip: "Undo",
            onPressed: _c.canUndo ? _c.undo : null,
            icon: const Icon(Icons.undo),
            color: Colors.white,
            disabledColor: Colors.white24,
          ),
          IconButton(
            tooltip: "Redo",
            onPressed: _c.canRedo ? _c.redo : null,
            icon: const Icon(Icons.redo),
            color: Colors.white,
            disabledColor: Colors.white24,
          ),
          FilledButton.icon(
            onPressed: _showExport,
            icon: const Icon(Icons.ios_share, size: 18),
            label: const Text("Export"),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF3B6B),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _transportBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: _togglePlay,
            icon: Icon(_c.isPlaying ? Icons.pause_circle : Icons.play_circle),
            iconSize: 40,
            color: Colors.white,
          ),
          const SizedBox(width: 8),
          Text(
            "${_fmt(_playhead)} / ${_fmt(_c.durationMs)}",
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontFeatures: <FontFeature>[FontFeature.tabularFigures()]),
          ),
          const Spacer(),
          IconButton(
            tooltip: "Split at playhead",
            onPressed: _splitAtPlayhead,
            icon: const Icon(Icons.content_cut),
            color: Colors.white,
          ),
          IconButton(
            tooltip: "Duplicate",
            onPressed: _targetId == null
                ? null
                : () => _c.duplicateClip(_targetId!),
            icon: const Icon(Icons.copy_all),
            color: Colors.white,
            disabledColor: Colors.white24,
          ),
          IconButton(
            tooltip: "Delete",
            onPressed:
                _targetId == null ? null : () => _c.removeClip(_targetId!),
            icon: const Icon(Icons.delete_outline),
            color: Colors.white,
            disabledColor: Colors.white24,
          ),
        ],
      ),
    );
  }

  Widget _toolBar() {
    final List<(IconData, String, VoidCallback)> tools = <(IconData, String, VoidCallback)>[
      (Icons.auto_awesome, "Filter", _showFilters),
      (Icons.title, "Text", _showAddText),
      (Icons.emoji_emotions, "Sticker", _showStickers),
      (Icons.speed, "Speed", _showSpeed),
      (Icons.volume_up, "Volume", _showVolume),
      (Icons.transition_enterexit, "Transition", _showTransitions),
    ];
    return Container(
      color: const Color(0xFF181818),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: <Widget>[
            for (final (IconData icon, String label, VoidCallback tap) in tools)
              _toolButton(icon, label, tap),
          ],
        ),
      ),
    );
  }

  Widget _toolButton(IconData icon, String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  // ---- tool actions --------------------------------------------------------

  void _splitAtPlayhead() {
    final String? id = _targetId;
    if (id == null) return;
    _c.splitAt(id, _playhead);
  }

  void _requireTarget(String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Select a clip to $action")),
    );
  }

  void _showFilters() {
    final Clip? target = _target;
    if (target == null) return _requireTarget("apply a filter");
    _sheet(
      "Filter",
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          _filterChip("None", target.filterId == null,
              () => _c.setFilter(target.id, null)),
          for (final e in EditorFilters.presets)
            _filterChip(e.name, target.filterId == e.id,
                () => _c.setFilter(target.id, e.id)),
        ],
      ),
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        onTap();
        Navigator.of(context).pop();
      },
    );
  }

  void _showAddText() {
    final TextEditingController tc = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add text"),
        content: TextField(
          controller: tc,
          autofocus: true,
          decoration: const InputDecoration(hintText: "Your caption"),
        ),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("Cancel")),
          FilledButton(
            onPressed: () {
              final String t = tc.text.trim();
              if (t.isNotEmpty) _c.addTextAtPlayhead(t);
              Navigator.of(ctx).pop();
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  void _showStickers() {
    const List<String> emojis = <String>[
      "😀", "😎", "🔥", "❤️", "⭐", "🎉", "👍", "🌊", "🚢", "✨"
    ];
    _sheet(
      "Sticker",
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: <Widget>[
          for (final String e in emojis)
            GestureDetector(
              onTap: () {
                _c.addStickerAtPlayhead(e.runes.first);
                Navigator.of(context).pop();
              },
              child: Text(e, style: const TextStyle(fontSize: 34)),
            ),
        ],
      ),
    );
  }

  void _showSpeed() {
    final Clip? target = _target;
    if (target == null) return _requireTarget("change speed");
    _sliderSheet(
      "Speed",
      value: target.speed,
      min: 0.25,
      max: 4.0,
      format: (v) => "${v.toStringAsFixed(2)}x",
      onChanged: (v) => _c.setSpeed(target.id, v),
    );
  }

  void _showVolume() {
    final Clip? target = _target;
    if (target == null) return _requireTarget("change volume");
    _sliderSheet(
      "Volume",
      value: target.volume,
      min: 0.0,
      max: 2.0,
      format: (v) => "${(v * 100).round()}%",
      onChanged: (v) => _c.setVolume(target.id, v),
    );
  }

  void _showTransitions() {
    final Clip? target = _target;
    if (target == null) return _requireTarget("set a transition");
    _sheet(
      "Transition out",
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          for (final TransitionType t in TransitionType.values)
            _filterChip(t.name, target.transitionOut == t,
                () => _c.setTransitionOut(target.id, t)),
        ],
      ),
    );
  }

  void _showExport() {
    final RenderPlan plan = RenderPlan.fromProject(_c.project);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Export recipe"),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Text(
              plan.toEdl(),
              style: const TextStyle(fontFamily: "monospace", fontSize: 11),
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Close"),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      "Render plan ready — plug in an encoder to write the .mp4"),
                ),
              );
            },
            child: const Text("Render"),
          ),
        ],
      ),
    );
  }

  // ---- sheet helpers -------------------------------------------------------

  void _sheet(String title, Widget body) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1C1C1C),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            body,
          ],
        ),
      ),
    );
  }

  void _sliderSheet(
    String title, {
    required double value,
    required double min,
    required double max,
    required String Function(double) format,
    required ValueChanged<double> onChanged,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1C1C1C),
      builder: (ctx) {
        double v = value;
        return StatefulBuilder(
          builder: (ctx, setSheet) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    Text(format(v),
                        style: const TextStyle(color: Colors.white70)),
                  ],
                ),
                Slider(
                  value: v,
                  min: min,
                  max: max,
                  onChanged: (nv) {
                    setSheet(() => v = nv);
                    onChanged(nv);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _fmt(int ms) {
    final int totalSec = ms ~/ 1000;
    final int m = totalSec ~/ 60;
    final int s = totalSec % 60;
    final int cs = (ms % 1000) ~/ 10;
    return "$m:${s.toString().padLeft(2, '0')}.${cs.toString().padLeft(2, '0')}";
  }
}
