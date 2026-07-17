import "dart:ui" show Offset, Rect;

import "package:flutter_test/flutter_test.dart";
import "package:tideview/banuba/banuba.dart";

void main() {
  group("ColorMatrix", () {
    test("identity leaves colors unchanged", () {
      final ColorMatrix m = ColorMatrix.identity();
      expect(m.isIdentity, isTrue);
      final List<double> out = m.applyToRgb(100, 150, 200);
      expect(out[0], closeTo(100, 1e-6));
      expect(out[1], closeTo(150, 1e-6));
      expect(out[2], closeTo(200, 1e-6));
    });

    test("brightness lifts every channel by the amount", () {
      final List<double> out = ColorMatrix.brightness(20).applyToRgb(50, 60, 70);
      expect(out[0], closeTo(70, 1e-6));
      expect(out[1], closeTo(80, 1e-6));
      expect(out[2], closeTo(90, 1e-6));
    });

    test("brightness clamps at the 0..255 range", () {
      final List<double> out = ColorMatrix.brightness(100).applyToRgb(200, 200, 200);
      expect(out[0], 255);
    });

    test("zero saturation produces equal (grey) channels", () {
      final List<double> out = ColorMatrix.saturation(0).applyToRgb(200, 50, 10);
      expect(out[0], closeTo(out[1], 1e-6));
      expect(out[1], closeTo(out[2], 1e-6));
    });

    test("warm temperature raises red and lowers blue", () {
      final List<double> out = ColorMatrix.temperature(1.0).applyToRgb(120, 120, 120);
      expect(out[0], greaterThan(120));
      expect(out[2], lessThan(120));
    });

    test("composition applies the second transform to the first's result", () {
      // brightness(+10) then brightness(+5) == brightness(+15)
      final ColorMatrix composed =
          ColorMatrix.brightness(10).then(ColorMatrix.brightness(5));
      final List<double> out = composed.applyToRgb(0, 0, 0);
      expect(out[0], closeTo(15, 1e-6));
    });

    test("scaledFromIdentity(0) is identity, (1) is full", () {
      final ColorMatrix full = ColorMatrix.brightness(40);
      expect(full.scaledFromIdentity(0).isIdentity, isTrue);
      final List<double> half = full.scaledFromIdentity(0.5).applyToRgb(0, 0, 0);
      expect(half[0], closeTo(20, 1e-6));
    });
  });

  group("BeautyConfig", () {
    test("neutral config yields an identity color matrix", () {
      expect(BeautyConfig.none.isNeutral, isTrue);
      expect(BeautyConfig.none.toColorMatrix().isIdentity, isTrue);
    });

    test("blur sigma scales with skin smoothing", () {
      expect(const BeautyConfig(smoothSkin: 0).blurSigma, 0);
      expect(const BeautyConfig(smoothSkin: 1).blurSigma, greaterThan(0));
    });

    test("copyWith overrides only the given field", () {
      const BeautyConfig b = BeautyConfig(brighten: 0.2, warmth: 0.1);
      final BeautyConfig c = b.copyWith(brighten: 0.5);
      expect(c.brighten, 0.5);
      expect(c.warmth, 0.1);
    });
  });

  group("Face geometry", () {
    test("fromEyes computes roll from eye slope", () {
      final Face level = Face.fromEyes(
        leftEye: const Offset(0.4, 0.5),
        rightEye: const Offset(0.6, 0.5),
        boundingBox: const Rect.fromLTWH(0.35, 0.3, 0.3, 0.4),
      );
      expect(level.roll, closeTo(0, 1e-9));

      final Face tilted = Face.fromEyes(
        leftEye: const Offset(0.4, 0.5),
        rightEye: const Offset(0.6, 0.6),
        boundingBox: const Rect.fromLTWH(0.35, 0.3, 0.3, 0.4),
      );
      expect(tilted.roll, greaterThan(0));
    });

    test("interocular distance and eye center are correct", () {
      final Face f = Face.fromEyes(
        leftEye: const Offset(0.4, 0.5),
        rightEye: const Offset(0.6, 0.5),
        boundingBox: const Rect.fromLTWH(0.35, 0.3, 0.3, 0.4),
      );
      expect(f.interocular, closeTo(0.2, 1e-9));
      expect(f.eyeCenter.dx, closeTo(0.5, 1e-9));
    });

    test("derived nose sits below the eyes", () {
      final Face f = Face.fromEyes(
        leftEye: const Offset(0.4, 0.5),
        rightEye: const Offset(0.6, 0.5),
        boundingBox: const Rect.fromLTWH(0.35, 0.3, 0.3, 0.4),
      );
      expect(f.noseTip.dy, greaterThan(f.eyeCenter.dy));
      expect(f.chinBottom.dy, greaterThan(f.noseTip.dy));
    });

    test("toPixels scales normalized coords to a preview size", () {
      final Offset p = Face.toPixels(const Offset(0.5, 0.25), 200, 400);
      expect(p.dx, 100);
      expect(p.dy, 100);
    });
  });

  group("MockFaceTracker", () {
    test("always yields exactly one face and is deterministic", () {
      const MockFaceTracker t = MockFaceTracker();
      final List<Face> a = t.facesAt(1.5);
      final List<Face> b = t.facesAt(1.5);
      expect(a.length, 1);
      expect(a.first.eyeCenter.dx, closeTo(b.first.eyeCenter.dx, 1e-12));
    });

    test("face drifts over time", () {
      const MockFaceTracker t = MockFaceTracker();
      final Face f0 = t.facesAt(0).first;
      final Face f1 = t.facesAt(3).first;
      expect((f0.eyeCenter - f1.eyeCenter).distance, greaterThan(0));
    });
  });

  group("EffectPlayer", () {
    test("defaults to the pass-through effect with no filter", () {
      final EffectPlayer p = EffectPlayer();
      expect(p.effect.isNone, isTrue);
      expect(p.colorFilter, isNull);
      expect(p.mask, isNull);
      expect(p.makeup, isNull);
      p.dispose();
    });

    test("loading a grade effect produces a color filter", () {
      final EffectPlayer p = EffectPlayer();
      p.loadEffect(EffectsCatalog.noir);
      expect(p.colorFilter, isNotNull);
      p.dispose();
    });

    test("mask effect exposes its mask config", () {
      final EffectPlayer p = EffectPlayer();
      p.loadEffect(EffectsCatalog.glasses);
      expect(p.mask, isNotNull);
      expect(p.mask!.shape, MaskShape.glasses);
      p.dispose();
    });

    test("disabling bypasses all effects (before/after)", () {
      final EffectPlayer p = EffectPlayer();
      p.loadEffect(EffectsCatalog.glam);
      expect(p.colorFilter, isNotNull);
      p.setEnabled(false);
      expect(p.colorFilter, isNull);
      expect(p.blurSigma, 0);
      p.dispose();
    });

    test("beauty override stacks on top of the effect preset", () {
      final EffectPlayer p = EffectPlayer();
      p.loadEffect(EffectsCatalog.natural);
      final double baseBlur = p.blurSigma;
      p.setBeautyOverride(const BeautyConfig(smoothSkin: 0.5));
      expect(p.blurSigma, greaterThan(baseBlur));
      p.dispose();
    });

    test("notifies listeners on effect change", () {
      final EffectPlayer p = EffectPlayer();
      int calls = 0;
      p.addListener(() => calls++);
      p.loadEffect(EffectsCatalog.cyber);
      expect(calls, 1);
      // Loading the same effect again does not re-notify.
      p.loadEffect(EffectsCatalog.cyber);
      expect(calls, 1);
      p.dispose();
    });

    test("reset returns to the original pass-through state", () {
      final EffectPlayer p = EffectPlayer();
      p.loadEffect(EffectsCatalog.vintage);
      p.setBeautyOverride(const BeautyConfig(brighten: 0.3));
      p.reset();
      expect(p.effect.isNone, isTrue);
      expect(p.beautyOverride.isNeutral, isTrue);
      expect(p.colorFilter, isNull);
      p.dispose();
    });
  });

  group("EffectsCatalog", () {
    test("all effects have unique ids and lead with the pass-through", () {
      final List<Effect> all = EffectsCatalog.all;
      expect(all.first.isNone, isTrue);
      final Set<String> ids = all.map((e) => e.id).toSet();
      expect(ids.length, all.length);
    });
  });
}
