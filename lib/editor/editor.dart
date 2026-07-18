/// TideView video editor — a CapCut-style, multi-track, in-app editor built on
/// Flutter. Provides a timeline data model, an editing engine with undo/redo,
/// project save/load, a render-plan/export seam, and an editor UI. Clip filters
/// reuse the Banuba color engine so the editor and AR studio share one look.
library editor;

export "src/model.dart";
export "src/edit_controller.dart";
export "src/project_codec.dart";
export "src/demo_project.dart";
export "src/filters.dart";
export "ui/editor_screen.dart";
