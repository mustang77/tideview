#!/usr/bin/env node
'use strict';

/**
 * Mirror every product image in the catalog to Bunny Storage, then rewrite the
 * catalog's imageUrl to serve from the Bunny CDN. Idempotent: images already on
 * the CDN host are skipped, so re-runs only mirror new products.
 *
 * Config comes from env (set by the GitHub workflow):
 *   STORAGE_ZONE      Bunny storage zone name (e.g. wcamobile)
 *   PULL_HOST         Bunny CDN hostname (e.g. wcamobile.b-cdn.net)
 *   STORAGE_ENDPOINT  Region upload host (e.g. sg.storage.bunnycdn.com)
 *   PREFIX            Folder inside the zone (default: paramall)
 *   BUNNY_STORAGE_KEY Storage password (a GitHub secret — never in code)
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const ZONE = process.env.STORAGE_ZONE;
const HOST = process.env.PULL_HOST;
const ENDPOINT = process.env.STORAGE_ENDPOINT;
const PREFIX = process.env.PREFIX || 'paramall';
const KEY = process.env.BUNNY_STORAGE_KEY || '';

if (!KEY) { console.log('BUNNY_STORAGE_KEY not set — add the GitHub secret first. Skipping.'); process.exit(0); }
if (!ZONE || !HOST || !ENDPOINT) { console.log('Missing STORAGE_ZONE / PULL_HOST / STORAGE_ENDPOINT. Skipping.'); process.exit(0); }

const root = path.join(__dirname, '..');
const catPath = path.join(root, 'assets', 'catalog.json');
const cat = JSON.parse(fs.readFileSync(catPath, 'utf8'));
const cdnBase = `https://${HOST}/${PREFIX}/`;

function nameFor(url) {
  const h = crypto.createHash('sha1').update(url).digest('hex');
  const m = url.split('?')[0].match(/\.(jpe?g|png|webp|gif)$/i);
  return h + (m ? m[0].toLowerCase() : '.jpg');
}

async function download(url) {
  const res = await fetch(url, { redirect: 'follow' });
  if (!res.ok) throw new Error('download ' + res.status);
  return Buffer.from(await res.arrayBuffer());
}

async function upload(name, buf) {
  const res = await fetch(`https://${ENDPOINT}/${ZONE}/${PREFIX}/${name}`, {
    method: 'PUT',
    headers: { AccessKey: KEY, 'Content-Type': 'application/octet-stream' },
    body: buf,
  });
  if (res.status !== 201 && res.status !== 200) {
    throw new Error('upload ' + res.status + ' ' + (await res.text()).slice(0, 120));
  }
}

(async () => {
  let mirrored = 0, skipped = 0, failed = 0;
  let firstError = '';
  const items = cat.slice();
  let idx = 0;
  const worker = async () => {
    while (idx < items.length) {
      const p = items[idx++];
      const url = (p && p.imageUrl) || '';
      if (!url || url.startsWith(cdnBase)) { skipped++; continue; }
      try {
        const buf = await download(url);
        const name = nameFor(url);
        await upload(name, buf);
        p.imageUrl = cdnBase + name;
        mirrored++;
      } catch (e) {
        failed++;
        if (!firstError) firstError = String(e.message || e);
      }
    }
  };
  await Promise.all(Array.from({ length: 6 }, worker));
  console.log(`mirrored=${mirrored} skipped=${skipped} failed=${failed}`);
  if (failed && firstError) console.log('first error: ' + firstError);
  if (mirrored > 0) {
    const json = JSON.stringify(cat, null, 1) + '\n';
    fs.writeFileSync(catPath, json);
    fs.writeFileSync(path.join(root, 'site', 'catalog.json'), json);
    console.log('Catalog rewritten to Bunny CDN URLs.');
  } else {
    console.log('Nothing new mirrored — catalog unchanged.');
  }
})().catch((e) => { console.error(e); process.exit(1); });
