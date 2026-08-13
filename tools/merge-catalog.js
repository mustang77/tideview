#!/usr/bin/env node
'use strict';

/**
 * Merge a scraper's output into the app catalog (assets/catalog.json +
 * site/catalog.json). Additive: keeps what's already there and adds new
 * products, de-duped by name, keeping only ones that have a photo.
 *
 * Run after scraping locally:
 *   node tools/merge-catalog.js klikindomaret
 *   node tools/merge-catalog.js alfagift
 */

const fs = require('fs');
const path = require('path');

const which = (process.argv[2] || 'klikindomaret').toLowerCase();
const dir = which === 'alfagift' ? 'alfagift_scraper' : 'klikindomaret_scraper';
const root = path.join(__dirname, '..');
const srcPath = path.join(__dirname, dir, 'output', 'catalog.json');

if (!fs.existsSync(srcPath)) {
  console.error(`No scrape output at ${srcPath}\nRun the scraper first (see the README / instructions).`);
  process.exit(1);
}

const scraped = JSON.parse(fs.readFileSync(srcPath, 'utf8'));
let existing = [];
try { existing = JSON.parse(fs.readFileSync(path.join(root, 'assets', 'catalog.json'), 'utf8')); } catch (e) { /* start fresh */ }

const int = (v) => { const n = Math.round(Number(v)); return Number.isFinite(n) ? n : 0; };
const seen = new Set();
const out = [];
const add = (p) => {
  if (!p || !p.name) return;
  const price = int(p.price);
  if (price <= 0) return;
  const img = (typeof p.imageUrl === 'string') ? p.imageUrl : '';
  if (!img) return; // photo required
  const key = String(p.name).trim().toLowerCase();
  if (seen.has(key)) return;
  seen.add(key);
  const row = { name: String(p.name).trim(), price };
  const po = int(p.priceOriginal);
  if (po > price) row.priceOriginal = po;
  row.imageUrl = img;
  out.push(row);
};

existing.forEach(add); // keep current catalog...
scraped.forEach(add);  // ...then add newly scraped products

const json = JSON.stringify(out, null, 1) + '\n';
fs.writeFileSync(path.join(root, 'assets', 'catalog.json'), json);
fs.writeFileSync(path.join(root, 'site', 'catalog.json'), json);
console.log(`Catalog now has ${out.length} products (was ${existing.length}, added ${out.length - existing.length}).`);
