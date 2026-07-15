#!/usr/bin/env bash
# Vendor a Google Fonts family into a HyperShots workspace: download latin +
# latin-ext woff2 subsets, append matching @font-face rules to <ws>/fonts.css
# (unicode-range from the css2 response, font-display:block), fetch the license.
# Same technique the kit's own vendored fonts were built with: css2 + Chrome UA
# so Google serves subsetted woff2 with labeled unicode-range blocks.
# Idempotent-ish: existing woff2 files are kept; @font-face blocks aren't duplicated.
set -euo pipefail

usage='usage: fetch-fonts.sh <workspace> "<Family Name>" [weights, default "400;700"]'
WS="${1:?$usage}"
FAMILY="${2:?$usage}"
WEIGHTS="${3:-400;700}"

[ -f "$WS/fonts.css" ] || { echo "ERROR: $WS/fonts.css not found — scaffold the workspace first (scaffold.sh)" >&2; exit 1; }
case "$WEIGHTS" in
  *[!0-9\;.]*|"") echo "ERROR: weights must look like \"400;700\" or \"400..900\" (got: $WEIGHTS)" >&2; exit 1 ;;
esac
mkdir -p "$WS/fonts"

# Chrome UA => css2 answers with woff2 + per-subset unicode-range blocks
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36"
FAM_Q="${FAMILY// /+}"
SLUG="$(printf '%s' "$FAMILY" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9')"      # google/fonts repo dir (e.g. playfairdisplay)
FSLUG="$(printf '%s' "$FAMILY" | tr '[:upper:]' '[:lower:]' | tr -s ' ' '-')"        # filename slug (e.g. playfair-display)
CSS_URL="https://fonts.googleapis.com/css2?family=${FAM_Q}:wght@${WEIGHTS}&display=swap"

TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT
code="$(curl -sS -A "$UA" -o "$TMPD/css2.css" -w '%{http_code}' "$CSS_URL")"
if [ "$code" != "200" ]; then
  echo "ERROR: css2 returned HTTP $code — unknown family \"$FAMILY\" or bad weights \"$WEIGHTS\"?" >&2
  echo "       tried: $CSS_URL" >&2
  exit 1
fi

# parse the labeled subset blocks -> subset<TAB>weight<TAB>style<TAB>url<TAB>unicode-range
node -e '
  const fs = require("fs");
  const css = fs.readFileSync(process.argv[1], "utf8");
  const re = /\/\*\s*(latin-ext|latin)\s*\*\/\s*@font-face\s*\{([^}]*)\}/g;
  const rows = []; let m;
  while ((m = re.exec(css))) {
    const [, subset, b] = m;
    const get = k => { const mm = b.match(new RegExp(k + ":\\s*([^;]+);")); return mm ? mm[1].trim() : ""; };
    const url = (b.match(/url\((\S+?)\)/) || [])[1] || "";
    if (!url || !get("font-weight") || !get("unicode-range")) {
      console.error("ERROR: malformed " + subset + " block in css2 response"); process.exit(1);
    }
    rows.push([subset, get("font-weight"), get("font-style") || "normal", url, get("unicode-range")].join("\t"));
  }
  if (!rows.length) { console.error("ERROR: no latin/latin-ext blocks in css2 response"); process.exit(1); }
  console.log(rows.join("\n"));
' "$TMPD/css2.css" > "$TMPD/rows.tsv"

# one comment header per family in fonts.css
if ! grep -qF "font-family:'$FAMILY'" "$WS/fonts.css"; then
  printf "\n/* %s — vendored by fetch-fonts.sh (Google Fonts css2, latin + latin-ext, OFL notice in fonts/) */\n" "$FAMILY" >> "$WS/fonts.css"
fi

added=0
while IFS=$'\t' read -r subset weight style url urange; do
  wtag="${weight// /-}"                       # "700" or "400-900" (variable)
  ext=""; [ "$subset" = "latin-ext" ] && ext="-ext"
  fname="${FSLUG}-${wtag}${ext}.woff2"
  if [ -f "$WS/fonts/$fname" ]; then
    echo "exists: fonts/$fname (download skipped)"
  else
    curl -fsS -A "$UA" -o "$TMPD/dl.woff2" "$url"
    mv "$TMPD/dl.woff2" "$WS/fonts/$fname"
    echo "fetched: fonts/$fname ($subset $weight)"
  fi
  if grep -qF "fonts/$fname" "$WS/fonts.css"; then
    echo "fonts.css: block for $fname already present (append skipped)"
  else
    printf "@font-face{font-family:'%s';src:url('fonts/%s') format('woff2');font-weight:%s;font-style:%s;font-display:block;unicode-range:%s}\n" \
      "$FAMILY" "$fname" "$weight" "$style" "$urange" >> "$WS/fonts.css"
    added=$((added + 1))
  fi
done < "$TMPD/rows.tsv"

# license: OFL first, Apache fallback — keep the notice next to the woff2
LIC="$WS/fonts/OFL-${FAMILY// /}.txt"
LIC_AP="$WS/fonts/LICENSE-${FAMILY// /}.txt"
if [ -f "$LIC" ] || [ -f "$LIC_AP" ]; then
  echo "license: already present"
elif curl -fsS -A "$UA" -o "$TMPD/lic.txt" "https://raw.githubusercontent.com/google/fonts/main/ofl/$SLUG/OFL.txt"; then
  mv "$TMPD/lic.txt" "$LIC"; echo "license: fonts/$(basename "$LIC") (OFL)"
elif curl -fsS -A "$UA" -o "$TMPD/lic.txt" "https://raw.githubusercontent.com/google/fonts/main/apache/$SLUG/LICENSE.txt"; then
  mv "$TMPD/lic.txt" "$LIC_AP"; echo "license: fonts/$(basename "$LIC_AP") (Apache)"
else
  echo "*** WARNING: could not fetch a license for \"$FAMILY\" (tried ofl/$SLUG/OFL.txt and apache/$SLUG/LICENSE.txt). ***" >&2
  echo "*** Fonts are vendored WITHOUT their notice — find and add the license to $WS/fonts/ before shipping. ***" >&2
fi

echo "OK: $FAMILY ($WEIGHTS) vendored — $added @font-face block(s) appended to $WS/fonts.css"
echo "Next: point theme.css at the family, e.g. --font-sans:'$FAMILY',system-ui,sans-serif;"
