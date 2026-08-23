#!/usr/bin/env python3
"""Fix: InputImage return type needs the mlkit. prefix."""
F = r"lib\banuba\src\mlkit_face_tracker.dart"
s = open(F, encoding="utf-8", newline="").read().replace("\r\n","\n")

# The method signature: 'InputImage? _toInputImage(CameraImage image) {'
before = s
s = s.replace("  InputImage? _toInputImage(CameraImage image) {",
              "  mlkit.InputImage? _toInputImage(CameraImage image) {", 1)
if s == before:
    print("MISS: signature - searching")
    import re
    for m in re.finditer(r"InputImage\??", s):
        print("  found at", m.start(), s[m.start()-10:m.start()+20])
else:
    print("OK: return type prefixed")

open(F,"w",encoding="utf-8",newline="").write(s.replace("\n","\r\n"))
c = open(F, encoding="utf-8").read()
# check no bare InputImage remains (all should be mlkit.InputImage)
import re
bare = [m.start() for m in re.finditer(r"(?<!\.)(?<!mlkit\.)\bInputImage\b", c)]
print("bare InputImage refs:", len(bare))
