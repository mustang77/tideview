# Klik Indomaret catalog scraper

Pulls product **name, image, and price** from
[Klik Indomaret](https://www.klikindomaret.com) into a catalog file you can
import into the tideview shop. Sibling of `../alfagift_scraper`; same idea,
different site.

There is **no official Indomaret product API** — this reads the site the same
way a browser does. See "Legal & fair use" below.

## How it works

Klik Indomaret serves products from a JSON API at `ap-mc.klikindomaret.com`, but
the **entire domain is behind Cloudflare's "Just a moment..." bot challenge** —
a plain `curl`/`fetch` gets a 403 challenge page, not data. So this scraper
launches a real headless Chromium, lets it clear the Cloudflare challenge, then
calls the same API *from inside the page* (reusing the clearance cookie and the
site's own headers).

Endpoints it uses (discovered from the live site):

| Purpose | Path (host `https://ap-mc.klikindomaret.com`) |
|---------|-----------------------------------------------|
| Categories | `/assets-klikidmgroceries/api/get/catalog-xpress/api/webapp/category/meta` |
| Products / search | `/assets-klikidmcore/api/get/catalog-xpress/api/webapp/search/result` |

Product fields read: `productId`, `productName`, `imageUrl`, `price`,
`finalPrice`.

## Install

Requires Node.js 18+.

```bash
cd tools/klikindomaret_scraper
npm install          # also downloads Chromium via `playwright install`
```

## ⚠️ Set your store location first

The catalog, availability, and **prices depend on which store you're ordering
from**. The defaults point at a Jakarta store (`storeCode TJKT`). Set them to
**your city's store** or your prices will be wrong:

```bash
node scrape.js --category 123 \
  --store-code YOURCODE --lat -6.20 --lng 106.81 --district 141100100
```

How to find your values: open klikindomaret.com in a normal browser, choose your
delivery location, open DevTools → Network, and read the `storeCode`,
`latitude`, `longitude`, and `districtId` on any `ap-mc.klikindomaret.com`
request. (Or run `node scrape.js --headful --raw` and copy what the site used.)

## Usage

```bash
# 1. List categories (get ids)
node scrape.js --list-categories --store-code YOURCODE --lat .. --lng .. --district ..

# 2. Scrape one category
node scrape.js --category 123 --max 500 --store-code YOURCODE --lat .. --lng .. --district ..

# 3. Walk every category
node scrape.js --all --max 2000 --store-code YOURCODE --lat .. --lng .. --district ..

# 4. Keyword search (param name may differ — see note)
node scrape.js --search indomie --max 200
```

Output lands in `output/`:

- `catalog.json` — full records (`sku, name, imageUrl, price, priceOriginal, unit, available`, plus raw)
- `catalog.csv` — `sku, name, price, priceOriginal, unit, available, imageUrl`

### Options

| Flag | Meaning |
|------|---------|
| `--list-categories` | Print the category tree and exit |
| `--category <id>` | Scrape a single category |
| `--all` | Walk every category (respects `--max`) |
| `--search <kw>` | Keyword search |
| `--search-param <name>` | Query param carrying the keyword (default `key`) |
| `--max <n>` | Stop after n unique products (default 1000) |
| `--page-size <n>` | Products per API page (default 50) |
| `--delay <ms>` | Delay between pages (default 1000) |
| `--store-code / --lat / --lng / --district` | Store location (**set these**) |
| `--out <dir>` | Output directory (default `./output`) |
| `--raw` | Save the first raw API response and exit |
| `--headful` | Show the browser (debug / solve Cloudflare manually) |
| `PROXY_SERVER=...` | Env var: route the browser through a proxy |

## Troubleshooting

- **Everything returns 403 / no products.** Cloudflare didn't clear. Run once
  with `--headful` (you may briefly see the challenge solve itself), and prefer a
  normal/residential IP — datacenter IPs get challenged hard. A residential
  proxy via `PROXY_SERVER` also helps.
- **Prices look wrong.** Wrong store location — set `--store-code/--lat/--lng/--district`.
- **Search returns nothing but categories work.** The keyword parameter name may
  differ on your region's site. Run `node scrape.js --search indomie --raw`,
  open `output/raw-sample.json`, check what the site actually sends, and pass
  `--search-param <name>`. Category browsing (`--category` / `--all`) is the more
  reliable path.
- **Prices/images empty.** Field names changed. `node scrape.js --category <id> --raw`,
  inspect `output/raw-sample.json`, and add the new keys to the candidate lists
  in [`normalize.js`](./normalize.js).

## Importing into the tideview shop

Same as the Alfagift tool: load the catalog into your **own** product table with
your own SKU, your own price (add a margin buffer), and an availability flag you
control. Don't have the Flutter app call Klik Indomaret directly — the online
price/stock won't match the shelf, and Cloudflare will block automated app
traffic anyway. Re-run periodically to refresh names/images.

## Legal & fair use

- Scrapes a third-party site; confirm it's permitted where you operate. You
  confirmed name/image/price scraping is acceptable in your country — this tool
  takes only those fields.
- Defaults are deliberately slow (`--delay 1000`). Don't hammer the site; scrape
  off-peak and cache.
- Prices are **indicative**. Your team pays the in-store shelf price — always
  re-check and keep a margin buffer.
