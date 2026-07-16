#!/usr/bin/env bash
# HyperShots validator: the "cannot be rejected for asset specs" guarantee.
set -euo pipefail
WS="${1:?usage: validate.sh <workspace> [profile] [locale]}"
PROFILE="${2:-iphone-6.9}"
LOCALE="${3:-en}"
KIT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$WS/out/$PROFILE/$LOCALE"

# plain assignment so an unknown profile trips set -e (read <<< "$(...)" would not)
DIMS="$(node "$KIT/scripts/lib/profile-dims.mjs" "$KIT/profiles.json" "$PROFILE")"
read -r _ _ _ OW OH <<< "$DIMS"
[ -n "$OH" ] || { echo "ERROR: bad dims line for profile $PROFILE" >&2; exit 1; }

# IM7 ships one `magick` binary; IM6 (e.g. plain `apt-get install imagemagick`
# on ubuntu-latest) ships separate `convert`/`identify` binaries and no
# `magick` — support both so this passes on a real Linux box, not just CI.
have_magick() { command -v magick >/dev/null 2>&1 || command -v convert >/dev/null 2>&1; }
im_identify() { if command -v magick >/dev/null 2>&1; then magick identify "$@"; else identify "$@"; fi; }
im_convert()  { if command -v magick >/dev/null 2>&1; then magick "$@"; else convert "$@"; fi; }

# image prop reader: sips on macOS, magick/identify elsewhere
props() { # $1=png -> "W H hasAlpha profileDesc"
  if command -v sips >/dev/null 2>&1; then
    local w h a p
    w=$(sips -g pixelWidth  "$1" | awk 'END{print $2}')
    h=$(sips -g pixelHeight "$1" | awk 'END{print $2}')
    a=$(sips -g hasAlpha    "$1" | awk 'END{print $2}')
    p=$(sips -g profile     "$1" 2>/dev/null | sed -n 's/^ *profile: //p'; true)
    echo "$w $h $a ${p:-<nil>}"
  else
    local fmt; fmt=$(im_identify -format "%w %h %A %[icc:description]" "$1" 2>/dev/null)
    echo "$fmt" | awk '{a=($3=="True"||$3=="Blend")?"yes":"no"; printf "%s %s %s %s\n",$1,$2,a,($4==""?"<nil>":$4)}'
  fi
}

shopt -s nullglob
PNGS=("$OUT"/panel-*.png)
# styled alternates (panel-N.styled.png) are spec-checked like any deliverable
# but don't occupy store slots — only clean renders count toward the cap
STORE=0
for f in "${PNGS[@]}"; do
  case "$f" in *.styled.png) ;; *) STORE=$((STORE + 1)) ;; esac
done
STYLED=$(( ${#PNGS[@]} - STORE ))
[ "$STORE" -gt 0 ]  || { echo "FAIL: no PNGs in $OUT" >&2; exit 1; }
[ "$STORE" -le 10 ] || { echo "FAIL: $STORE panels — App Store max is 10 per device size per localization" >&2; exit 1; }

FAILED=0
for f in "${PNGS[@]}"; do
  read -r w h a prof <<< "$(props "$f")"
  ok=1; msgs=()
  # Apple rejects screenshots over 8 MB
  bytes=$(wc -c < "$f" | tr -d ' ')
  [ "$bytes" -le 8388608 ] || { ok=0; msgs+=("${bytes} bytes — over Apple's 8 MB screenshot cap; recompress or simplify the panel"); }
  [ "$w" = "$OW" ] && [ "$h" = "$OH" ] || { ok=0; msgs+=("dims ${w}x${h}, expected ${OW}x${OH}"); }
  # every PNG must carry a clean boxes.json sibling: proof the render pipeline
  # completed (fit + dim checks) for THIS file — validate is self-sufficient
  bj="${f%.png}.boxes.json"
  if [ ! -s "$bj" ]; then
    ok=0; msgs+=("missing/empty $(basename "$bj") — not produced by a clean render")
  elif ! node -e '
      const j=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));
      if(!Array.isArray(j.fitFailures)||j.fitFailures.length)process.exit(1)' "$bj" 2>/dev/null; then
    ok=0; msgs+=("$(basename "$bj") has fitFailures or is unparsable")
  fi
  if [ "$a" = "yes" ]; then
    if have_magick; then
      im_convert "$f" -background white -alpha remove -alpha off "$f"
      msgs+=("alpha flattened (fixed in place)")
    else
      ok=0; msgs+=("HAS ALPHA — App Store rejects; install ImageMagick (brew install imagemagick) or re-render")
    fi
  fi
  case "$prof" in
    "<nil>"|*sRGB*|*"IEC 61966"*) : ;;                       # untagged or sRGB = OK
    *) ok=0; msgs+=("non-sRGB ICC profile '$prof' — re-render with --force-color-profile=srgb") ;;
  esac
  if [ $ok -eq 1 ]; then echo "PASS $(basename "$f") ${w}x${h} alpha:no profile:ok ${msgs[*]:-}"
  else echo "FAIL $(basename "$f"): ${msgs[*]}"; FAILED=1; fi
done
[ $FAILED -eq 0 ] || exit 1
STYLED_NOTE=""
if [ "$STYLED" -gt 0 ]; then STYLED_NOTE=" (+$STYLED styled)"; fi
echo "VALIDATED: $STORE panels$STYLED_NOTE, ${OW}x${OH}, store-compliant"
