/// A compact face-AR / beauty-filter SDK for Flutter — a from-scratch clone of
/// the shape of Banuba's Face AR SDK, built entirely on Flutter's own
/// rendering primitives (color matrices, fragment-free CustomPaint overlays and
/// GPU color filters).
///
/// Public surface:
///  - [EffectPlayer]      the object an app loads effects into and reads render
///                        state from.
///  - [Effect] and the [BeautyConfig] / [MakeupConfig] / [ARMaskConfig] /
///    [ColorGrade] configs that compose one.
///  - [EffectsCatalog]    a ready-made pack of beauty, makeup, mask and grade
///                        effects.
///  - [FaceTracker] / [MockFaceTracker] the pluggable face source.
///  - [Face]              the normalized landmark model effects render against.
///  - [FaceOverlayPainter] the AR mask + makeup renderer.
///  - [ColorMatrix]       composable 4x5 color transforms.
library banuba;

export "src/color_matrix.dart";
export "src/effect.dart";
export "src/effect_player.dart";
export "src/effects_catalog.dart";
export "src/face.dart";
export "src/face_tracker.dart";
export "src/ar_renderer.dart";
