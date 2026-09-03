// JARVIS self-check harness: starts the server on a spare port and tests every feature it can
// reach without a browser. Run with:  npm run check
import { spawn } from "node:child_process";
import path from "node:path";
import fs from "node:fs";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const PORT = 3900 + Math.floor(Math.random() * 100);
const BASE = `http://localhost:${PORT}`;
const results = [];
const record = (name, status, detail = "") => { results.push({ name, status, detail }); console.log(`${status.padEnd(5)} ${name}${detail ? "  - " + detail : ""}`); };

async function test(name, fn) {
  try { const detail = await fn(); record(name, detail === "SKIP" ? "SKIP" : "PASS", detail === "SKIP" ? "" : detail || ""); }
  catch (err) { record(name, "FAIL", err.message); }
}

const child = spawn(process.execPath, [path.join(here, "server.mjs")], { env: { ...process.env, PORT: String(PORT) }, stdio: ["ignore", "pipe", "pipe"] });
let log = ""; child.stdout.on("data", d => log += d); child.stderr.on("data", d => log += d);

async function waitForServer() {
  for (let i = 0; i < 40; i++) {
    try { const r = await fetch(BASE + "/api/health"); if (r.ok) return r.json(); } catch {}
    await new Promise(r => setTimeout(r, 150));
  }
  throw new Error("server did not start:\n" + log);
}

let health;
await test("server starts", async () => { health = await waitForServer(); return `model ${health.model}, effort ${health.effort}`; });

await test("notes are indexed", async () => {
  const r = await (await fetch(BASE + "/api/notes")).json();
  if (!r.notes.length) throw new Error(`no notes found in ${health.notesDir}`);
  const bad = r.notes.find(n => !n.title || !n.id);
  if (bad) throw new Error("a note is missing a title or id");
  return `${r.notes.length} notes, ${r.links.length} links`;
});

await test("galaxy has links", async () => {
  const r = await (await fetch(BASE + "/api/notes")).json();
  if (r.notes.length > 1 && !r.links.length) throw new Error("no links between notes: add [[wikilinks]] or #tags");
  const ids = new Set(r.notes.map(n => n.id));
  const dangling = r.links.find(l => !ids.has(l.source) || !ids.has(l.target));
  if (dangling) throw new Error("a link points at a missing note");
  return "";
});

await test("search finds the right note", async () => {
  const notes = (await (await fetch(BASE + "/api/notes")).json()).notes;
  const probe = notes[0];
  const words = probe.title.split(/\s+/).filter(w => w.length > 3).slice(0, 3).join(" ") || probe.title;
  const r = await (await fetch(BASE + "/api/search?q=" + encodeURIComponent(words))).json();
  if (!r.results.length) throw new Error(`no results for "${words}"`);
  if (!r.results.slice(0, 2).some(x => x.id === probe.id)) throw new Error(`"${words}" did not rank "${probe.title}" in the top 2`);
  return `"${words}" -> ${r.results[0].title}`;
});

await test("note bodies are served", async () => {
  const notes = (await (await fetch(BASE + "/api/notes")).json()).notes;
  const r = await (await fetch(BASE + "/api/note?id=" + encodeURIComponent(notes[0].id))).json();
  if (!r.raw || r.raw.length < 10) throw new Error("empty note body");
  return "";
});

await test("web app is served", async () => {
  const html = await (await fetch(BASE + "/")).text();
  for (const id of ["galaxy", "transcript", "askForm", "micBtn", "eyesBtn", "voiceBtn"]) if (!html.includes(`id="${id}"`)) throw new Error(`missing element #${id}`);
  if (!html.includes("three.js") && !html.includes("three.min.js")) throw new Error("three.js not referenced");
  return "";
});

async function ask(question, extra = {}) {
  const r = await fetch(BASE + "/api/ask", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ question, history: [], ...extra }) });
  const text = await r.text();
  const events = text.split("\n\n").filter(Boolean).map(l => JSON.parse(l.replace(/^data: /, "")));
  const answer = events.filter(e => e.type === "text").map(e => e.text).join("");
  const done = events.find(e => e.type === "done"); const error = events.find(e => e.type === "error");
  return { events, answer, done, error };
}

await test("ask streams an answer with sources", async () => {
  const notes = (await (await fetch(BASE + "/api/notes")).json()).notes;
  const r = await ask(`What do my notes say about ${notes[0].title}?`);
  if (r.error) throw new Error(r.error.message);
  if (!r.answer.trim()) throw new Error("empty answer");
  if (!r.done) throw new Error("stream never finished");
  if (!r.done.sources || !r.done.sources.length) throw new Error("no sources returned");
  return `${r.done.demo ? "demo mode" : r.done.model}, ${r.answer.split(/\s+/).length} words, ${r.done.sources.length} sources`;
});

await test("ask cites a note", async () => {
  const notes = (await (await fetch(BASE + "/api/notes")).json()).notes;
  const r = await ask(`Quote one sentence from my note titled "${notes[0].title}" and tell me which note it is from.`);
  if (r.error) throw new Error(r.error.message);
  const cited = r.events.filter(e => e.type === "citation");
  if (!cited.length) throw new Error("no citation events (the model answered without citing the notes)");
  return `${cited.length} citation(s)`;
});

await test("eyes: image is accepted", async () => {
  if (!health.hasKey) return "SKIP";
  // 1x1 red pixel PNG
  const png = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==";
  const r = await ask("What colour is the attached image? Answer with one word.", { image: "data:image/png;base64," + png });
  if (r.error) throw new Error(r.error.message);
  if (!/red|pink|crimson/i.test(r.answer)) throw new Error(`expected red, got: ${r.answer.slice(0, 80)}`);
  return r.answer.trim().slice(0, 40);
});

await test("bad request is rejected cleanly", async () => {
  const r = await fetch(BASE + "/api/ask", { method: "POST", headers: { "Content-Type": "application/json" }, body: "{}" });
  if (r.status !== 400) throw new Error(`expected 400, got ${r.status}`);
  return "";
});

child.kill();
const fails = results.filter(r => r.status === "FAIL").length, skips = results.filter(r => r.status === "SKIP").length;
console.log(`\n${results.length - fails - skips} passed, ${fails} failed, ${skips} skipped${health && !health.hasKey ? "   (no API key: Claude calls ran in demo mode)" : ""}`);
process.exit(fails ? 1 : 0);
