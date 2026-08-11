#!/usr/bin/env node
'use strict';

/**
 * Klik Indomaret catalog scraper for the tideview shop.
 *
 * Klik Indomaret (klikindomaret.com) serves its products from a JSON API at
 * ap-mc.klikindomaret.com, but the whole domain sits behind Cloudflare's
 * "Just a moment..." bot challenge — plain HTTP requests get a 403 challenge
 * page, not data. So, like the Alfagift tool, this drives a real headless
 * Chromium: the browser solves the Cloudflare challenge (best from a normal /
 * residential IP), and we then call the same API *from inside the page*, which
 * reuses the Cloudflare clearance cookie and the site's own headers.
 *
 * Endpoints (discovered from the live site):
 *   Base: https://ap-mc.klikindomaret.com
 *   Categories: /assets-klikidmgroceries/api/get/catalog-xpress/api/webapp/category/meta
 *   Products:   /assets-klikidmcore/api/get/catalog-xpress/api/webapp/search/result
 *   Params:     storeCode, latitude, longitude, mode=DELIVERY, districtId,
 *               page (0-based), size, categories=<id>   (keyword search: see --search)
 *   Fields:     productId, productName, imageUrl, price, finalPrice
 *
 * IMPORTANT — store location matters. The storeCode / latitude / longitude /
 * districtId below default to a Jakarta store. Set them to YOUR city's store so
 * the catalog, availability, and prices match what your team will actually buy.
 * (Open klikindomaret.com in a browser, pick your delivery location, then read
 * the request params in DevTools > Network, or run this with --raw and copy the
 * values the site used.)
 *
 * IMPORTANT — third-party data. Confirm scraping is allowed where you operate,
 * keep the rate gentle (defaults are slow), and treat prices as indicative:
 * your team pays the in-store shelf price. Keep a margin buffer.
 *
 * Usage:
 *   node scrape.js --list-categories
 *   node scrape.js --category <categoryId> --max 500
 *   node scrape.js --all --max 2000
 *   node scrape.js --search "indomie" --max 200      # keyword search (see --search-param)
 *   node scrape.js --raw                             # dump first raw API response and exit
 *   node scrape.js --headful                         # show the browser (debug / solve challenge)
 *
 * Store-location flags (override the Jakarta defaults):
 *   --store-code TJKT --lat -6.1763897 --lng 106.82667 --district 141100100
 *
 * Env:
 *   PROXY_SERVER=http://host:port   route the browser through a proxy if needed
 */

const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');
const { normalizeProduct, extractProducts } = require('./normalize');

const SITE = 'https://www.klikindomaret.com';
const API = 'https://ap-mc.klikindomaret.com';
const EP_CATEGORIES = '/assets-klikidmgroceries/api/get/catalog-xpress/api/webapp/category/meta';
const EP_PRODUCTS = '/assets-klikidmcore/api/get/catalog-xpress/api/webapp/search/result';
const UA =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ' +
  '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';

// ---- args ------------------------------------------------------------------
function parseArgs(argv) {
  const a = {
    max: 1000, pageSize: 50, delayMs: 1000,
    storeCode: 'TJKT', lat: '-6.1763897', lng: '106.82667', district: '141100100',
    searchParam: 'key',
  };
  for (let i = 2; i < argv.length; i++) {
    const next = () => argv[++i];
    switch (argv[i]) {
      case '--category': a.category = next(); break;
      case '--search': a.search = next(); break;
      case '--search-param': a.searchParam = next(); break;
      case '--all': a.all = true; break;
      case '--list-categories': a.listCategories = true; break;
      case '--max': a.max = parseInt(next(), 10); break;
      case '--page-size': a.pageSize = parseInt(next(), 10); break;
      case '--delay': a.delayMs = parseInt(next(), 10); break;
      case '--store-code': a.storeCode = next(); break;
      case '--lat': a.lat = next(); break;
      case '--lng': a.lng = next(); break;
      case '--district': a.district = next(); break;
      case '--out': a.out = next(); break;
      case '--raw': a.raw = true; break;
      case '--headful': a.headful = true; break;
      case '--help': case '-h': a.help = true; break;
      default: console.error('Unknown arg:', argv[i]);
    }
  }
  return a;
}

const HELP = `Klik Indomaret catalog scraper

  --list-categories        Print the category tree (id + name) and exit
  --category <id>          Scrape one category by id
  --all                    Scrape every category (respects --max total)
  --search <keyword>       Keyword search (param name via --search-param, default "key")
  --search-param <name>    Query param that carries the keyword (default "key")
  --max <n>                Stop after n unique products (default 1000)
  --page-size <n>          Products per API page (default 50)
  --delay <ms>             Delay between pages (default 1000 — keep it gentle)
  --store-code <code>      Store code (default TJKT / Jakarta) -- SET TO YOUR CITY
  --lat <v> --lng <v>      Delivery coordinates for pricing/availability
  --district <id>          District id used by the API
  --out <dir>              Output directory (default ./output)
  --raw                    Save the first raw API response to output/raw-sample.json and exit
  --headful                Launch a visible browser (debug / manually pass Cloudflare)
  --help                   Show this help
`;

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function baseParams(a) {
  return `storeCode=${encodeURIComponent(a.storeCode)}&latitude=${encodeURIComponent(a.lat)}` +
    `&longitude=${encodeURIComponent(a.lng)}&mode=DELIVERY&districtId=${encodeURIComponent(a.district)}`;
}

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

// Load the site so Cloudflare issues a clearance cookie, then return a helper
// that calls the API from inside the page (inheriting cf_clearance + cookies).
async function openApiSession(context, headful) {
  const page = await context.newPage();
  await page.goto(SITE + '/', { waitUntil: 'domcontentloaded', timeout: 90000 });

  // Wait for Cloudflare's interstitial to go away (title stops being "Just a moment...").
  const deadline = Date.now() + (headful ? 120000 : 45000);
  while (Date.now() < deadline) {
    const title = await page.title().catch(() => '');
    if (!/just a moment|attention required/i.test(title)) break;
    await page.waitForTimeout(1500);
  }
  // Let the SPA make its first ap-mc call so we also hold clearance for that host.
  await page.waitForTimeout(4000);

  const call = (pathAndQuery) =>
    page.evaluate(async (url) => {
      try {
        const res = await fetch(url, { credentials: 'include', headers: { accept: 'application/json' } });
        const text = await res.text();
        let json = null;
        try { json = JSON.parse(text); } catch (e) {}
        return { status: res.status, json, text: json ? null : text.slice(0, 500) };
      } catch (e) {
        return { status: -1, error: String(e) };
      }
    }, `${API}${pathAndQuery}`);

  return { page, call };
}

async function listCategories(call, a) {
  const res = await call(`${EP_CATEGORIES}?${baseParams(a)}`);
  if (res.status !== 200 || !res.json) {
    throw new Error(`categories request failed (status ${res.status}). ${res.error || res.text || ''}`);
  }
  const cats = [];
  const walk = (nodes, depth) => {
    if (!Array.isArray(nodes)) return;
    for (const n of nodes) {
      if (!n || typeof n !== 'object') continue;
      const id = n.categoryId ?? n.id ?? n.code ?? n.categoryCode;
      const name = n.categoryName ?? n.name ?? n.title;
      if (id !== undefined && name) cats.push({ id: String(id), name, depth });
      const kids = n.childs ?? n.children ?? n.subCategories ?? n.subCategory ?? n.categories;
      if (kids) walk(kids, depth + 1);
    }
  };
  walk(res.json.categories ?? res.json.data ?? res.json.result ?? res.json, 0);
  return cats;
}

async function harvest(call, makePath, opts, collected, seen) {
  let page = 0;
  while (collected.length < opts.max) {
    const res = await call(makePath(page, opts.pageSize));
    if (res.status !== 200 || !res.json) {
      if (page === 0) console.warn(`  ! request failed (status ${res.status}) ${res.error || res.text || ''}`);
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
    if (added === 0) break;
    page += 1;
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
  const a = parseArgs(process.argv);
  if (a.help) { console.log(HELP); return; }
  const outDir = a.out || path.join(__dirname, 'output');

  const { browser, context } = await launchBrowser(a.headful);
  try {
    const { call } = await openApiSession(context, a.headful);

    if (a.raw) {
      // Prefer a category listing for the raw sample; fall back to search.
      const q = a.category
        ? `${EP_PRODUCTS}?${baseParams(a)}&page=0&size=10&categories=${encodeURIComponent(a.category)}`
        : `${EP_PRODUCTS}?${baseParams(a)}&page=0&size=10&${a.searchParam}=${encodeURIComponent(a.search || 'indomie')}`;
      const res = await call(q);
      fs.mkdirSync(outDir, { recursive: true });
      const p = path.join(outDir, 'raw-sample.json');
      fs.writeFileSync(p, JSON.stringify(res, null, 2));
      console.log(`Saved raw API response to ${p} (status ${res.status}).`);
      if (res.status !== 200) {
        console.log('Non-200 usually means the Cloudflare challenge was not solved — try --headful once,');
        console.log('or run from a normal (non-datacenter) IP.');
      } else {
        console.log('Open it, confirm the product field names, and tweak normalize.js if needed.');
      }
      return;
    }

    if (a.listCategories) {
      const cats = await listCategories(call, a);
      console.log(`Found ${cats.length} categories:\n`);
      for (const c of cats) console.log(`${'  '.repeat(c.depth)}${c.id}\t${c.name}`);
      return;
    }

    const products = [];
    const seen = new Set();
    const opts = { max: a.max, pageSize: a.pageSize, delayMs: a.delayMs };

    if (a.search) {
      console.log(`Search: "${a.search}" (param "${a.searchParam}")`);
      await harvest(
        call,
        (page, size) => `${EP_PRODUCTS}?${baseParams(a)}&page=${page}&size=${size}&${a.searchParam}=${encodeURIComponent(a.search)}`,
        opts, products, seen
      );
    } else if (a.category) {
      console.log(`Category: ${a.category}`);
      await harvest(
        call,
        (page, size) => `${EP_PRODUCTS}?${baseParams(a)}&page=${page}&size=${size}&categories=${encodeURIComponent(a.category)}`,
        opts, products, seen
      );
    } else if (a.all) {
      const cats = await listCategories(call, a);
      const leaves = cats.filter((c) => c.depth >= 1);
      console.log(`Walking ${leaves.length} categories...`);
      for (const c of leaves) {
        if (products.length >= opts.max) break;
        console.log(`  category ${c.id} (${c.name})`);
        await harvest(
          call,
          (page, size) => `${EP_PRODUCTS}?${baseParams(a)}&page=${page}&size=${size}&categories=${encodeURIComponent(c.id)}`,
          opts, products, seen
        );
      }
    } else {
      console.log(HELP);
      console.log('Nothing to do: pass --search, --category, --all, or --list-categories.');
      return;
    }

    if (!products.length) {
      console.error(
        '\nNo products collected. Likely causes:\n' +
        '  - Cloudflare challenge not solved (try --headful once, or a residential IP)\n' +
        '  - Wrong store location (set --store-code/--lat/--lng/--district for your city)\n' +
        '  - API fields changed: run with --raw and inspect output/raw-sample.json, then adjust normalize.js'
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
