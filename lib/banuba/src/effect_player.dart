import "package:flutter/foundation.dart";
import "dart:ui" show ColorFilter;

import "color_matrix.dart";
import "effect.dart";

/// Drives the active effect and any user beauty overrides, and exposes the
/// derived render state (a single [ColorFilter], the skin-smoothing blur, the
/// makeup and mask configs) that the preview widget applies.
///
/// This is the closest analogue in the clone to Banuba's `EffectPlayer`: the
/// object an app holds, loads effects into, and reads render parameters from.
class EffectPlayer extends ChangeNotifier {
  Effect _effect = Effect.none;

  /// User-driven beauty override, layered on top of the effect's own preset.
  BeautyConfig _beautyOverride = BeautyConfig.none;

  /// When false, all effects are bypassed (before/after comparison).
  bool _enabled = true;

  Effect get effect => _effect;
  BeautyConfig get beautyOverride => _beautyOverride;
  bool get enabled => _enabled;

  /// Load an effect, replacing whatever was active. Beauty overrides persist
  /// across effect changes (like a global beauty setting).
  void loadEffect(Effect effect) {
    if (_effect.id == effect.id) return;
    _effect = effect;
    notifyListeners();
  }

  void setBeautyOverride(BeautyConfig config) {
    _beautyOverride = config;
    notifyListeners();
  }

  void setEnabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    notifyListeners();
  }

  void reset() {
    _effect = Effect.none;
    _beautyOverride = BeautyConfig.none;
    _enabled = true;
    notifyListeners();
  }

  /// Combine the effect's beauty preset with the user override. The override
  /// adds to smoothing/brightness/warmth and multiplies saturation/contrast.
  BeautyConfig get effectiveBeauty {
    if (!_enabled) return BeautyConfig.none;
    final BeautyConfig base = _effect.beauty;
    final BeautyConfig o = _beautyOverride;
    return BeautyConfig(
      smoothSkin: clampd(base.smoothSkin + o.smoothSkin, 0, 1),
      brighten: clampd(base.brighten + o.brighten, -1, 1),
      warmth: clampd(base.warmth + o.warmth, -1, 1),
      saturation: clampd(base.saturation * o.saturation, 0, 2),
      contrast: clampd(base.contrast * o.contrast, 0, 2),
    );
  }

  /// The single color filter to wrap the preview in, folding the active grade
  /// and the effective beauty tone together. Null when nothing changes color.
  ColorFilter? get colorFilter {
    if (!_enabled) return null;
    ColorMatrix m = ColorMatrix.identity();
    final ColorGrade? grade = _effect.grade;
    if (grade != null) m = m.then(grade.matrix);
    m = m.then(effectiveBeauty.toColorMatrix());
    if (m.isIdentity) return null;
    return ColorFilter.matrix(m.toFilterMatrix());
  }

  /// Blur sigma for the skin-smoothing pass, 0 when disabled.
  double get blurSigma => _enabled ? effectiveBeauty.blurSigma : 0.0;

  /// Active makeup, if any (null when disabled).
  MakeupConfig? get makeup {
    if (!_enabled) return null;
    final MakeupConfig? m = _effect.makeup;
    if (m == null || m.isEmpty) return null;
    return m;
  }

  /// Active AR mask, if any (null when disabled).
  ARMaskConfig? get mask => _enabled ? _effect.mask : null;
}
