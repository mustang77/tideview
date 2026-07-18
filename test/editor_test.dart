import "package:flutter_test/flutter_test.dart";
import "package:tideview/editor/editor.dart";

Project _demo() => DemoProject.build();

void main() {
  group("Clip timing", () {
    test("duration and end honor trim", () {
      const Clip c = Clip(
        id: "x",
        type: ClipType.video,
        sourceInMs: 1000,
        sourceOutMs: 4000,
        startMs: 2000,
      );
      expect(c.rawDurationMs, 3000);
      expect(c.durationMs, 3000);
      expect(c.endMs, 5000);
    });

    test("speed compresses timeline duration", () {
      const Clip c = Clip(
        id: "x",
        type: ClipType.video,
        sourceInMs: 0,
        sourceOutMs: 4000,
        startMs: 0,
        speed: 2.0,
      );
      expect(c.durationMs, 2000);
      expect(c.endMs, 2000);
    });

    test("sourceTimeAt maps timeline to source with speed", () {
      const Clip c = Clip(
        id: "x",
        type: ClipType.video,
        sourceInMs: 8000,
        sourceOutMs: 12000,
        startMs: 5000,
        speed: 2.0,
      );
      // 1000ms into the clip on the timeline == 2000ms into the source.
      expect(c.sourceTimeAt(6000), 10000);
    });

    test("coversTimeline is half-open [start, end)", () {
      const Clip c = Clip(
        id: "x",
        type: ClipType.video,
        sourceInMs: 0,
        sourceOutMs: 1000,
        startMs: 500,
      );
      expect(c.coversTimeline(500), isTrue);
      expect(c.coversTimeline(1499), isTrue);
      expect(c.coversTimeline(1500), isFalse);
    });
  });

  group("Track & Project", () {
    test("track duration is furthest clip end", () {
      final Project p = _demo();
      expect(p.trackById("v1")!.durationMs, 9000);
    });

    test("project duration is max across tracks", () {
      expect(_demo().durationMs, 9000);
    });

    test("locate finds the clip and its track", () {
      final Project p = _demo();
      final loc = p.locate("c3");
      expect(loc, isNotNull);
      expect(loc!.track.id, "t1");
      expect(loc.clip.type, ClipType.text);
    });

    test("clipAt returns the covering clip", () {
      final Project p = _demo();
      expect(p.trackById("v1")!.clipAt(6000)!.id, "c2");
      expect(p.trackById("v1")!.clipAt(20000), isNull);
    });
  });

  group("EditController editing", () {
    test("split cuts a clip into two at the playhead", () {
      final EditController c = EditController(_demo());
      c.splitAt("c1", 2000);
      final Clip left = c.project.locate("c1")!.clip;
      expect(left.endMs, 2000);
      expect(left.sourceOutMs, 2000);
      final Clip? right = c.videoClipAt(3000);
      expect(right, isNotNull);
      expect(right!.id, isNot("c1"));
      expect(right.sourceInMs, 2000);
    });

    test("split is a no-op outside the clip", () {
      final EditController c = EditController(_demo());
      final int before = c.project.trackById("v1")!.clips.length;
      c.splitAt("c1", 9999);
      expect(c.project.trackById("v1")!.clips.length, before);
    });

    test("trimEnd shortens via source-out", () {
      final EditController c = EditController(_demo());
      c.trimEnd("c1", 3000);
      expect(c.project.locate("c1")!.clip.endMs, 3000);
    });

    test("trimStart shifts start and source-in together", () {
      final EditController c = EditController(_demo());
      c.trimStart("c1", 1000);
      final Clip c1 = c.project.locate("c1")!.clip;
      expect(c1.startMs, 1000);
      expect(c1.sourceInMs, 1000);
      expect(c1.endMs, 5000);
    });

    test("move repositions a clip", () {
      final EditController c = EditController(_demo());
      c.moveClip("c3", 4000);
      expect(c.project.locate("c3")!.clip.startMs, 4000);
    });

    test("remove deletes the clip and clears selection", () {
      final EditController c = EditController(_demo());
      c.select("c3");
      c.removeClip("c3");
      expect(c.project.locate("c3"), isNull);
      expect(c.selectedClipId, isNull);
    });

    test("duplicate appends a copy after the original", () {
      final EditController c = EditController(_demo());
      c.duplicateClip("c1");
      final copy = c.selectedClip!;
      expect(copy.id, isNot("c1"));
      expect(copy.startMs, 5000); // right after c1's end
    });

    test("setSpeed changes timeline duration", () {
      final EditController c = EditController(_demo());
      c.setSpeed("c1", 2.0);
      expect(c.project.locate("c1")!.clip.durationMs, 2500);
    });

    test("setFilter and clear", () {
      final EditController c = EditController(_demo());
      c.setFilter("c1", "grade_noir");
      expect(c.project.locate("c1")!.clip.filterId, "grade_noir");
      c.setFilter("c1", null);
      expect(c.project.locate("c1")!.clip.filterId, isNull);
    });

    test("addTextAtPlayhead inserts a selected text clip", () {
      final EditController c = EditController(_demo());
      c.seek(1000);
      final String id = c.addTextAtPlayhead("Hello");
      final Clip clip = c.project.locate(id)!.clip;
      expect(clip.type, ClipType.text);
      expect(clip.startMs, 1000);
      expect(clip.text!.text, "Hello");
      expect(c.selectedClipId, id);
    });

    test("seek clamps to the timeline bounds", () {
      final EditController c = EditController(_demo());
      c.seek(999999);
      expect(c.playheadMs, 9000);
      c.seek(-100);
      expect(c.playheadMs, 0);
    });
  });

  group("Undo / redo", () {
    test("undo restores the previous project state", () {
      final EditController c = EditController(_demo());
      expect(c.canUndo, isFalse);
      c.removeClip("c3");
      expect(c.project.locate("c3"), isNull);
      expect(c.canUndo, isTrue);
      c.undo();
      expect(c.project.locate("c3"), isNotNull);
      expect(c.canRedo, isTrue);
      c.redo();
      expect(c.project.locate("c3"), isNull);
    });

    test("a new edit clears the redo stack", () {
      final EditController c = EditController(_demo());
      c.removeClip("c3");
      c.undo();
      expect(c.canRedo, isTrue);
      c.setSpeed("c1", 1.5);
      expect(c.canRedo, isFalse);
    });

    test("live drag is a single undo step", () {
      final EditController c = EditController(_demo());
      c.beginInteraction();
      c.moveClipLive("c3", 1000);
      c.moveClipLive("c3", 2000);
      c.moveClipLive("c3", 3000);
      expect(c.project.locate("c3")!.clip.startMs, 3000);
      c.undo();
      expect(c.project.locate("c3")!.clip.startMs, 500); // original
    });
  });

  group("Media import", () {
    test("importClip appends to the video track at the end", () {
      final EditController c = EditController(_demo());
      final Clip imported = c.importClip(
        type: ClipType.image,
        path: "/photos/pic.jpg",
        durationMs: 3000,
      );
      expect(imported.id, isNotEmpty);
      expect(imported.type, ClipType.image);
      expect(imported.startMs, 9000); // after c2's end
      expect(imported.endMs, 12000);
      expect(c.durationMs, 12000);
      expect(c.selectedClipId, imported.id);
    });

    test("ensureVideoTrack reuses an existing video track", () {
      final EditController c = EditController(_demo());
      expect(c.ensureVideoTrack(), "v1");
    });

    test("ensureVideoTrack creates one when absent", () {
      final EditController c = EditController(const Project(
        id: "p",
        name: "empty",
        tracks: <Track>[],
      ));
      final String id = c.ensureVideoTrack();
      expect(c.project.trackById(id), isNotNull);
      expect(c.project.trackById(id)!.type, TrackType.video);
    });
  });

  group("Compositing queries", () {
    test("videoClipAt picks the video-track clip", () {
      final EditController c = EditController(_demo());
      expect(c.videoClipAt(1000)!.id, "c1");
      expect(c.videoClipAt(6000)!.id, "c2");
    });

    test("visualStackAt returns overlapping visual clips", () {
      final EditController c = EditController(_demo());
      final List<Clip> stack = c.visualStackAt(1000);
      expect(stack.map((e) => e.id), containsAll(<String>["c1", "c3"]));
    });
  });

  group("Serialization & export", () {
    test("project round-trips through JSON", () {
      final Project p = _demo();
      final String json = ProjectCodec.encode(p);
      final Project back = ProjectCodec.decode(json);
      expect(back.durationMs, p.durationMs);
      expect(back.allClips.length, p.allClips.length);
      expect(back.locate("c3")!.clip.text!.text, "TideView");
    });

    test("render plan flattens every clip in order", () {
      final RenderPlan plan = RenderPlan.fromProject(_demo());
      expect(plan.ops.length, 3);
      expect(plan.width, 1080);
      expect(plan.toEdl(), contains("operations"));
    });

    test("plan-only exporter returns the output path", () async {
      final RenderPlan plan = RenderPlan.fromProject(_demo());
      const VideoExporter exporter = PlanOnlyExporter();
      final String out =
          await exporter.export(plan, outputPath: "/tmp/out.mp4");
      expect(out, "/tmp/out.mp4");
    });
  });

  group("Filters bridge", () {
    test("known grade resolves to a color filter", () {
      expect(EditorFilters.colorFilterFor("grade_noir"), isNotNull);
      expect(EditorFilters.colorFilterFor(null), isNull);
    });

    test("presets exclude mask-only effects", () {
      final ids = EditorFilters.presets.map((e) => e.id).toList();
      expect(ids, isNot(contains("mask_glasses")));
      expect(ids, contains("grade_noir"));
    });
  });
}
