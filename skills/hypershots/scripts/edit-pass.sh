#!/usr/bin/env bash
# Optional style grade: GPT Image 2 edit over a finished render, with the
# protected regions re-composited from the original (see references/edit-filter.md).
# Usage:
#   edit-pass.sh <workspace> <profile> <locale> <panel-N> "<style prompt>" [protected|full]
set -euo pipefail
WS="${1:?usage: edit-pass.sh <workspace> <profile> <locale> <panel-N> \"<style prompt>\" [protected|full]}"
PROFILE="$2"; LOCALE="$3"; PANEL="$4"; STYLE="$5"; MODE="${6:-protected}"
KIT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$WS/out/$PROFILE/$LOCALE"; SRC="$OUT/$PANEL.png"; BOX="$OUT/$PANEL.boxes.json"

[ -f "$SRC" ] || { echo "ERROR: $SRC not rendered" >&2; exit 1; }
[ -f "$BOX" ] || { echo "ERROR: $BOX missing — re-render first" >&2; exit 1; }
case "$MODE" in protected|full) ;; *) echo "ERROR: mode must be 'protected' or 'full', got '$MODE'" >&2; exit 1 ;; esac
command -v genmedia >/dev/null || { echo "ERROR: style grade needs genmedia (see SKILL.md prerequisites)" >&2; exit 1; }
command -v magick   >/dev/null || { echo "ERROR: style grade needs ImageMagick (ImageMagick 7 'magick' binary required)" >&2; exit 1; }

# watchdog: kill a wedged upload/edit after 300s (same pattern as render.sh)
guard() { perl -e 'alarm 300; exec @ARGV' -- "$@"; }

# pull one field out of genmedia --json output (never grep JSON)
json_field() {
  node -e '
    let s = "";
    process.stdin.on("data", d => s += d).on("end", () => {
      let j; try { j = JSON.parse(s); } catch (e) {
        console.error("ERROR: unparsable genmedia output: " + s); process.exit(1);
      }
      const v = j[process.argv[1]];
      if (!v) { console.error("ERROR: no " + process.argv[1] + " in genmedia output: " + s); process.exit(1); }
      console.log(v);
    })' "$1"
}

DIMS="$(node "$KIT/scripts/lib/profile-dims.mjs" "$KIT/profiles.json" "$PROFILE")"
read -r _ _ SCALE OW OH <<< "$DIMS"
[ -n "$OH" ] || { echo "ERROR: bad dims line for profile $PROFILE" >&2; exit 1; }

# gpt-image-2 canvases must be multiples of 16 — store dims never are
# (1290x2796 etc). Edit at the nearest-16 canvas, resample back to exact.
EW=$(( (OW + 8) / 16 * 16 )); EH=$(( (OH + 8) / 16 * 16 ))

# temps live OUTSIDE out/ — anything matching out/**/panel-*.png without a
# clean boxes.json sibling would fail a later validate.sh run
TMPD="$(mktemp -d "${TMPDIR:-/tmp}/hypershots-edit.XXXXXX")"
trap 'rm -rf "$TMPD"' EXIT
MASK="$TMPD/mask.png"; FEATHER="$TMPD/feather.png"; RAW="$TMPD/styled-raw.png"
STYLED="$OUT/$PANEL.styled.png"

# build masks BEFORE any upload — a zero-protect-boxes authoring bug must
# fail here, before a single byte (or cent) goes to the API
if [ "$MODE" = "protected" ]; then
  node "$KIT/scripts/make-mask.mjs" "$BOX" "$OW" "$OH" "$SCALE" "$MASK" "$FEATHER"
fi

echo "uploading $SRC ..."
SRC_URL="$(guard genmedia upload "$SRC" --json | json_field cdn_url)"

# image_urls is array<string> and image_size an ImageSize object — genmedia
# passes flag values through verbatim, so hand it JSON literals
RUN_ARGS=(openai/gpt-image-2/edit
  --image_urls "[\"$SRC_URL\"]"
  --prompt "$STYLE"
  --image_size "{\"width\":$EW,\"height\":$EH}"
  --quality high
  --output_format png
  --download "$RAW"
  --json)

if [ "$MODE" = "protected" ]; then
  echo "uploading mask ..."
  MASK_URL="$(guard genmedia upload "$MASK" --json | json_field cdn_url)"
  RUN_ARGS+=(--mask_url "$MASK_URL")
fi

echo "editing at ${EW}x${EH} ($MODE mode) ..."
RUN_JSON="$(guard genmedia run "${RUN_ARGS[@]}")"
[ -s "$RAW" ] || { echo "ERROR: edit returned no image — genmedia output:" >&2; echo "$RUN_JSON" >&2; exit 1; }

# back to the exact store canvas
magick "$RAW" -resize "${OW}x${OH}!" -alpha off "$STYLED"

if [ "$MODE" = "protected" ]; then
  # THE pixel guarantee: the model re-generates the whole canvas, so composite
  # the protected regions back from the original through the feathered mask
  magick "$STYLED" "$SRC" "$FEATHER" -composite -alpha off "$STYLED"
fi

# boxes sibling for the styled PNG (same geometry as the clean render) so
# validate.sh — which requires proof-of-clean-render per PNG — can bless it
cp "$BOX" "$OUT/$PANEL.styled.boxes.json"

echo "styled: $STYLED (${OW}x${OH}, $MODE mode)"
echo "clean render untouched: $SRC"
echo "if the styled panel ships, run validate.sh on it first"
