import "model.dart";

/// A ready-made sample project so the editor opens with something to edit
/// without needing a media importer. Uses a public sample video so preview
/// playback works out of the box.
class DemoProject {
  DemoProject._();

  /// Creative Commons sample clip (Google's public test asset).
  static const String sampleVideo =
      "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4";

  static Project build() {
    return Project(
      id: "demo",
      name: "My First Edit",
      width: 1080,
      height: 1920,
      fps: 30,
      tracks: <Track>[
        Track(
          id: "v1",
          type: TrackType.video,
          name: "Video",
          clips: <Clip>[
            const Clip(
              id: "c1",
              type: ClipType.video,
              sourcePath: sampleVideo,
              sourceInMs: 0,
              sourceOutMs: 5000,
              startMs: 0,
              transitionOut: TransitionType.fade,
            ),
            const Clip(
              id: "c2",
              type: ClipType.video,
              sourcePath: sampleVideo,
              sourceInMs: 8000,
              sourceOutMs: 12000,
              startMs: 5000,
              filterId: "grade_vintage",
            ),
          ],
        ),
        Track(
          id: "t1",
          type: TrackType.text,
          name: "Text",
          clips: <Clip>[
            const Clip(
              id: "c3",
              type: ClipType.text,
              sourceInMs: 0,
              sourceOutMs: 2500,
              startMs: 500,
              text: TextStyleSpec(
                text: "TideView",
                fontSize: 64,
                colorValue: 0xFFFFFFFF,
                backgroundValue: 0x99000000,
              ),
              transform: Transform2D(x: 0.5, y: 0.2),
              transitionIn: TransitionType.fade,
            ),
          ],
        ),
      ],
    );
  }
}
