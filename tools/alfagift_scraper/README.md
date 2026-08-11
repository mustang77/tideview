# Alfagift catalog scraper

Pulls product **name, image, and price** from [Alfagift](https://alfagift.id)
(Alfamart's own online store) into a catalog file you can import into the
tideview shop. Your team still buys the items in-store; this just seeds your
online product list so customers have something to browse and order from.

There is **no official Alfamart or Indomaret product API** — this reads
Alfagift's website the same way a browser does. See "Legal & fair use" below
before running it at scale.

## How it works

Alfagift is a single-page app; its products come from a private JSON API
(`webcommerce-gw.alfagift.id/v2/products/...`) that requires a short-lived guest
token the site fetches automatically. Rather than reverse-engineer that token,
this scraper launches a real headless Chromium, lets the site authenticate
itself, then reads the product JSON — calling the same API *from inside the
page* so it reuses the page's token. That makes it resilient: when Alfagift
rotates tokens or tweaks auth, the browser handles it for you.

## Install

Requires Node.js 18+.

```bash
cd tools/alfagift_scraper
npm install          # also downloads a Chromium build via `playwright install`
```

If you run on a server where Chromium is already provided, set
`PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1` before `npm install` and point Playwright
at your existing browser.

## Usage

```bash
# 1. See what categories exist
node scrape.js --list-categories

# 2. Scrape by search keyword(s) — good for a curated starter catalog
node scrape.js --search "indomie,beras,minyak goreng,gula,telur" --max 300

# 3. Scrape one category by id (from step 1)
node scrape.js --category 1234 --max 500

# 4. Walk every category (larger, slower)
node scrape.js --all --max 2000
```

Output lands in `output/`:

- `catalog.json` — full records (`sku, name, imageUrl, price, priceOriginal, unit, available`, plus the raw object)
- `catalog.csv` — `sku, name, price, priceOriginal, unit, available, imageUrl`

### Options

| Flag | Meaning |
|------|---------|
| `--search <a,b,c>` | One or more keywords (comma separated) |
| `--category <id>` | Scrape a single category |
| `--all` | Walk every category (respects `--max` total) |
| `--list-categories` | Print the category tree and exit |
| `--max <n>` | Stop after n unique products (default 1000) |
| `--page-size <n>` | Products per API page (default 50) |
| `--delay <ms>` | Delay between pages (default 900 — keep it gentle) |
| `--out <dir>` | Output directory (default `./output`) |
| `--raw` | Save the first raw API response and exit (see below) |
| `--headful` | Show the browser window (debugging) |
| `PROXY_SERVER=...` | Env var: route the browser through a proxy |

## If prices/images come out empty

Alfagift can rename its JSON fields at any time. When that happens:

```bash
node scrape.js --search indomie --raw
```

This writes `output/raw-sample.json` — the actual API response. Open it, look
at the real product field names, and add them to the candidate lists at the top
of [`normalize.js`](./normalize.js) (`NAME_KEYS`, `PRICE_KEYS`, `IMAGE_KEYS`,
etc.). That's usually a one-line fix. No other file needs to change.

## Importing into the tideview shop

`catalog.csv`/`catalog.json` are meant to **seed your own product table**, not
to be read live by the app. Recommended flow:

1. Load the file into your shop's backend/database as your own products, each
   with **your own SKU, your own price (add a margin buffer), and an
   `available` flag** you control.
2. Keep them as *your* records. Don't have the Flutter app call Alfagift
   directly — the online price and stock won't match what your team finds on the
   shelf, and it couples your shop to a site that can change or block you.
3. Re-run the scraper periodically (e.g. weekly) to refresh names/images and
   spot new items; reconcile against your table rather than overwriting prices
   blindly.

This also means the day you open your own store, the catalog is already yours —
nothing to untangle.

## Legal & fair use

- This scrapes a third-party site. Confirm it's permitted in your jurisdiction
  and under Alfagift's terms before running it at scale. You told us scraping
  name/image/price is acceptable where you operate — this tool takes only those
  fields.
- Be a good citizen: the defaults are deliberately slow (`--delay 900`). Don't
  hammer the site; scrape off-peak and cache results.
- Treat prices as **indicative**. Your team pays the in-store shelf price, which
  can differ from the online price — always re-check at the counter and keep a
  margin buffer in your own pricing.

## Indomaret

Klik Indomaret works the same way (SPA + private API) but its endpoints and
auth differ, so this scraper targets Alfagift only. If you want an Indomaret
importer too, the same browser-driven approach applies — ask and it can be
added as a sibling tool.
