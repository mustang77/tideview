import "dart:ui" show Color;

import "color_matrix.dart";

/// Category of a built-in or custom effect, used to group the effect carousel.
enum EffectCategory { none, beauty, makeup, mask, grade }

/// The AR asset a mask effect renders, anchored to face landmarks.
enum MaskShape { glasses, dogEars, crown, mustache, heartEyes }

/// Real-time beautification parameters. These fold into a single GPU color
/// filter (see [toColorMatrix]) plus a separate skin-smoothing blur pass.
class BeautyConfig {
  /// Skin smoothing 0..1 (drives a selective blur radius).
  final double smoothSkin;

  /// Brightness lift 0..1.
  final double brighten;

  /// Warmth -1..1 (negative cools).
  final double warmth;

  /// Saturation multiplier, 1.0 neutral.
  final double saturation;

  /// Contrast multiplier, 1.0 neutral.
  final double contrast;

  const BeautyConfig({
    this.smoothSkin = 0.0,
    this.brighten = 0.0,
    this.warmth = 0.0,
    this.saturation = 1.0,
    this.contrast = 1.0,
  });

  static const BeautyConfig none = BeautyConfig();

  bool get isNeutral =>
      smoothSkin == 0 &&
      brighten == 0 &&
      warmth == 0 &&
      saturation == 1.0 &&
      contrast == 1.0;

  /// Maximum blur sigma applied at smoothSkin == 1.
  double get blurSigma => smoothSkin.clamp(0.0, 1.0) * 3.5;

  BeautyConfig copyWith({
    double? smoothSkin,
    double? brighten,
    double? warmth,
    double? saturation,
    double? contrast,
  }) =>
      BeautyConfig(
        smoothSkin: smoothSkin ?? this.smoothSkin,
        brighten: brighten ?? this.brighten,
        warmth: warmth ?? this.warmth,
        saturation: saturation ?? this.saturation,
        contrast: contrast ?? this.contrast,
      );

  /// Collapse the tone controls into one color matrix.
  ColorMatrix toColorMatrix() {
    ColorMatrix m = ColorMatrix.identity();
    if (brighten != 0) {
      m = m.then(ColorMatrix.brightness(brighten * 40));
    }
    if (contrast != 1.0) {
      m = m.then(ColorMatrix.contrast(contrast));
    }
    if (saturation != 1.0) {
      m = m.then(ColorMatrix.saturation(saturation));
    }
    if (warmth != 0) {
      m = m.then(ColorMatrix.temperature(warmth));
    }
    return m;
  }
}

/// Virtual makeup: colored tints over lip/cheek regions. Rendered as landmark
/// anchored overlays with a soft blend.
class MakeupConfig {
  final Color? lipColor;
  final double lipStrength;
  final Color? blushColor;
  final double blushStrength;

  const MakeupConfig({
    this.lipColor,
    this.lipStrength = 0.5,
    this.blushColor,
    this.blushStrength = 0.35,
  });

  bool get hasLips => lipColor != null && lipStrength > 0;
  bool get hasBlush => blushColor != null && blushStrength > 0;
  bool get isEmpty => !hasLips && !hasBlush;
}

/// A full-frame color LUT-style grade (film looks, mood tints).
class ColorGrade {
  final String name;
  final ColorMatrix matrix;
  const ColorGrade(this.name, this.matrix);
}

/// An AR mask effect: which asset to draw and its accent color.
class ARMaskConfig {
  final MaskShape shape;
  final Color accent;
  const ARMaskConfig(this.shape, {this.accent = const Color(0xFF222222)});
}

/// A composable effect, the unit the [EffectPlayer] activates. An effect can
/// carry any combination of a beauty preset, makeup, a color grade, and an AR
/// mask — matching how Banuba effects bundle multiple features.
class Effect {
  final String id;
  final String name;
  final EffectCategory category;
  final BeautyConfig beauty;
  final MakeupConfig? makeup;
  final ColorGrade? grade;
  final ARMaskConfig? mask;

  const Effect({
    required this.id,
    required this.name,
    required this.category,
    this.beauty = BeautyConfig.none,
    this.makeup,
    this.grade,
    this.mask,
  });

  /// The empty pass-through effect.
  static const Effect none = Effect(
    id: "none",
    name: "Original",
    category: EffectCategory.none,
  );

  bool get isNone => id == "none";
}
