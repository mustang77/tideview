#!/usr/bin/env python3
"""Create the ML Kit face tracker, aliasing ML Kit's Face to avoid collision
with the SDK's own Face class."""
content = r'''import "dart:ui" show Offset, Rect, Size;

import "package:camera/camera.dart";
import "package:flutter/foundation.dart" show WriteBuffer;
import "package:google_mlkit_face_detection/google_mlkit_face_detection.dart"
    as mlkit;

import "../src/face.dart";
import "../src/face_tracker.dart";

/// A real [FaceTracker] backed by Google ML Kit face detection. It consumes the
/// camera image stream, runs on-device detection, and exposes the most recently
/// detected faces (normalized 0..1) to the effect pipeline.
///
/// ML Kit is async (a frame is processed a moment after it arrives) while
/// [FaceTracker.facesAt] is sync, so this stores the latest result and returns
/// it regardless of the requested time [t].
class MLKitFaceTracker implements FaceTracker {
  final mlkit.FaceDetector _detector = mlkit.FaceDetector(
    options: mlkit.FaceDetectorOptions(
      enableLandmarks: true,
      enableContours: false,
      enableClassification: false,
      performanceMode: mlkit.FaceDetectorMode.fast,
    ),
  );

  List<Face> _latest = const <Face>[];
  bool _busy = false;

  int sensorOrientation;
  bool isFront;

  MLKitFaceTracker({this.sensorOrientation = 90, this.isFront = true});

  void updateCamera({required int sensorOrientation, required bool isFront}) {
    this.sensorOrientation = sensorOrientation;
    this.isFront = isFront;
  }

  /// Feed a camera frame (from CameraController.startImageStream).
  Future<void> processFrame(CameraImage image) async {
    if (_busy) return; // drop frames while one is in flight
    _busy = true;
    try {
      final input = _toInputImage(image);
      if (input == null) {
        _busy = false;
        return;
      }
      final faces = await _detector.processImage(input);
      final bool swap =
          sensorOrientation == 90 || sensorOrientation == 270;
      final double iw = swap ? image.height.toDouble() : image.width.toDouble();
      final double ih = swap ? image.width.toDouble() : image.height.toDouble();
      _latest = faces
          .map((f) => _convert(f, iw, ih))
          .whereType<Face>()
          .toList();
    } catch (_) {
      // keep last known faces on error
    }
    _busy = false;
  }

  Face? _convert(mlkit.Face mlFace, double iw, double ih) {
    final le = mlFace.landmarks[mlkit.FaceLandmarkType.leftEye]?.position;
    final re = mlFace.landmarks[mlkit.FaceLandmarkType.rightEye]?.position;
    final box = mlFace.boundingBox;
    if (le == null || re == null) return null;

    Offset norm(double px, double py) {
      double nx = px / iw;
      double ny = py / ih;
      if (isFront) nx = 1.0 - nx; // mirror front preview
      return Offset(nx.clamp(0.0, 1.0), ny.clamp(0.0, 1.0));
    }

    final Offset eyeA = norm(le.x.toDouble(), le.y.toDouble());
    final Offset eyeB = norm(re.x.toDouble(), re.y.toDouble());
    final Offset screenLeft = eyeA.dx <= eyeB.dx ? eyeA : eyeB;
    final Offset screenRight = eyeA.dx <= eyeB.dx ? eyeB : eyeA;

    Rect nbox = Rect.fromLTRB(
      box.left / iw,
      box.top / ih,
      box.right / iw,
      box.bottom / ih,
    );
    if (isFront) {
      nbox = Rect.fromLTRB(
        1.0 - nbox.right,
        nbox.top,
        1.0 - nbox.left,
        nbox.bottom,
      );
    }

    return Face.fromEyes(
      leftEye: screenLeft,
      rightEye: screenRight,
      boundingBox: nbox,
      confidence: 1.0,
    );
  }

  InputImage? _toInputImage(CameraImage image) {
    final rotation =
        mlkit.InputImageRotationValue.fromRawValue(sensorOrientation) ??
            mlkit.InputImageRotation.rotation90deg;
    final format =
        mlkit.InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    return mlkit.InputImage.fromBytes(
      bytes: bytes,
      metadata: mlkit.InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.isNotEmpty
            ? image.planes.first.bytesPerRow
            : image.width,
      ),
    );
  }

  @override
  List<Face> facesAt(double t) => _latest;

  @override
  void dispose() {
    _detector.close();
  }
}
'''
import os
os.makedirs(r"lib\banuba\ui", exist_ok=True)
with open(r"lib\banuba\src\mlkit_face_tracker.dart", "w", encoding="utf-8", newline="\r\n") as f:
    f.write(content)
print("wrote mlkit_face_tracker.dart")
