'use strict';

/**
 * Turns a raw Klik Indomaret API product object into the flat shape the
 * tideview shop needs: { sku, name, imageUrl, price, priceOriginal, unit, available, raw }.
 * (Same normalizer shape as the Alfagift tool; Klik Indomaret's fields —
 * productId / productName / imageUrl / price / finalPrice — are already covered
 * by the candidate lists below.)
 *
 * Klik Indomaret is a live third-party site and can rename its JSON fields at any
 * time, so nothing here hard-codes a single field name. Each value is resolved
 * by trying a list of likely keys in priority order. When the site changes,
 * you usually only need to add one more candidate to the relevant list below
 * (run the scraper with --raw first to see the real field names — see README).
 */

// Pull the first defined, non-empty value for any of `keys` out of `obj`.
function pick(obj, keys) {
  for (const k of keys) {
    const v = obj[k];
    if (v !== undefined && v !== null && v !== '') return v;
  }
  return undefined;
}

// Coerce Alfagift price fields (numbers, or strings like "Rp12.500") to an integer rupiah amount.
function toRupiah(value) {
  if (value === undefined || value === null) return undefined;
  if (typeof value === 'number' && Number.isFinite(value)) return Math.round(value);
  const digits = String(value).replace(/[^\d]/g, '');
  if (!digits) return undefined;
  return parseInt(digits, 10);
}

const SKU_KEYS = ['productId', 'productCode', 'plu', 'id', 'sku', 'itemId', 'articleId'];
const NAME_KEYS = ['productName', 'name', 'title', 'productTitle', 'displayName'];
const IMAGE_KEYS = ['image', 'imageUrl', 'productImage', 'thumbnail', 'thumbnailUrl', 'imageThumbnail', 'imgUrl'];
const PRICE_KEYS = ['finalPrice', 'priceDisc', 'priceAfterDiscount', 'sellPrice', 'price', 'normalPrice', 'productPrice'];
const PRICE_ORIGINAL_KEYS = ['normalPrice', 'basePrice', 'strikePrice', 'priceBeforeDiscount', 'originalPrice', 'price'];
const UNIT_KEYS = ['uom', 'unit', 'unitName', 'packaging', 'satuan'];
const STOCK_KEYS = ['availableStock', 'stock', 'stockQty', 'availableQty', 'qtyStock'];
const AVAILABLE_FLAG_KEYS = ['isAvailable', 'available', 'inStock', 'isActive'];

function normalizeProduct(raw) {
  if (!raw || typeof raw !== 'object') return null;

  const name = pick(raw, NAME_KEYS);
  if (!name) return null; // without a name it isn't a usable catalog row

  let image = pick(raw, IMAGE_KEYS);
  if (image && typeof image === 'string' && image.startsWith('//')) image = 'https:' + image;

  const price = toRupiah(pick(raw, PRICE_KEYS));
  const priceOriginal = toRupiah(pick(raw, PRICE_ORIGINAL_KEYS));

  const stock = pick(raw, STOCK_KEYS);
  const flag = pick(raw, AVAILABLE_FLAG_KEYS);
  let available;
  if (typeof flag === 'boolean') available = flag;
  else if (stock !== undefined) available = toRupiah(stock) > 0;
  else available = undefined; // unknown

  return {
    sku: pick(raw, SKU_KEYS) !== undefined ? String(pick(raw, SKU_KEYS)) : undefined,
    name: String(name).trim(),
    imageUrl: image,
    price,
    priceOriginal: priceOriginal !== price ? priceOriginal : undefined,
    unit: pick(raw, UNIT_KEYS),
    available,
    raw, // kept so nothing is silently dropped; strip it before shipping to the app if you want smaller files
  };
}

/**
 * Alfagift wraps product lists in an envelope that also varies by endpoint
 * ({products:[...]}, {data:{products:[...]}}, {productList:[...]}, a bare
 * array, etc). Walk the object and collect every array of objects that look
 * like products (i.e. that have one of the NAME_KEYS).
 */
function extractProducts(payload) {
  const found = [];
  const seen = new Set();
  const looksLikeProduct = (o) =>
    o && typeof o === 'object' && !Array.isArray(o) && NAME_KEYS.some((k) => o[k] !== undefined);

  const walk = (node, depth) => {
    if (depth > 6 || node === null || typeof node !== 'object') return;
    if (Array.isArray(node)) {
      if (node.length && looksLikeProduct(node[0])) {
        for (const item of node) if (looksLikeProduct(item)) found.push(item);
      } else {
        for (const item of node) walk(item, depth + 1);
      }
      return;
    }
    for (const key of Object.keys(node)) walk(node[key], depth + 1);
  };
  walk(payload, 0);

  // De-dupe by SKU (fall back to name) so overlapping category/search hits collapse.
  const unique = [];
  for (const p of found) {
    const key = String(pick(p, SKU_KEYS) ?? pick(p, NAME_KEYS));
    if (seen.has(key)) continue;
    seen.add(key);
    unique.push(p);
  }
  return unique;
}

module.exports = { normalizeProduct, extractProducts, toRupiah, pick };
