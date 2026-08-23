#!/usr/bin/env python3
"""Add a debug overlay: draw dots at detected eye/nose/mouth positions so we can
see exactly where the mapping lands and diagnose the offset."""
import sys, re
F = r"lib\banuba\ui\ar_studio_screen.dart"
s = open(F, encoding="utf-8", newline="").read().replace("\r\n","\n")

# Add a debug painter class at end of file.
if "_DebugLandmarkPainter" not in s:
    s = s.rstrip() + '''

class _DebugLandmarkPainter extends CustomPainter {
  final List<Face> faces;
  _DebugLandmarkPainter(this.faces);
  @override
  void paint(Canvas canvas, Size size) {
    final dot = Paint()..color = const Color(0xFF00FF00);
    final box = Paint()
      ..color = const Color(0xFFFF0000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final f in faces) {
      void d(Offset n, [double r = 6]) {
        canvas.drawCircle(
            Offset(n.dx * size.width, n.dy * size.height), r, dot);
      }
      d(f.leftEye);
      d(f.rightEye);
      d(f.noseTip, 4);
      d(f.mouthCenter, 4);
      final b = f.boundingBox;
      canvas.drawRect(
        Rect.fromLTRB(b.left * size.width, b.top * size.height,
            b.right * size.width, b.bottom * size.height),
        box,
      );
    }
  }
  @override
  bool shouldRepaint(covariant _DebugLandmarkPainter old) => true;
}
'''
    print("OK: debug painter class")

# Add the debug painter into the stack, on top of the existing overlay.
# Find the CustomPaint with FaceOverlayPainter and add a sibling after it.
m = re.search(r"(CustomPaint\(\s*painter: FaceOverlayPainter\([^;]*?\),?\s*\),)", s)
if m:
    block = m.group(1)
    s = s.replace(block, block + "\n                  CustomPaint(\n                    painter: _DebugLandmarkPainter(faces),\n                  ),", 1)
    print("OK: debug painter added to stack")
else:
    print("WARN: FaceOverlayPainter CustomPaint not matched - showing region")
    j = s.find("FaceOverlayPainter")
    print(repr(s[j-40:j+200]) if j>=0 else "not found")

open(F,"w",encoding="utf-8",newline="").write(s.replace("\n","\r\n"))
c = open(F, encoding="utf-8").read()
print("verify:", "OK" if "_DebugLandmarkPainter" in c else "MISS")
print("brace:", "OK" if c.count("{")==c.count("}") else "OFF %d"%(c.count('{')-c.count('}')))
