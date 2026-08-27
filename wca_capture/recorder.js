// recorder.js — screen recording via getDisplayMedia + MediaRecorder.
// Runs in its own extension tab. Nothing is uploaded anywhere: the recording
// stays in memory and is saved to a local .webm file.

const startBtn = document.getElementById("start");
const stopBtn = document.getElementById("stop");
const micBox = document.getElementById("mic");
const statusEl = document.getElementById("status");
const preview = document.getElementById("preview");
const dl = document.getElementById("dl");
const timerEl = document.getElementById("timer");

let recorder = null;
let chunks = [];
let streams = [];
let timerId = null;

function fmt(s) {
  return `${String(Math.floor(s / 60)).padStart(2, "0")}:${String(s % 60).padStart(2, "0")}`;
}

startBtn.addEventListener("click", async () => {
  chunks = [];
  streams = [];
  dl.style.display = "none";
  preview.style.display = "none";

  let display;
  try {
    display = await navigator.mediaDevices.getDisplayMedia({
      video: { frameRate: 30 },
      audio: true, // system/tab audio if the user enables "share audio"
    });
  } catch {
    statusEl.textContent = "Recording cancelled.";
    return;
  }
  streams.push(display);

  // Merge display audio + microphone into one track using WebAudio.
  const audioCtx = new AudioContext();
  const dest = audioCtx.createMediaStreamDestination();
  let hasAudio = false;

  if (display.getAudioTracks().length) {
    audioCtx.createMediaStreamSource(display).connect(dest);
    hasAudio = true;
  }
  if (micBox.checked) {
    try {
      const mic = await navigator.mediaDevices.getUserMedia({ audio: true });
      streams.push(mic);
      audioCtx.createMediaStreamSource(mic).connect(dest);
      hasAudio = true;
    } catch {
      statusEl.textContent = "⚠️ Microphone blocked — recording without it.";
    }
  }

  const tracks = [...display.getVideoTracks(), ...(hasAudio ? dest.stream.getAudioTracks() : [])];
  const combined = new MediaStream(tracks);

  const mime = MediaRecorder.isTypeSupported("video/webm;codecs=vp9")
    ? "video/webm;codecs=vp9"
    : "video/webm";
  recorder = new MediaRecorder(combined, { mimeType: mime });
  recorder.ondataavailable = (e) => e.data.size && chunks.push(e.data);
  recorder.onstop = finish;
  recorder.start(1000);

  // Stop automatically if the user ends sharing from Chrome's own bar.
  display.getVideoTracks()[0].addEventListener("ended", stop);

  startBtn.style.display = "none";
  stopBtn.style.display = "inline-block";
  statusEl.textContent = "Recording… choose this tab to see yourself go in circles 🙂";

  let seconds = 0;
  timerEl.textContent = fmt(0);
  timerId = setInterval(() => (timerEl.textContent = fmt(++seconds)), 1000);
});

function stop() {
  if (recorder && recorder.state !== "inactive") recorder.stop();
}
stopBtn.addEventListener("click", stop);

function finish() {
  clearInterval(timerId);
  streams.forEach((s) => s.getTracks().forEach((t) => t.stop()));
  startBtn.style.display = "inline-block";
  stopBtn.style.display = "none";

  const blob = new Blob(chunks, { type: "video/webm" });
  const url = URL.createObjectURL(blob);

  preview.src = url;
  preview.style.display = "block";
  dl.href = url;
  dl.download = `WCA-recording-${new Date().toISOString().replace(/[:.]/g, "-")}.webm`;
  dl.style.display = "inline-block";
  statusEl.textContent = `Done — ${(blob.size / 1048576).toFixed(1)} MB. Preview below, then save.`;
}
