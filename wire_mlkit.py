#!/usr/bin/env python3
"""Wire MLKitFaceTracker into AR Studio: add dependency, swap tracker, start
image stream feeding frames. Run from the tideview-banuba project root."""
import sys, re

# 1) pubspec: add google_mlkit_face_detection
P = "pubspec.yaml"
s = open(P, encoding="utf-8", newline="").read().replace("\r\n","\n")
if "google_mlkit_face_detection" not in s:
    # add after camera: line
    m = re.search(r"(\n\s*camera:\s*[^\n]+\n)", s)
    if m:
        ins = m.group(1) + "  google_mlkit_face_detection: ^0.13.1\n"
        s = s.replace(m.group(1), ins, 1)
        open(P,"w",encoding="utf-8",newline="").write(s.replace("\n","\r\n"))
        print("OK: pubspec dependency added")
    else:
        print("WARN: camera: line not found in pubspec")
else:
    print("skip: dependency present")

# 2) ar_studio_screen.dart wiring
F = r"lib\banuba\ui\ar_studio_screen.dart"
s = open(F, encoding="utf-8", newline="").read().replace("\r\n","\n")

# import the tracker
if "mlkit_face_tracker.dart" not in s:
    # add after the last existing import of the banuba src, or top
    m = re.search(r'(import "[^"]*face_tracker\.dart";\n)', s)
    if m:
        s = s.replace(m.group(1), m.group(1) + 'import "../src/mlkit_face_tracker.dart";\n', 1)
    else:
        # fallback: after first import
        m2 = re.search(r'(import "[^"]+";\n)', s)
        s = s.replace(m2.group(1), m2.group(1) + 'import "../src/mlkit_face_tracker.dart";\n', 1)
    print("OK: tracker import")

# swap the tracker field to the ML Kit one (mutable, not const)
s2 = s.replace(
    "final FaceTracker _tracker = const MockFaceTracker();",
    "final MLKitFaceTracker _tracker = MLKitFaceTracker();")
if s2 != s:
    s = s2
    print("OK: tracker swapped")
else:
    print("WARN: tracker field not found (check exact text)")

# start image stream after camera initialize + set orientation/front. We hook
# into where the CameraController is created. Add a helper _startStream and call
# it. Find 'await controller.initialize();' and append stream start.
if "startImageStream" not in s:
    m = re.search(r"(await controller\.initialize\(\);\n)", s)
    if m:
        hook = m.group(1) + '''      try {
        _tracker.updateCamera(
          sensorOrientation: controller.description.sensorOrientation,
          isFront: controller.description.lensDirection ==
              CameraLensDirection.front,
        );
        await controller.startImageStream(_tracker.processFrame);
      } catch (_) {}
'''
        s = s.replace(m.group(1), hook, 1)
        print("OK: image stream started")
    else:
        print("WARN: controller.initialize() not found - manual wiring needed")
else:
    print("skip: stream already started")

# dispose tracker
if "_tracker.dispose()" not in s:
    m = re.search(r"(\n\s*@override\n\s*void dispose\(\) \{\n)", s)
    if m:
        s = s.replace(m.group(1), m.group(1) + "    _tracker.dispose();\n", 1)
        print("OK: tracker dispose")

open(F,"w",encoding="utf-8",newline="").write(s.replace("\n","\r\n"))
c = open(F, encoding="utf-8").read()
print("verify swap:", "OK" if "MLKitFaceTracker _tracker" in c else "MISS")
print("verify stream:", "OK" if "startImageStream" in c else "MISS")
print("brace:", "OK" if c.count("{")==c.count("}") else "OFF %d"%(c.count('{')-c.count('}')))
