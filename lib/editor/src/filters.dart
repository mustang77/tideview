import "dart:ui" show ColorFilter;

import "../../banuba/banuba.dart";

/// Bridges the editor's per-clip filters to the Banuba color engine, so the
/// video editor and the AR studio share one set of looks. A clip stores a
/// filter id (an [Effect.id]); this resolves it to a [ColorFilter] and lists
/// the presets the filter panel offers.
class EditorFilters {
  EditorFilters._();

  /// Filter presets available in the editor: the color grades plus the beauty
  /// tone presets from the shared catalog (mask-only effects are excluded —
  /// they need a live face).
  static List<Effect> get presets => EffectsCatalog.all
      .where((e) =>
          e.category == EffectCategory.grade ||
          e.category == EffectCategory.beauty)
      .toList();

  static Effect? _byId(String? id) {
    if (id == null) return null;
    for (final Effect e in EffectsCatalog.all) {
      if (e.id == id) return e;
    }
    return null;
  }

  static String labelFor(String? id) => _byId(id)?.name ?? "None";

  /// The [ColorFilter] for a clip's filter id, or null for no color change.
  static ColorFilter? colorFilterFor(String? id) {
    final Effect? e = _byId(id);
    if (e == null) return null;
    ColorMatrix m = ColorMatrix.identity();
    if (e.grade != null) m = m.then(e.grade!.matrix);
    if (!e.beauty.isNeutral) m = m.then(e.beauty.toColorMatrix());
    if (m.isIdentity) return null;
    return ColorFilter.matrix(m.toFilterMatrix());
  }
}
