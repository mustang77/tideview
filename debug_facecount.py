#!/usr/bin/env python3
"""Add debug: print detected face count from ML Kit, and expose latest count so
we can show it on screen. Confirms whether detection or rendering is the issue."""
import sys
F = r"lib\banuba\src\mlkit_face_tracker.dart"
s = open(F, encoding="utf-8", newline="").read().replace("\r\n","\n")

# add a public counter + debugPrint in processFrame
if "int lastCount = 0;" not in s:
    s = s.replace("  List<Face> _latest = const <Face>[];",
                  "  List<Face> _latest = const <Face>[];\n  int lastCount = 0;\n  int frameCount = 0;", 1)

# add import for debugPrint
if "foundation.dart" in s and "debugPrint" not in s:
    pass  # WriteBuffer import already pulls foundation

# after we set _latest, record count + print
old = """      _latest = faces
          .map((f) => _convert(f, iw, ih))
          .whereType<Face>()
          .toList();"""
new = """      _latest = faces
          .map((f) => _convert(f, iw, ih))
          .whereType<Face>()
          .toList();
      frameCount++;
      lastCount = _latest.length;
      if (frameCount % 15 == 0) {
        // ignore: avoid_print
        print('MLKIT frame=$frameCount rawFaces=${faces.length} '
            'converted=${_latest.length}');
      }"""
if old in s:
    s = s.replace(old, new, 1)
    print("OK: debug in processFrame")
else:
    print("WARN: processFrame block not matched")

# also print on error path
old_err = """    } catch (_) {
      // keep last known faces on error
    }
    _busy = false;"""
new_err = """    } catch (e) {
      // ignore: avoid_print
      print('MLKIT ERROR: $e');
    }
    _busy = false;"""
if old_err in s:
    s = s.replace(old_err, new_err, 1)
    print("OK: error logging")

open(F,"w",encoding="utf-8",newline="").write(s.replace("\n","\r\n"))
print("done")
