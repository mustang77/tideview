#!/usr/bin/env bash
# Deploy web H2O Laundry di VPS: salin webdist repo ke docroot
# LiteSpeed/CyberPanel yang melayani https://app.h2olaundry.com.
# Pakai: sudo ./deploy-web.sh   (setelah git pull)
# Docroot lain? Jalankan: DOCROOT=/path/lain sudo -E ./deploy-web.sh
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
DOCROOT="${DOCROOT:-/home/wca/public_html/app}"

if [ ! -d "$DOCROOT" ]; then
  echo "Docroot tidak ditemukan: $DOCROOT" >&2
  exit 1
fi

cp -r "$REPO/webdist/." "$DOCROOT/"
chown -R "$(stat -c '%U:%G' "$DOCROOT")" "$DOCROOT"
echo "Web terpasang ke $DOCROOT"
echo "Versi: $(md5sum "$DOCROOT/main.dart.js" | cut -c1-12)"
