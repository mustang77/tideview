import "dart:ui" show Color;

import "color_matrix.dart";
import "effect.dart";

/// Built-in effect library. Mirrors the sort of ready-made effect pack an AR
/// SDK ships: a beauty preset, a few virtual-makeup looks, AR masks, and
/// cinematic color grades.
class EffectsCatalog {
  EffectsCatalog._();

  static const Effect natural = Effect(
    id: "beauty_natural",
    name: "Natural",
    category: EffectCategory.beauty,
    beauty: BeautyConfig(
      smoothSkin: 0.45,
      brighten: 0.18,
      warmth: 0.12,
      saturation: 1.06,
      contrast: 1.02,
    ),
  );

  static const Effect glam = Effect(
    id: "beauty_glam",
    name: "Glam",
    category: EffectCategory.beauty,
    beauty: BeautyConfig(
      smoothSkin: 0.8,
      brighten: 0.3,
      warmth: 0.2,
      saturation: 1.12,
      contrast: 1.05,
    ),
  );

  static const Effect lipstick = Effect(
    id: "makeup_lips",
    name: "Ruby Lips",
    category: EffectCategory.makeup,
    beauty: BeautyConfig(smoothSkin: 0.4, brighten: 0.12),
    makeup: MakeupConfig(
      lipColor: Color(0xFFC21A3B),
      lipStrength: 0.55,
      blushColor: Color(0xFFF07A7A),
      blushStrength: 0.3,
    ),
  );

  static const Effect glasses = Effect(
    id: "mask_glasses",
    name: "Shades",
    category: EffectCategory.mask,
    mask: ARMaskConfig(MaskShape.glasses, accent: Color(0xFF141414)),
  );

  static const Effect dog = Effect(
    id: "mask_dog",
    name: "Puppy",
    category: EffectCategory.mask,
    beauty: BeautyConfig(smoothSkin: 0.3, brighten: 0.1),
    mask: ARMaskConfig(MaskShape.dogEars, accent: Color(0xFF7A4B2B)),
  );

  static const Effect crown = Effect(
    id: "mask_crown",
    name: "Royal",
    category: EffectCategory.mask,
    mask: ARMaskConfig(MaskShape.crown, accent: Color(0xFFF3C33B)),
  );

  static const Effect mustache = Effect(
    id: "mask_mustache",
    name: "Mustache",
    category: EffectCategory.mask,
    mask: ARMaskConfig(MaskShape.mustache, accent: Color(0xFF2A1B10)),
  );

  static const Effect heartEyes = Effect(
    id: "mask_hearts",
    name: "In Love",
    category: EffectCategory.mask,
    mask: ARMaskConfig(MaskShape.heartEyes, accent: Color(0xFFFF3B6B)),
  );

  static final Effect vintage = Effect(
    id: "grade_vintage",
    name: "Vintage",
    category: EffectCategory.grade,
    grade: ColorGrade(
      "Vintage",
      ColorMatrix.saturation(0.75)
          .then(ColorMatrix.temperature(0.35))
          .then(ColorMatrix.contrast(0.95)),
    ),
  );

  static final Effect noir = Effect(
    id: "grade_noir",
    name: "Noir",
    category: EffectCategory.grade,
    grade: ColorGrade(
      "Noir",
      ColorMatrix.saturation(0.0).then(ColorMatrix.contrast(1.25)),
    ),
  );

  static final Effect cyber = Effect(
    id: "grade_cyber",
    name: "Cyber",
    category: EffectCategory.grade,
    grade: ColorGrade(
      "Cyber",
      ColorMatrix.tint(0.35, 0.45, 1.0, 0.35)
          .then(ColorMatrix.saturation(1.2))
          .then(ColorMatrix.contrast(1.1)),
    ),
  );

  /// All effects in display order, led by the pass-through.
  static List<Effect> get all => <Effect>[
        Effect.none,
        natural,
        glam,
        lipstick,
        glasses,
        dog,
        crown,
        mustache,
        heartEyes,
        vintage,
        noir,
        cyber,
      ];
}
