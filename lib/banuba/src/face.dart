import "dart:math" as math;
import "dart:ui" show Offset, Rect;

/// A single tracked face in normalized image space (all coordinates in 0..1,
/// origin top-left). Mirrors the landmark set an AR SDK exposes to effects.
class Face {
  /// Face bounding box in normalized coordinates.
  final Rect boundingBox;

  /// Named landmarks, all normalized.
  final Offset leftEye;
  final Offset rightEye;
  final Offset noseTip;
  final Offset mouthLeft;
  final Offset mouthRight;
  final Offset mouthCenter;
  final Offset foreheadTop;
  final Offset chinBottom;

  /// In-plane head roll in radians (rotation around the view axis).
  final double roll;

  /// Detector confidence 0..1.
  final double confidence;

  const Face({
    required this.boundingBox,
    required this.leftEye,
    required this.rightEye,
    required this.noseTip,
    required this.mouthLeft,
    required this.mouthRight,
    required this.mouthCenter,
    required this.foreheadTop,
    required this.chinBottom,
    this.roll = 0.0,
    this.confidence = 1.0,
  });

  /// Distance between the eyes — the natural unit for scaling AR assets so a
  /// mask stays proportional as the face moves toward or away from the camera.
  double get interocular => (rightEye - leftEye).distance;

  /// Midpoint between the eyes.
  Offset get eyeCenter => Offset(
        (leftEye.dx + rightEye.dx) / 2,
        (leftEye.dy + rightEye.dy) / 2,
      );

  /// Convert a normalized point to pixel space for a preview of [size].
  static Offset toPixels(Offset normalized, double width, double height) =>
      Offset(normalized.dx * width, normalized.dy * height);

  /// Build a face from an eye-centered pose. Useful for synthesising a face
  /// from a bounding box + eye positions when a detector only reports those.
  factory Face.fromEyes({
    required Offset leftEye,
    required Offset rightEye,
    required Rect boundingBox,
    double confidence = 1.0,
  }) {
    final Offset center = Offset(
      (leftEye.dx + rightEye.dx) / 2,
      (leftEye.dy + rightEye.dy) / 2,
    );
    final double roll = math.atan2(
      rightEye.dy - leftEye.dy,
      rightEye.dx - leftEye.dx,
    );
    final double eyeGap = (rightEye - leftEye).distance;
    // Derive plausible lower-face landmarks from the eye pose.
    final Offset down = Offset(-math.sin(roll), math.cos(roll));
    final Offset right = Offset(math.cos(roll), math.sin(roll));
    Offset along(double d, Offset dir) =>
        Offset(center.dx + dir.dx * d, center.dy + dir.dy * d);
    final Offset nose = along(eyeGap * 0.9, down);
    final Offset mouth = along(eyeGap * 1.5, down);
    return Face(
      boundingBox: boundingBox,
      leftEye: leftEye,
      rightEye: rightEye,
      noseTip: nose,
      mouthCenter: mouth,
      mouthLeft: Offset(
        mouth.dx - right.dx * eyeGap * 0.45,
        mouth.dy - right.dy * eyeGap * 0.45,
      ),
      mouthRight: Offset(
        mouth.dx + right.dx * eyeGap * 0.45,
        mouth.dy + right.dy * eyeGap * 0.45,
      ),
      foreheadTop: Offset(center.dx - down.dx * eyeGap * 1.6,
          center.dy - down.dy * eyeGap * 1.6),
      chinBottom: along(eyeGap * 2.4, down),
      roll: roll,
      confidence: confidence,
    );
  }
}
