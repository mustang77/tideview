#!/usr/bin/env python3
"""Fix ImageFormat not supported: request NV21 from the camera + tell ML Kit
the input is NV21. This is the reliable Android format for ML Kit."""
import sys, re

# --- 1) ar_studio_screen.dart: set imageFormatGroup: ImageFormatGroup.nv21 on
# both CameraController constructions ---
F = r"lib\banuba\ui\ar_studio_screen.dart"
s = open(F, encoding="utf-8", newline="").read().replace("\r\n","\n")

# Add imageFormatGroup to CameraController(...) calls that don't have it.
# Pattern: CameraController(\n  <cam>,\n  <resolution>,\n ... )
# Simplest: insert after each "CameraController(" first argument block. We add
# the named param right after the resolution preset if present, else after cam.
count = 0
def add_fmt(m):
    global count
    block = m.group(0)
    if "imageFormatGroup" in block:
        return block
    count += 1
    # insert before the closing paren of the constructor call args
    return block  # placeholder; we handle via targeted replaces below

# Targeted: most camera plugin usage is CameraController(desc, ResolutionPreset.x,
# enableAudio: false, ...). Add imageFormatGroup: ImageFormatGroup.nv21.
# Handle common shapes:
patterns = [
    ("enableAudio: false,",
     "enableAudio: false,\n        imageFormatGroup: ImageFormatGroup.nv21,"),
    ("enableAudio: false)",
     "enableAudio: false,\n        imageFormatGroup: ImageFormatGroup.nv21)"),
]
applied = 0
for old, new in patterns:
    n = s.count(old)
    if n and "imageFormatGroup" not in s:
        s = s.replace(old, new)
        applied += n
if applied == 0 and "imageFormatGroup" not in s:
    # fallback: after 'ResolutionPreset.' lines add param — show for manual
    print("WARN: could not auto-add imageFormatGroup; need manual. Showing CameraController usages:")
    for m in re.finditer(r"CameraController\([^;]{0,200}", s):
        print("----", m.group(0)[:180])
else:
    print(f"OK: added imageFormatGroup to camera ({applied} spot(s))")

open(F,"w",encoding="utf-8",newline="").write(s.replace("\n","\r\n"))

# --- 2) mlkit_face_tracker.dart: use nv21 format + single bytesPerRow ---
T = r"lib\banuba\src\mlkit_face_tracker.dart"
t = open(T, encoding="utf-8", newline="").read().replace("\r\n","\n")

# Replace the _toInputImage body to force NV21.
old_body = '''    final format =
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
    );'''
new_body = '''    // We request ImageFormatGroup.nv21 from the camera, so the first plane
    // already holds the full NV21 buffer on Android.
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
        format: mlkit.InputImageFormat.nv21,
        bytesPerRow: image.planes.isNotEmpty
            ? image.planes.first.bytesPerRow
            : image.width,
      ),
    );'''
if old_body in t:
    t = t.replace(old_body, new_body, 1)
    print("OK: tracker uses NV21")
else:
    print("WARN: tracker body not matched exactly")
    j = t.find("final format =")
    print(repr(t[j:j+120]) if j>=0 else "format line not found")

open(T,"w",encoding="utf-8",newline="").write(t.replace("\n","\r\n"))
c = open(T, encoding="utf-8").read()
print("verify nv21:", "OK" if "InputImageFormat.nv21" in c else "MISS")
