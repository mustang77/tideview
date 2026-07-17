# tideview

A Flutter app. Alongside the video features it ships **Banuba-clone**, a compact
Face AR / beauty-filter SDK built from scratch on Flutter's own rendering
primitives — no native AR engine required.

## Banuba-clone: Face AR SDK

A from-scratch clone of the shape of Banuba's Face AR SDK. It gives you the same
building blocks — an effect player you load effects into, a pluggable face
tracker, composable beauty/makeup/mask/grade effects, and a real-time renderer —
implemented entirely with GPU color filters and `CustomPaint`.

Try it: run the app and open the **AR Studio** tab.

### What's included

| Piece | File | Role |
| --- | --- | --- |
| `EffectPlayer` | `lib/banuba/src/effect_player.dart` | Holds the active effect + beauty overrides; derives the render state (one folded `ColorFilter`, blur sigma, mask/makeup). |
| `Effect` + configs | `lib/banuba/src/effect.dart` | Composable `BeautyConfig` / `MakeupConfig` / `ARMaskConfig` / `ColorGrade`. |
| `EffectsCatalog` | `lib/banuba/src/effects_catalog.dart` | Ready-made pack: Natural, Glam, Ruby Lips, Shades, Puppy, Royal, Mustache, In Love, Vintage, Noir, Cyber. |
| `FaceTracker` / `MockFaceTracker` | `lib/banuba/src/face_tracker.dart` | The pluggable face source. Swap in ML Kit / MediaPipe / a real NN. |
| `Face` | `lib/banuba/src/face.dart` | Normalized landmark model effects render against. |
| `FaceOverlayPainter` | `lib/banuba/src/ar_renderer.dart` | Draws AR masks + virtual makeup, anchored and scaled to landmarks. |
| `ColorMatrix` | `lib/banuba/src/color_matrix.dart` | Composable 4x5 color transforms (brightness, contrast, saturation, temperature, tint). |
| `ARStudioScreen` | `lib/banuba/ui/ar_studio_screen.dart` | Live-camera demo studio with effect carousel, beauty sliders, capture, before/after. |

### Quick start

```dart
import 'package:tideview/banuba/banuba.dart';

final player = EffectPlayer();
player.loadEffect(EffectsCatalog.glam);        // beauty preset
player.setBeautyOverride(const BeautyConfig(smoothSkin: 0.3)); // global override

// In your preview widget:
//  - wrap the frame in player.colorFilter (folded grade + tone)
//  - blur it by player.blurSigma (skin smoothing)
//  - paint FaceOverlayPainter(faces, mask: player.mask, makeup: player.makeup)
```

The face tracker is an interface: `MockFaceTracker` keeps the whole pipeline
runnable and unit-tested without camera hardware, and a production build plugs a
real detector into the same `FaceTracker` contract.

Tests for the pure logic (color math, landmark geometry, effect state) live in
`test/banuba_test.dart`.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
