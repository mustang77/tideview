// WCA PDF Tools — all processing happens in the browser.
// Libraries: pdf-lib (edit/merge/split), pdf.js (render/extract), JSZip.

pdfjsLib.GlobalWorkerOptions.workerSrc = "vendor/pdf.worker.min.js";

const $ = (s) => document.querySelector(s);

/* ================= i18n ================= */
const STR = {
en: {
  heroTitle: "Every PDF tool you need. Free.",
  heroSub: "Merge, split, compress, convert and edit PDF — right in your browser.",
  privacyBadge: "🔒 100% private: your files are processed on YOUR device and never uploaded anywhere.",
  back: "All tools",
  dropTitle: "Choose a file or drop it here",
  dropSub: "Nothing is uploaded — everything stays on your device.",
  process: "Process",
  working: "Working…",
  done: "Done! Your download is ready:",
  err: "Something went wrong with this file. Is it a valid, unprotected PDF?",
  needTwo: "Add at least 2 PDF files to merge.",
  badRange: "Enter a page range like: 1-3, 5",
  splitRange: "Pages to extract (e.g. 1-3, 5)",
  splitZip: "Instead: split EVERY page into separate PDFs (ZIP)",
  cmpQuality: "Image quality",
  cmpNote: "Compression rebuilds pages as optimized images — great for scanned documents; selectable text becomes an image.",
  rotAngle: "Rotate all pages by",
  wmText: "Watermark text",
  wmOpacity: "Opacity",
  pnStart: "First page number",
  pages: "pages",
  smaller: "smaller",
  bigger: "larger — original kept",
  tools: {
    merge:    ["Merge PDF", "Combine multiple PDFs into one, in the order you choose."],
    split:    ["Split PDF", "Extract pages or break a PDF into separate files."],
    compress: ["Compress PDF", "Shrink scanned PDFs by rebuilding pages as optimized images."],
    rotate:   ["Rotate PDF", "Rotate every page by 90°, 180° or 270°."],
    watermark:["Watermark", "Stamp a diagonal text watermark on every page."],
    pagenum:  ["Page numbers", "Add page numbers at the bottom of every page."],
    jpg2pdf:  ["JPG to PDF", "Turn images (JPG/PNG) into a single PDF."],
    pdf2jpg:  ["PDF to JPG", "Export every page as a JPG image (ZIP)."],
    extract:  ["Extract text", "Pull all selectable text out of a PDF into a .txt file."],
  },
  footerNote: "Free PDF tools by World Cruise Academy. Files are processed locally in your browser and are never uploaded.",
},
id: {
  heroTitle: "Semua alat PDF yang kamu butuhkan. Gratis.",
  heroSub: "Gabungkan, pisahkan, kompres, konversi dan edit PDF — langsung di browser.",
  privacyBadge: "🔒 100% privat: file diproses di perangkatMU dan tidak pernah diunggah ke mana pun.",
  back: "Semua alat",
  dropTitle: "Pilih file atau jatuhkan di sini",
  dropSub: "Tidak ada yang diunggah — semuanya tetap di perangkatmu.",
  process: "Proses",
  working: "Memproses…",
  done: "Selesai! Unduhanmu siap:",
  err: "Ada masalah dengan file ini. Apakah PDF-nya valid dan tidak terkunci?",
  needTwo: "Tambahkan minimal 2 file PDF untuk digabung.",
  badRange: "Masukkan rentang halaman seperti: 1-3, 5",
  splitRange: "Halaman yang diambil (mis. 1-3, 5)",
  splitZip: "Atau: pisahkan SETIAP halaman jadi PDF terpisah (ZIP)",
  cmpQuality: "Kualitas gambar",
  cmpNote: "Kompresi membangun ulang halaman sebagai gambar teroptimasi — cocok untuk dokumen hasil scan; teks tidak bisa diseleksi lagi.",
  rotAngle: "Putar semua halaman",
  wmText: "Teks watermark",
  wmOpacity: "Transparansi",
  pnStart: "Nomor halaman pertama",
  pages: "halaman",
  smaller: "lebih kecil",
  bigger: "lebih besar — asli dipertahankan",
  tools: {
    merge:    ["Gabungkan PDF", "Satukan beberapa PDF menjadi satu, dengan urutan pilihanmu."],
    split:    ["Pisahkan PDF", "Ambil halaman tertentu atau pecah PDF jadi file terpisah."],
    compress: ["Kompres PDF", "Kecilkan PDF hasil scan dengan membangun ulang halaman sebagai gambar."],
    rotate:   ["Putar PDF", "Putar semua halaman 90°, 180°, atau 270°."],
    watermark:["Watermark", "Beri cap teks diagonal di setiap halaman."],
    pagenum:  ["Nomor halaman", "Tambahkan nomor di bagian bawah setiap halaman."],
    jpg2pdf:  ["JPG ke PDF", "Ubah gambar (JPG/PNG) menjadi satu PDF."],
    pdf2jpg:  ["PDF ke JPG", "Ekspor setiap halaman sebagai gambar JPG (ZIP)."],
    extract:  ["Ekstrak teks", "Ambil semua teks dari PDF ke file .txt."],
  },
  footerNote: "Alat PDF gratis dari World Cruise Academy. File diproses secara lokal di browser dan tidak pernah diunggah.",
},
};

const store = {
  get(k, f) { try { return JSON.parse(localStorage.getItem(k)) ?? f; } catch { return f; } },
  set(k, v) { try { localStorage.setItem(k, JSON.stringify(v)); } catch {} },
};

let lang = store.get("wcapdf_lang", null) || (navigator.language?.startsWith("id") ? "id" : "en");
if (!STR[lang]) lang = "en";
const T = () => STR[lang];

const TOOL_META = {
  merge:    { ico: "🧩", cls: "c1", multi: true,  accept: "application/pdf" },
  split:    { ico: "✂️", cls: "c2", multi: false, accept: "application/pdf" },
  compress: { ico: "🗜️", cls: "c3", multi: false, accept: "application/pdf" },
  rotate:   { ico: "🔄", cls: "c4", multi: false, accept: "application/pdf" },
  watermark:{ ico: "💧", cls: "c5", multi: false, accept: "application/pdf" },
  pagenum:  { ico: "🔢", cls: "c6", multi: false, accept: "application/pdf" },
  jpg2pdf:  { ico: "🖼️", cls: "c7", multi: true,  accept: "image/jpeg,image/png" },
  pdf2jpg:  { ico: "📸", cls: "c8", multi: false, accept: "application/pdf" },
  extract:  { ico: "📝", cls: "c9", multi: false, accept: "application/pdf" },
};

let currentTool = null;
let files = [];

/* ================= UI: language + grid ================= */
function applyLang() {
  document.documentElement.lang = lang;
  $("#lang-select").value = lang;
  document.querySelectorAll("[data-i18n]").forEach((el) => {
    const v = T()[el.dataset.i18n];
    if (v) el.textContent = v;
  });
  renderGrid();
  if (currentTool) openTool(currentTool, true);
}

$("#lang-select").addEventListener("change", (e) => {
  lang = e.target.value;
  store.set("wcapdf_lang", lang);
  applyLang();
});

function renderGrid() {
  $("#tool-cards").innerHTML = Object.keys(TOOL_META)
    .map((key) => {
      const [name, desc] = T().tools[key];
      const m = TOOL_META[key];
      return `<button class="tool-card ${m.cls}" data-tool="${key}">
        <span class="tc-ico">${m.ico}</span>
        <strong>${name}</strong>
        <p>${desc}</p>
      </button>`;
    })
    .join("");
  document.querySelectorAll(".tool-card").forEach((c) =>
    c.addEventListener("click", () => openTool(c.dataset.tool))
  );
}

function openTool(key, keepFiles = false) {
  currentTool = key;
  if (!keepFiles) { files = []; renderFiles(); $("#results").innerHTML = ""; $("#status").textContent = ""; }
  const [name, desc] = T().tools[key];
  $("#tool-title").textContent = `${TOOL_META[key].ico} ${name}`;
  $("#tool-desc").textContent = desc;
  $("#process").textContent = `${TOOL_META[key].ico} ${name}`;
  $("#file-input").multiple = TOOL_META[key].multi;
  $("#file-input").accept = TOOL_META[key].accept;
  document.querySelectorAll(".opts").forEach((o) => (o.hidden = true));
  const opt = $("#opt-" + key);
  if (opt) opt.hidden = false;
  $("#grid-view").hidden = true;
  $("#tool-view").hidden = false;
  updateProcess();
  window.scrollTo(0, 0);
}

function goHome() {
  currentTool = null;
  $("#tool-view").hidden = true;
  $("#grid-view").hidden = false;
}
$("#back").addEventListener("click", goHome);
$("#brand-home").addEventListener("click", (e) => { e.preventDefault(); goHome(); });

/* ================= Files: pick, drop, list ================= */
const dz = $("#dropzone");
dz.addEventListener("click", () => $("#file-input").click());
$("#file-input").addEventListener("change", (e) => addFiles([...e.target.files]));
dz.addEventListener("dragover", (e) => { e.preventDefault(); dz.classList.add("over"); });
dz.addEventListener("dragleave", () => dz.classList.remove("over"));
dz.addEventListener("drop", (e) => {
  e.preventDefault();
  dz.classList.remove("over");
  addFiles([...e.dataTransfer.files]);
});

function addFiles(list) {
  if (!TOOL_META[currentTool].multi) files = [];
  files.push(...list);
  renderFiles();
  updateProcess();
}

function fmtSize(b) {
  return b > 1048576 ? (b / 1048576).toFixed(1) + " MB" : Math.round(b / 1024) + " KB";
}

function renderFiles() {
  $("#file-list").innerHTML = files
    .map(
      (f, i) => `<li>
        <span class="f-name">${f.name}</span>
        <span class="f-size">${fmtSize(f.size)}</span>
        ${files.length > 1 ? `<button class="mv" data-up="${i}" ${i === 0 ? "disabled" : ""}>↑</button>
        <button class="mv" data-dn="${i}" ${i === files.length - 1 ? "disabled" : ""}>↓</button>` : ""}
        <button class="rm" data-rm="${i}">✕</button>
      </li>`
    )
    .join("");
  document.querySelectorAll("[data-rm]").forEach((b) =>
    b.addEventListener("click", () => { files.splice(+b.dataset.rm, 1); renderFiles(); updateProcess(); })
  );
  document.querySelectorAll("[data-up]").forEach((b) =>
    b.addEventListener("click", () => {
      const i = +b.dataset.up;
      [files[i - 1], files[i]] = [files[i], files[i - 1]];
      renderFiles();
    })
  );
  document.querySelectorAll("[data-dn]").forEach((b) =>
    b.addEventListener("click", () => {
      const i = +b.dataset.dn;
      [files[i + 1], files[i]] = [files[i], files[i + 1]];
      renderFiles();
    })
  );
}

function updateProcess() {
  $("#process").disabled = files.length === 0;
}

/* range sliders live output */
$("#cmp-quality").addEventListener("input", (e) => ($("#cmp-q-out").textContent = e.target.value + "%"));
$("#wm-opacity").addEventListener("input", (e) => ($("#wm-o-out").textContent = e.target.value + "%"));

/* ================= Helpers ================= */
const readBytes = (f) => f.arrayBuffer().then((b) => new Uint8Array(b));

function offerDownload(bytes, name, mime = "application/pdf", extra = "") {
  const blob = bytes instanceof Blob ? bytes : new Blob([bytes], { type: mime });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.className = "dl-item";
  a.href = url;
  a.download = name;
  a.innerHTML = `⬇ ${name} <span class="f-size">${fmtSize(blob.size)}${extra ? " · " + extra : ""}</span>`;
  $("#results").appendChild(a);
  a.click(); // auto-start the download too
}

function parseRange(str, max) {
  const out = new Set();
  for (const part of str.split(",")) {
    const p = part.trim();
    if (!p) continue;
    const m = p.match(/^(\d+)\s*-\s*(\d+)$/);
    if (m) {
      for (let i = +m[1]; i <= +m[2]; i++) if (i >= 1 && i <= max) out.add(i - 1);
    } else if (/^\d+$/.test(p)) {
      const i = +p;
      if (i >= 1 && i <= max) out.add(i - 1);
    } else return null;
  }
  return out.size ? [...out].sort((a, b) => a - b) : null;
}

const baseName = (n) => n.replace(/\.[^.]+$/, "");

/* ================= The tools ================= */
const RUNNERS = {
  async merge() {
    if (files.length < 2) throw new Error(T().needTwo);
    const out = await PDFLib.PDFDocument.create();
    for (const f of files) {
      const src = await PDFLib.PDFDocument.load(await readBytes(f));
      const pages = await out.copyPages(src, src.getPageIndices());
      pages.forEach((p) => out.addPage(p));
    }
    offerDownload(await out.save(), "WCA-merged.pdf", "application/pdf",
      `${out.getPageCount()} ${T().pages}`);
  },

  async split() {
    const bytes = await readBytes(files[0]);
    const src = await PDFLib.PDFDocument.load(bytes);
    const n = src.getPageCount();

    if ($("#split-zip").checked) {
      const zip = new JSZip();
      for (let i = 0; i < n; i++) {
        const doc = await PDFLib.PDFDocument.create();
        const [p] = await doc.copyPages(src, [i]);
        doc.addPage(p);
        zip.file(`${baseName(files[0].name)}-page-${i + 1}.pdf`, await doc.save());
      }
      const blob = await zip.generateAsync({ type: "blob" });
      offerDownload(blob, `${baseName(files[0].name)}-pages.zip`, "application/zip", `${n} ${T().pages}`);
      return;
    }

    const idx = parseRange($("#split-range").value, n);
    if (!idx) throw new Error(T().badRange);
    const doc = await PDFLib.PDFDocument.create();
    const pages = await doc.copyPages(src, idx);
    pages.forEach((p) => doc.addPage(p));
    offerDownload(await doc.save(), `${baseName(files[0].name)}-extract.pdf`, "application/pdf",
      `${idx.length} ${T().pages}`);
  },

  async compress() {
    const quality = +$("#cmp-quality").value / 100;
    const bytes = await readBytes(files[0]);
    const pdf = await pdfjsLib.getDocument({ data: bytes.slice() }).promise;
    const out = await PDFLib.PDFDocument.create();
    for (let i = 1; i <= pdf.numPages; i++) {
      const page = await pdf.getPage(i);
      const vp = page.getViewport({ scale: 1.5 });
      const canvas = document.createElement("canvas");
      canvas.width = vp.width;
      canvas.height = vp.height;
      await page.render({ canvasContext: canvas.getContext("2d"), viewport: vp }).promise;
      const jpg = canvas.toDataURL("image/jpeg", quality);
      const img = await out.embedJpg(jpg);
      const p = out.addPage([vp.width, vp.height]);
      p.drawImage(img, { x: 0, y: 0, width: vp.width, height: vp.height });
    }
    const outBytes = await out.save();
    if (outBytes.length >= files[0].size) {
      // No gain — give back the original rather than a bigger file.
      offerDownload(bytes, files[0].name, "application/pdf", T().bigger);
    } else {
      const pct = Math.round((1 - outBytes.length / files[0].size) * 100);
      offerDownload(outBytes, `${baseName(files[0].name)}-compressed.pdf`, "application/pdf",
        `${pct}% ${T().smaller}`);
    }
  },

  async rotate() {
    const angle = +$("#rot-angle").value;
    const doc = await PDFLib.PDFDocument.load(await readBytes(files[0]));
    doc.getPages().forEach((p) =>
      p.setRotation(PDFLib.degrees((p.getRotation().angle + angle) % 360))
    );
    offerDownload(await doc.save(), `${baseName(files[0].name)}-rotated.pdf`);
  },

  async watermark() {
    const text = $("#wm-text").value.trim() || "WATERMARK";
    const opacity = +$("#wm-opacity").value / 100;
    const doc = await PDFLib.PDFDocument.load(await readBytes(files[0]));
    const font = await doc.embedFont(PDFLib.StandardFonts.HelveticaBold);
    doc.getPages().forEach((p) => {
      const { width, height } = p.getSize();
      const size = Math.min(width, height) / (text.length * 0.5);
      p.drawText(text, {
        x: width * 0.12,
        y: height * 0.25,
        size,
        font,
        color: PDFLib.rgb(0.5, 0.55, 0.6),
        opacity,
        rotate: PDFLib.degrees(35),
      });
    });
    offerDownload(await doc.save(), `${baseName(files[0].name)}-watermarked.pdf`);
  },

  async pagenum() {
    const start = +$("#pn-start").value || 1;
    const doc = await PDFLib.PDFDocument.load(await readBytes(files[0]));
    const font = await doc.embedFont(PDFLib.StandardFonts.Helvetica);
    doc.getPages().forEach((p, i) => {
      const { width } = p.getSize();
      const label = String(start + i);
      p.drawText(label, {
        x: width / 2 - font.widthOfTextAtSize(label, 11) / 2,
        y: 18,
        size: 11,
        font,
        color: PDFLib.rgb(0.25, 0.3, 0.35),
      });
    });
    offerDownload(await doc.save(), `${baseName(files[0].name)}-numbered.pdf`);
  },

  async jpg2pdf() {
    const out = await PDFLib.PDFDocument.create();
    for (const f of files) {
      const bytes = await readBytes(f);
      const img = f.type === "image/png" ? await out.embedPng(bytes) : await out.embedJpg(bytes);
      const page = out.addPage([img.width, img.height]);
      page.drawImage(img, { x: 0, y: 0, width: img.width, height: img.height });
    }
    offerDownload(await out.save(), "WCA-images.pdf", "application/pdf",
      `${files.length} ${T().pages}`);
  },

  async pdf2jpg() {
    const bytes = await readBytes(files[0]);
    const pdf = await pdfjsLib.getDocument({ data: bytes }).promise;
    const zip = new JSZip();
    for (let i = 1; i <= pdf.numPages; i++) {
      const page = await pdf.getPage(i);
      const vp = page.getViewport({ scale: 2 });
      const canvas = document.createElement("canvas");
      canvas.width = vp.width;
      canvas.height = vp.height;
      await page.render({ canvasContext: canvas.getContext("2d"), viewport: vp }).promise;
      const blob = await new Promise((r) => canvas.toBlob(r, "image/jpeg", 0.9));
      zip.file(`${baseName(files[0].name)}-page-${i}.jpg`, blob);
    }
    const blob = await zip.generateAsync({ type: "blob" });
    offerDownload(blob, `${baseName(files[0].name)}-images.zip`, "application/zip",
      `${pdf.numPages} ${T().pages}`);
  },

  async extract() {
    const bytes = await readBytes(files[0]);
    const pdf = await pdfjsLib.getDocument({ data: bytes }).promise;
    let text = "";
    for (let i = 1; i <= pdf.numPages; i++) {
      const page = await pdf.getPage(i);
      const content = await page.getTextContent();
      text += content.items.map((it) => it.str).join(" ") + "\n\n";
    }
    offerDownload(new Blob([text], { type: "text/plain" }), `${baseName(files[0].name)}.txt`, "text/plain");
  },
};

$("#process").addEventListener("click", async () => {
  $("#results").innerHTML = "";
  $("#status").textContent = T().working;
  $("#process").disabled = true;
  try {
    await RUNNERS[currentTool]();
    $("#status").textContent = T().done;
  } catch (e) {
    console.error(e);
    $("#status").textContent = "⚠️ " + (e.message && STRerr(e.message) ? e.message : T().err);
  }
  $("#process").disabled = false;
});

// Show our own validation messages verbatim; anything else gets the generic error.
function STRerr(msg) {
  return [T().needTwo, T().badRange].includes(msg);
}

/* ================= Boot ================= */
applyLang();
