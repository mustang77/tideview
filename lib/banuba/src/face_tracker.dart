import "dart:math" as math;
import "dart:ui" show Offset, Rect;

import "face.dart";

/// Source of tracked faces for the effect pipeline.
///
/// The real Banuba SDK plugs a neural face-mesh model in here. This clone
/// ships a deterministic [MockFaceTracker] so the whole render pipeline — beauty
/// grading, AR masks, capture — is runnable and testable without camera
/// hardware or a native detector. Swap in an ML Kit / MediaPipe / Banuba-NN
/// implementation of this interface to drive it from a real camera stream.
abstract class FaceTracker {
  /// Faces detected for the frame at time [t] seconds. May be empty.
  List<Face> facesAt(double t);

  void dispose() {}
}

/// A tracker that synthesises a single gently-moving face. It takes no random
/// input (so results are reproducible) and drives entirely off the frame time,
/// which makes the AR overlays visibly "come alive" in the demo and keeps unit
/// tests deterministic.
class MockFaceTracker implements FaceTracker {
  /// How far the face drifts around the frame, as a fraction of the frame.
  final double sway;

  /// Whether the synthesized face tilts its head.
  final bool headTilt;

  const MockFaceTracker({this.sway = 0.04, this.headTilt = true});

  @override
  List<Face> facesAt(double t) {
    // Slow Lissajous drift around center so the mask tracks something.
    final double cx = 0.5 + math.sin(t * 0.6) * sway;
    final double cy = 0.46 + math.sin(t * 0.9 + 1.0) * sway * 0.6;
    final double roll = headTilt ? math.sin(t * 0.5) * 0.12 : 0.0;

    const double eyeGap = 0.14; // normalized inter-ocular distance
    final Offset dirRight = Offset(math.cos(roll), math.sin(roll));
    final Offset left = Offset(
      cx - dirRight.dx * eyeGap / 2,
      cy - dirRight.dy * eyeGap / 2,
    );
    final Offset right = Offset(
      cx + dirRight.dx * eyeGap / 2,
      cy + dirRight.dy * eyeGap / 2,
    );

    final Rect box = Rect.fromCenter(
      center: Offset(cx, cy + 0.06),
      width: eyeGap * 2.4,
      height: eyeGap * 3.4,
    );
    return <Face>[
      Face.fromEyes(
        leftEye: left,
        rightEye: right,
        boundingBox: box,
        confidence: 1.0,
      ),
    ];
  }

  @override
  void dispose() {}
}
