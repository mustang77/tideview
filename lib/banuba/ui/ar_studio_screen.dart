import "dart:ui" as ui;

import "package:camera/camera.dart";
import "package:flutter/material.dart";

import "../banuba.dart";

/// Demo studio for the Banuba-clone Face AR SDK. Runs a live camera preview
/// through the [EffectPlayer]: a folded color-grade + beauty color filter, a
/// selective skin-smoothing blur, and landmark-anchored AR masks / makeup drawn
/// by [FaceOverlayPainter]. When no camera is available it falls back to a
/// synthetic preview so the whole pipeline still demos and the overlays still
/// track.
class ARStudioScreen extends StatefulWidget {
  const ARStudioScreen({super.key});

  @override
  State<ARStudioScreen> createState() => _ARStudioScreenState();
}

class _ARStudioScreenState extends State<ARStudioScreen>
    with SingleTickerProviderStateMixin {
  final EffectPlayer _player = EffectPlayer();
  final FaceTracker _tracker = const MockFaceTracker();

  CameraController? _camera;
  bool _cameraReady = false;
  bool _mirror = true;
  String? _cameraError;

  late final AnimationController _clock;
  bool _showBeautyPanel = false;
  bool _showLandmarks = false;

  @override
  void initState() {
    super.initState();
    _clock = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();
    _player.addListener(_onPlayerChanged);
    _initCamera();
  }

  void _onPlayerChanged() => setState(() {});

  Future<void> _initCamera() async {
    try {
      final List<CameraDescription> cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _cameraError = "No camera on this device");
        return;
      }
      final CameraDescription front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final CameraController controller = CameraController(
        front,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _camera = controller;
        _cameraReady = true;
        _mirror = front.lensDirection == CameraLensDirection.front;
      });
    } catch (e) {
      setState(() => _cameraError = "Camera unavailable — showing demo preview");
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    _player.removeListener(_onPlayerChanged);
    _player.dispose();
    _tracker.dispose();
    _camera?.dispose();
    super.dispose();
  }

  double get _t => _clock.value * 60.0; // seconds

  Future<void> _capture() async {
    final CameraController? cam = _camera;
    String message;
    if (cam != null && _cameraReady) {
      try {
        final XFile shot = await cam.takePicture();
        message = "Captured ${shot.name} — effect: ${_player.effect.name}";
      } catch (_) {
        message = "Could not capture photo";
      }
    } else {
      message = "Demo capture — effect: ${_player.effect.name}";
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _topBar(),
            Expanded(child: _stage()),
            if (_showBeautyPanel) _beautyPanel(),
            _EffectCarousel(
              effects: EffectsCatalog.all,
              active: _player.effect,
              onSelect: _player.loadEffect,
            ),
            _bottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: <Widget>[
          const Text("AR Studio",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text("Face AR SDK",
                style: TextStyle(color: Colors.white70, fontSize: 11)),
          ),
          const Spacer(),
          IconButton(
            tooltip: "Toggle landmarks",
            onPressed: () => setState(() => _showLandmarks = !_showLandmarks),
            icon: Icon(
              _showLandmarks ? Icons.grid_on : Icons.grid_off,
              color: Colors.white70,
            ),
          ),
          IconButton(
            tooltip: "Beauty",
            onPressed: () =>
                setState(() => _showBeautyPanel = !_showBeautyPanel),
            icon: Icon(
              Icons.auto_awesome,
              color: _showBeautyPanel ? Colors.amber : Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: GestureDetector(
          // Press-and-hold to compare against the untouched original.
          onTapDown: (_) => _player.setEnabled(false),
          onTapUp: (_) => _player.setEnabled(true),
          onTapCancel: () => _player.setEnabled(true),
          child: AnimatedBuilder(
            animation: _clock,
            builder: (context, _) {
              final List<Face> faces = _tracker.facesAt(_t);
              return Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  _previewLayer(),
                  CustomPaint(
                    painter: FaceOverlayPainter(
                      faces: faces,
                      mask: _player.mask,
                      makeup: _player.makeup,
                      mirror: _mirror,
                      showLandmarks: _showLandmarks,
                    ),
                  ),
                  if (!_player.enabled)
                    const Positioned(
                      top: 12,
                      left: 12,
                      child: _Pill(text: "ORIGINAL"),
                    ),
                  if (_cameraError != null)
                    Positioned(
                      bottom: 12,
                      left: 12,
                      right: 12,
                      child: _Pill(text: _cameraError!),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// The base image the effects run over: the live camera, color-filtered and
  /// blurred, or a synthetic fallback.
  Widget _previewLayer() {
    Widget base;
    if (_cameraReady && _camera != null) {
      base = FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _camera!.value.previewSize?.height ?? 720,
          height: _camera!.value.previewSize?.width ?? 1280,
          child: CameraPreview(_camera!),
        ),
      );
    } else {
      base = const _SyntheticFace();
    }

    final double sigma = _player.blurSigma;
    if (sigma > 0.01) {
      base = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: base,
      );
    }

    final ColorFilter? filter = _player.colorFilter;
    if (filter != null) {
      base = ColorFiltered(colorFilter: filter, child: base);
    }
    return base;
  }

  Widget _beautyPanel() {
    final BeautyConfig o = _player.beautyOverride;
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _slider("Smooth", o.smoothSkin, 0, 1,
              (v) => _player.setBeautyOverride(o.copyWith(smoothSkin: v))),
          _slider("Brighten", o.brighten, -0.5, 0.5,
              (v) => _player.setBeautyOverride(o.copyWith(brighten: v))),
          _slider("Warmth", o.warmth, -1, 1,
              (v) => _player.setBeautyOverride(o.copyWith(warmth: v))),
          _slider("Vivid", o.saturation, 0, 2,
              (v) => _player.setBeautyOverride(o.copyWith(saturation: v))),
        ],
      ),
    );
  }

  Widget _slider(
      String label, double value, double min, double max, ValueChanged<double> onChanged) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 68,
          child: Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            activeColor: Colors.amber,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _bottomBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          IconButton(
            tooltip: "Reset",
            onPressed: _player.reset,
            icon: const Icon(Icons.restart_alt, color: Colors.white70),
          ),
          const SizedBox(width: 28),
          GestureDetector(
            onTap: _capture,
            child: Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
              ),
              child: Container(
                margin: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 28),
          IconButton(
            tooltip: "Switch camera",
            onPressed: _cameraReady ? _switchCamera : null,
            icon: const Icon(Icons.cameraswitch, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Future<void> _switchCamera() async {
    try {
      final List<CameraDescription> cameras = await availableCameras();
      if (cameras.length < 2 || _camera == null) return;
      final CameraLensDirection current = _camera!.description.lensDirection;
      final CameraDescription next = cameras.firstWhere(
        (c) => c.lensDirection != current,
        orElse: () => cameras.first,
      );
      await _camera!.dispose();
      final CameraController controller = CameraController(
        next,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _camera = controller;
        _mirror = next.lensDirection == CameraLensDirection.front;
      });
    } catch (_) {}
  }
}

/// A small rounded status pill.
class _Pill extends StatelessWidget {
  final String text;
  const _Pill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text,
          style: const TextStyle(color: Colors.white, fontSize: 11)),
    );
  }
}

/// Horizontally scrolling effect picker.
class _EffectCarousel extends StatelessWidget {
  final List<Effect> effects;
  final Effect active;
  final ValueChanged<Effect> onSelect;

  const _EffectCarousel({
    required this.effects,
    required this.active,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: effects.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final Effect e = effects[i];
          final bool selected = e.id == active.id;
          return GestureDetector(
            onTap: () => onSelect(e),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _swatch(e),
                    border: Border.all(
                      color: selected ? Colors.amber : Colors.white24,
                      width: selected ? 3 : 1.5,
                    ),
                  ),
                  child: Icon(_icon(e.category),
                      color: Colors.white, size: 22),
                ),
                const SizedBox(height: 4),
                Text(
                  e.name,
                  style: TextStyle(
                    color: selected ? Colors.amber : Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _swatch(Effect e) {
    if (e.mask != null) return e.mask!.accent;
    if (e.grade != null) return const Color(0xFF334155);
    switch (e.category) {
      case EffectCategory.beauty:
        return const Color(0xFFB06A8A);
      case EffectCategory.makeup:
        return const Color(0xFFC21A3B);
      case EffectCategory.none:
        return const Color(0xFF444444);
      default:
        return const Color(0xFF556070);
    }
  }

  IconData _icon(EffectCategory c) {
    switch (c) {
      case EffectCategory.beauty:
        return Icons.face_retouching_natural;
      case EffectCategory.makeup:
        return Icons.brush;
      case EffectCategory.mask:
        return Icons.emoji_emotions;
      case EffectCategory.grade:
        return Icons.gradient;
      case EffectCategory.none:
        return Icons.close;
    }
  }
}

/// A drawn stand-in "face" so the studio and its overlays render on devices or
/// environments without a camera.
class _SyntheticFace extends StatelessWidget {
  const _SyntheticFace();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.1),
          radius: 0.9,
          colors: <Color>[Color(0xFFE9C3A6), Color(0xFF9A5B3B), Color(0xFF241017)],
          stops: <double>[0.0, 0.55, 1.0],
        ),
      ),
      child: CustomPaint(painter: _SyntheticFacePainter()),
    );
  }
}

class _SyntheticFacePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = Offset(size.width / 2, size.height * 0.46);
    final double eyeGap = size.width * 0.14;
    final Paint eye = Paint()..color = const Color(0xFF3A2418);
    canvas.drawCircle(Offset(c.dx - eyeGap / 2, c.dy), eyeGap * 0.12, eye);
    canvas.drawCircle(Offset(c.dx + eyeGap / 2, c.dy), eyeGap * 0.12, eye);
    final Paint mouth = Paint()
      ..color = const Color(0xFF6B2B2B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.012
      ..strokeCap = StrokeCap.round;
    final Path smile = Path()
      ..moveTo(c.dx - eyeGap * 0.5, c.dy + eyeGap * 1.5)
      ..quadraticBezierTo(c.dx, c.dy + eyeGap * 1.9, c.dx + eyeGap * 0.5,
          c.dy + eyeGap * 1.5);
    canvas.drawPath(smile, mouth);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
