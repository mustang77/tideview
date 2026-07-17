import "dart:math" as math;

/// A 4x5 color matrix compatible with Flutter's [ColorFilter.matrix].
///
/// The 20 values are stored row-major and transform a pixel vector
/// `[R, G, B, A, 1]` into a new `[R', G', B', A']`. Matrices can be composed
/// with [then] so a whole beauty/grade pipeline collapses into a single
/// GPU color filter — the same approach Banuba's render graph uses to fold
/// tone adjustments into one pass.
class ColorMatrix {
  /// Row-major 4x5 values (length 20).
  final List<double> storage;

  const ColorMatrix._(this.storage);

  factory ColorMatrix.fromList(List<double> values) {
    assert(values.length == 20, "A color matrix needs exactly 20 values");
    return ColorMatrix._(List<double>.from(values));
  }

  /// The identity transform (no color change).
  factory ColorMatrix.identity() => ColorMatrix._(<double>[
        1, 0, 0, 0, 0, //
        0, 1, 0, 0, 0, //
        0, 0, 1, 0, 0, //
        0, 0, 0, 1, 0, //
      ]);

  /// Additive brightness. [amount] is expressed in 0..255 space; positive
  /// lifts, negative darkens.
  factory ColorMatrix.brightness(double amount) => ColorMatrix._(<double>[
        1, 0, 0, 0, amount, //
        0, 1, 0, 0, amount, //
        0, 0, 1, 0, amount, //
        0, 0, 0, 1, 0, //
      ]);

  /// Contrast around the mid-grey point. 1.0 is neutral, >1 increases.
  factory ColorMatrix.contrast(double c) {
    final double t = (1.0 - c) * 127.5;
    return ColorMatrix._(<double>[
      c, 0, 0, 0, t, //
      0, c, 0, 0, t, //
      0, 0, c, 0, t, //
      0, 0, 0, 1, 0, //
    ]);
  }

  /// Saturation. 0 is greyscale, 1 is neutral, >1 boosts vividness.
  /// Uses Rec. 601 luma weights.
  factory ColorMatrix.saturation(double s) {
    const double lr = 0.3086, lg = 0.6094, lb = 0.0820;
    final double sr = (1 - s) * lr;
    final double sg = (1 - s) * lg;
    final double sb = (1 - s) * lb;
    return ColorMatrix._(<double>[
      sr + s, sg, sb, 0, 0, //
      sr, sg + s, sb, 0, 0, //
      sr, sg, sb + s, 0, 0, //
      0, 0, 0, 1, 0, //
    ]);
  }

  /// Colour temperature. Positive [amount] warms (more red, less blue),
  /// negative cools. [amount] is roughly -1..1.
  factory ColorMatrix.temperature(double amount) {
    final double shift = amount * 30.0;
    return ColorMatrix._(<double>[
      1, 0, 0, 0, shift, //
      0, 1, 0, 0, shift * 0.2, //
      0, 0, 1, 0, -shift, //
      0, 0, 0, 1, 0, //
    ]);
  }

  /// Tint the image toward [r],[g],[b] (each 0..1) by [strength] (0..1).
  /// Used for LUT-style colour grades.
  factory ColorMatrix.tint(double r, double g, double b, double strength) {
    final double k = 1 - strength;
    return ColorMatrix._(<double>[
      k + strength * r * 2 * 0.5, 0, 0, 0, strength * r * 40, //
      0, k + strength * g * 2 * 0.5, 0, 0, strength * g * 40, //
      0, 0, k + strength * b * 2 * 0.5, 0, strength * b * 40, //
      0, 0, 0, 1, 0, //
    ]);
  }

  /// Compose this matrix with [next] so that [next] is applied to the result
  /// of `this` (i.e. `next ∘ this`). Returns a new matrix.
  ColorMatrix then(ColorMatrix next) {
    final List<double> a = next.storage; // applied second
    final List<double> b = storage; // applied first
    final List<double> out = List<double>.filled(20, 0);
    // Treat each as a 5x5 with an implicit last row [0,0,0,0,1].
    for (int row = 0; row < 4; row++) {
      for (int col = 0; col < 5; col++) {
        double sum = 0;
        for (int k = 0; k < 4; k++) {
          sum += a[row * 5 + k] * b[k * 5 + col];
        }
        // Contribution of the implicit 5th row of `b` (only the constant col).
        if (col == 4) sum += a[row * 5 + 4];
        out[row * 5 + col] = sum;
      }
    }
    return ColorMatrix._(out);
  }

  /// Blend from identity (t=0) toward this matrix (t=1).
  ColorMatrix scaledFromIdentity(double t) {
    final double clamped = t.clamp(0.0, 1.0);
    final List<double> id = ColorMatrix.identity().storage;
    final List<double> out = List<double>.filled(20, 0);
    for (int i = 0; i < 20; i++) {
      out[i] = id[i] + (storage[i] - id[i]) * clamped;
    }
    return ColorMatrix._(out);
  }

  /// Apply this matrix to a single opaque RGB pixel (each channel 0..255).
  /// Exposed mostly for testing the maths without a GPU.
  List<double> applyToRgb(double r, double g, double b) {
    double ch(int row) =>
        storage[row * 5 + 0] * r +
        storage[row * 5 + 1] * g +
        storage[row * 5 + 2] * b +
        storage[row * 5 + 3] * 255 +
        storage[row * 5 + 4];
    return <double>[
      ch(0).clamp(0.0, 255.0),
      ch(1).clamp(0.0, 255.0),
      ch(2).clamp(0.0, 255.0),
    ];
  }

  List<double> toFilterMatrix() => List<double>.from(storage);

  bool get isIdentity {
    final List<double> id = ColorMatrix.identity().storage;
    for (int i = 0; i < 20; i++) {
      if ((storage[i] - id[i]).abs() > 1e-6) return false;
    }
    return true;
  }
}

/// Clamp helper shared across the pipeline.
double clampd(double v, double lo, double hi) => math.max(lo, math.min(hi, v));
