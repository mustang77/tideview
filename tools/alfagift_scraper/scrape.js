#!/usr/bin/env node
'use strict';

/**
 * Alfagift catalog scraper for the tideview shop.
 *
 * Alfagift (alfagift.id) is Alfamart's own online store. It is a single-page
 * app whose product data comes from a private JSON API at
 * webcommerce-gw.alfagift.id. Those endpoints require a short-lived guest
 * token that the site's own JavaScript fetches on load, so instead of trying
 * to replicate that token flow (which breaks whenever they rotate it) this
 * scraper drives a real headless Chromium: the site authenticates itself, and
 * we simply read the product JSON as it streams back, plus poke the same API
 * from inside the page (reusing the page's own token) to page through results.
 *
 * Output: catalog.json (full) and catalog.csv (name, price, image) that you can
 * import into your shop's product table.
 *
 * IMPORTANT — this pulls data from a third party. Confirm it is allowed in your
 * jurisdiction and under their terms before running at scale. Keep the request
 * rate gentle (this script is deliberately slow) and treat prices as indicative
 * — always re-check at the counter, since your team buys in-store.
 *
 * Usage:
 *   node scrape.js --list-categories
 *   node scrape.js --category 1234 --max 500
 *   node scrape.js --search "indomie,beras,minyak goreng" --max 300
 *   node scrape.js --all --max 2000            # walk every category
 *   node scrape.js --search indomie --raw      # dump the first raw API response and exit
 *   node scrape.js --search indomie --headful  # show the browser (debugging)
 *
 * Env:
 *   PROXY_SERVER=http://host:port   route the browser through a proxy if you need one
 */

const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');
const { normalizeProduct, extractProducts } = require('./normalize');

const BASE = 'https://alfagift.id';
const API_HOST = 'webcommerce-gw.alfagift.id';
const UA =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ' +
  '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';

// ---- tiny arg parser -------------------------------------------------------
function parseArgs(argv) {
  const args = { max: 1000, pageSize: 50, delayMs: 900 };
  for (let i = 2; i < argv.length; i++) {
    const a = argv[i];
    const next = () => argv[++i];
    switch (a) {
      case '--category': args.category = next(); break;
      case '--search': args.search = next(); break;
      case '--all': args.all = true; break;
      case '--list-categories': args.listCategories = true; break;
      case '--max': args.max = parseInt(next(), 10); break;
      case '--page-size': args.pageSize = parseInt(next(), 10); break;
      case '--delay': args.delayMs = parseInt(next(), 10); break;
      case '--out': args.out = next(); break;
      case '--raw': args.raw = true; break;
      case '--headful': args.headful = true; break;
      case '--help': case '-h': args.help = true; break;
      default: console.error('Unknown arg:', a);
    }
  }
  return args;
}

const HELP = `Alfagift catalog scraper

  --list-categories        Print the category tree (id + name) and exit
  --category <id>          Scrape one category by id
  --all                    Scrape every category (respects --max total)
  --search <a,b,c>         Scrape one or more search keywords (comma separated)
  --max <n>                Stop after n unique products (default 1000)
  --page-size <n>          Products requested per API page (default 50)
  --delay <ms>             Delay between API pages (default 900)
  --out <dir>              Output directory (default ./output)
  --raw                    Save the first raw API response to output/raw-sample.json and exit
  --headful                Launch a visible browser (debugging)
  --help                   Show this help
`;

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function launchBrowser(headful) {
  const launchOpts = {
    headless: !headful,
    args: ['--no-sandbox', '--disable-gpu', '--disable-blink-features=AutomationControlled'],
  };
  if (process.env.PROXY_SERVER) launchOpts.proxy = { server: process.env.PROXY_SERVER };
  const browser = await chromium.launch(launchOpts);
  const context = await browser.newContext({
    userAgent: UA,
    locale: 'id-ID',
    viewport: { width: 1366, height: 900 },
    ignoreHTTPSErrors: true,
  });
  return { browser, context };
}

// Warm the page so the site fetches its guest token, then hand back helpers.
// Two ways to get data, used together for resilience:
//   1. call()  — hit the API from inside the page, adding the bearer token the
//      site keeps in its cookie (its own axios does the same). Supports paging.
//   2. interception — capture the product JSON the site loads on its own (e.g.
//      when we navigate to a real search page via primeSearch). No auth to
//      replicate; whatever the site can load, we get.
async function openApiSession(context) {
  const page = await context.newPage();

  // Safety net: collect product/category JSON the site requests on its own.
  const captured = [];
  page.on('response', async (res) => {
    const u = res.url();
    if (u.includes(API_HOST) && /\/v2\/(products|categories)/.test(u)) {
      try { captured.push(await res.json()); } catch (e) { /* not JSON */ }
    }
  });

  // Grab the bearer token the site sends on its OWN API requests, so we can
  // reuse it for clean, keyword-specific, paginated calls even when the token
  // isn't exposed in a readable cookie.
  const state = { auth: null };
  page.on('request', (req) => {
    if (state.auth) return;
    if (!req.url().includes(API_HOST)) return;
    const a = req.headers()['authorization'];
    if (a) state.auth = a;
  });

  await page.goto(BASE + '/', { waitUntil: 'domcontentloaded', timeout: 60000 });
  await page.waitForTimeout(5000); // let the SPA obtain its guest token + first calls

  const cookieTok = await page.evaluate(() => /auth\._token\.local=/.test(document.cookie));
  console.log(`  token — cookie: ${cookieTok}, captured from site requests: ${!!state.auth}`);

  const call = (pathAndQuery) =>
    page.evaluate(async ({ url, auth }) => {
      try {
        const headers = { accept: 'application/json' };
        const m = document.cookie.match(/auth\._token\.local=([^;]+)/);
        if (m) {
          const t = decodeURIComponent(m[1]);
          headers.authorization = /^bearer\s/i.test(t) ? t : 'Bearer ' + t;
        } else if (auth) {
          headers.authorization = auth;
        }
        const res = await fetch(url, { credentials: 'include', headers });
        const text = await res.text();
        let json = null;
        try { json = JSON.parse(text); } catch (e) {}
        return { status: res.status, json, text: json ? null : text.slice(0, 300) };
      } catch (e) {
        return { status: -1, error: String(e) };
      }
    }, { url: `https://${API_HOST}${pathAndQuery}`, auth: state.auth });

  // Navigate the real search page so the site itself loads (authenticated)
  // results, which the interception handler above then captures.
  const primeSearch = async (keyword) => {
    try {
      await page.goto(`${BASE}/search?keyword=${encodeURIComponent(keyword)}`,
        { waitUntil: 'domcontentloaded', timeout: 60000 });
      await page.waitForTimeout(4500);
    } catch (e) { /* ignore navigation hiccups */ }
  };

  return { page, call, captured, primeSearch };
}

// Fold any intercepted payloads into the product list (deduped).
function drainCaptured(captured, products, seen, max) {
  for (const payload of captured) {
    for (const raw of extractProducts(payload)) {
      const p = normalizeProduct(raw);
      if (!p) continue;
      const key = p.sku || p.name;
      if (seen.has(key)) continue;
      seen.add(key);
      products.push(p);
      if (products.length >= max) return;
    }
  }
}

async function listCategories(call) {
  const res = await call('/v2/categories');
  if (res.status !== 200 || !res.json) {
    throw new Error(`categories request failed (status ${res.status}). ${res.error || res.text || ''}`);
  }
  const cats = [];
  const walk = (nodes, depth) => {
    if (!Array.isArray(nodes)) return;
    for (const n of nodes) {
      const id = n.categoryId ?? n.id ?? n.categoryCode;
      const name = n.categoryName ?? n.name ?? n.title;
      if (id !== undefined && name) cats.push({ id: String(id), name, depth });
      const kids = n.subCategories ?? n.children ?? n.subCategory ?? n.categories;
      if (kids) walk(kids, depth + 1);
    }
  };
  // The category payload envelope varies; search a couple of likely roots.
  walk(res.json.categories ?? res.json.data ?? res.json, 0);
  return cats;
}

// Page through one endpoint template until we stop getting new products.
async function harvest(call, makePath, opts, collected, seen) {
  let start = 0;
  while (collected.length < opts.max) {
    const res = await call(makePath(start, opts.pageSize));
    if (res.status !== 200 || !res.json) {
      if (start === 0) console.warn(`  ! request failed (status ${res.status}) ${res.error || res.text || ''}`);
      break;
    }
    const batch = extractProducts(res.json);
    if (!batch.length) break;
    let added = 0;
    for (const raw of batch) {
      const p = normalizeProduct(raw);
      if (!p) continue;
      const key = p.sku || p.name;
      if (seen.has(key)) continue;
      seen.add(key);
      collected.push(p);
      added++;
      if (collected.length >= opts.max) break;
    }
    process.stdout.write(`\r  collected ${collected.length} products...  `);
    if (added === 0) break; // no new items -> end of this stream
    start += opts.pageSize;
    await sleep(opts.delayMs);
  }
  process.stdout.write('\n');
}

function writeOutputs(outDir, products) {
  fs.mkdirSync(outDir, { recursive: true });
  const jsonPath = path.join(outDir, 'catalog.json');
  fs.writeFileSync(jsonPath, JSON.stringify(products, null, 2));

  const esc = (v) => {
    if (v === undefined || v === null) return '';
    const s = String(v);
    return /[",\n]/.test(s) ? '"' + s.replace(/"/g, '""') + '"' : s;
  };
  const header = ['sku', 'name', 'price', 'priceOriginal', 'unit', 'available', 'imageUrl'];
  const rows = [header.join(',')];
  for (const p of products) {
    rows.push([p.sku, p.name, p.price, p.priceOriginal, p.unit, p.available, p.imageUrl].map(esc).join(','));
  }
  const csvPath = path.join(outDir, 'catalog.csv');
  fs.writeFileSync(csvPath, rows.join('\n'));
  return { jsonPath, csvPath };
}

async function main() {
  const args = parseArgs(process.argv);
  if (args.help) { console.log(HELP); return; }
  const outDir = args.out || path.join(__dirname, 'output');

  const { browser, context } = await launchBrowser(args.headful);
  try {
    const session = await openApiSession(context);
    const { call } = session;

    // --raw: dump the first product response so you can confirm the real field
    // names and adjust normalize.js if Alfagift has renamed anything.
    if (args.raw) {
      const kw = (args.search || 'indomie').split(',')[0].trim();
      const res = await call(`/v2/products/searches?keyword=${encodeURIComponent(kw)}&start=0&limit=10`);
      fs.mkdirSync(outDir, { recursive: true });
      const p = path.join(outDir, 'raw-sample.json');
      fs.writeFileSync(p, JSON.stringify(res, null, 2));
      console.log(`Saved raw API response to ${p} (status ${res.status}).`);
      console.log('Open it, check the product field names, and tweak normalize.js if needed.');
      return;
    }

    if (args.listCategories) {
      const cats = await listCategories(call);
      console.log(`Found ${cats.length} categories:\n`);
      for (const c of cats) console.log(`${'  '.repeat(c.depth)}${c.id}\t${c.name}`);
      return;
    }

    const products = [];
    const seen = new Set();
    const opts = { max: args.max, pageSize: args.pageSize, delayMs: args.delayMs };

    if (args.search) {
      for (const kw of args.search.split(',').map((s) => s.trim()).filter(Boolean)) {
        if (products.length >= opts.max) break;
        console.log(`Search: "${kw}"`);
        // Let the site load authenticated page-0 results (captured via interception)...
        await session.primeSearch(kw);
        drainCaptured(session.captured, products, seen, opts.max);
        // ...then page for more directly.
        await harvest(
          call,
          (start, limit) => `/v2/products/searches?keyword=${encodeURIComponent(kw)}&start=${start}&limit=${limit}`,
          opts, products, seen
        );
        drainCaptured(session.captured, products, seen, opts.max);
        console.log(`  running total: ${products.length}`);
      }
    } else if (args.category) {
      console.log(`Category: ${args.category}`);
      await harvest(
        call,
        (start, limit) => `/v2/products/category/${args.category}?sortDirection=asc&start=${start}&limit=${limit}`,
        opts, products, seen
      );
      drainCaptured(session.captured, products, seen, opts.max);
    } else if (args.all) {
      const cats = await listCategories(call);
      // Leaf-ish categories (deepest) hold the actual products.
      const leaves = cats.filter((c) => c.depth >= 1);
      console.log(`Walking ${leaves.length} categories...`);
      for (const c of leaves) {
        if (products.length >= opts.max) break;
        console.log(`  category ${c.id} (${c.name})`);
        await harvest(
          call,
          (start, limit) => `/v2/products/category/${c.id}?sortDirection=asc&start=${start}&limit=${limit}`,
          opts, products, seen
        );
      }
    } else {
      console.log(HELP);
      console.log('Nothing to do: pass --search, --category, --all, or --list-categories.');
      return;
    }

    // Last resort: whatever the site loaded on its own (homepage, etc.).
    if (!products.length) drainCaptured(session.captured, products, seen, opts.max);

    if (!products.length) {
      console.error(
        `\nNo products collected (intercepted payloads seen: ${session.captured.length}). ` +
        'Run `node scrape.js --search indomie --raw` and inspect output/raw-sample.json — ' +
        'the API may have changed or the guest token was not issued.'
      );
      process.exitCode = 2;
      return;
    }

    const { jsonPath, csvPath } = writeOutputs(outDir, products);
    console.log(`\nDone. ${products.length} products written:`);
    console.log(`  ${jsonPath}`);
    console.log(`  ${csvPath}`);
  } finally {
    await browser.close();
  }
}

main().catch((err) => {
  console.error('\nScraper failed:', err.message);
  process.exit(1);
});
