#!/usr/bin/env bash
# Set makeover: style-grade a whole rendered set in one consistent pass.
# The lowest-numbered panel is graded first (the anchor); every other panel
# is graded with the anchor's styled output as a style reference image, so
# the set comes back in ONE look instead of N drifting interpretations.
# Usage:
#   grade-set.sh <workspace> <profile> <locale> "<style prompt>" [protected|full]
set -euo pipefail
WS="${1:?usage: grade-set.sh <workspace> <profile> <locale> \"<style prompt>\" [protected|full]}"
PROFILE="${2:?usage: grade-set.sh <workspace> <profile> <locale> \"<style prompt>\" [protected|full]}"
LOCALE="${3:?usage: grade-set.sh <workspace> <profile> <locale> \"<style prompt>\" [protected|full]}"
STYLE="${4:?usage: grade-set.sh <workspace> <profile> <locale> \"<style prompt>\" [protected|full]}"
MODE="${5:-protected}"
KIT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$WS/out/$PROFILE/$LOCALE"

case "$MODE" in protected|full) ;; *) echo "ERROR: mode must be 'protected' or 'full', got '$MODE'" >&2; exit 1 ;; esac
command -v genmedia >/dev/null || { echo "ERROR: style grade needs genmedia (see SKILL.md prerequisites)" >&2; exit 1; }
command -v magick   >/dev/null || { echo "ERROR: style grade needs ImageMagick (ImageMagick 7 'magick' binary required)" >&2; exit 1; }

# collect the rendered set (clean renders only), lowest panel number first
shopt -s nullglob
NUMS=()
for f in "$OUT"/panel-*.png; do
  case "$f" in *.styled.png) continue ;; esac
  n="${f##*/panel-}"; n="${n%.png}"
  NUMS+=("$n")
done
[ ${#NUMS[@]} -gt 0 ] || { echo "ERROR: no rendered panels in $OUT — run render.sh first" >&2; exit 1; }
SORTED="$(printf '%s\n' "${NUMS[@]}" | sort -n)"
# every panel needs its boxes.json BEFORE any upload — fail free, not mid-set
while IFS= read -r n; do
  [ -f "$OUT/panel-$n.boxes.json" ] || { echo "ERROR: $OUT/panel-$n.boxes.json missing — re-render first" >&2; exit 1; }
done <<< "$SORTED"

TOTAL=${#NUMS[@]}
DONE=()
# on failure, say how far we got: styled outputs are non-destructive, so a
# re-run resumes safely (edit-pass.sh overwrites styled outputs)
report_progress() {
  rc=$?
  if [ $rc -ne 0 ]; then
    if [ ${#DONE[@]} -gt 0 ]; then
      echo "grade-set stopped: ${#DONE[@]}/$TOTAL panels styled (${DONE[*]})" >&2
      echo "styled outputs already written are kept — re-run grade-set.sh to resume (styled files are simply overwritten)" >&2
    else
      echo "grade-set stopped: 0/$TOTAL panels styled — nothing was written" >&2
    fi
  fi
}
trap report_progress EXIT

FIRST="$(head -n1 <<< "$SORTED")"
ANCHOR="$OUT/panel-$FIRST.styled.png"

echo "[1/$TOTAL] grading anchor panel-$FIRST ($MODE mode) ..."
bash "$KIT/scripts/edit-pass.sh" "$WS" "$PROFILE" "$LOCALE" "panel-$FIRST" "$STYLE" "$MODE"
DONE+=("panel-$FIRST")

i=1
while IFS= read -r n; do
  [ "$n" = "$FIRST" ] && continue
  i=$((i + 1))
  echo "[$i/$TOTAL] grading panel-$n against the anchor ..."
  bash "$KIT/scripts/edit-pass.sh" "$WS" "$PROFILE" "$LOCALE" "panel-$n" "$STYLE" "$MODE" "$ANCHOR"
  DONE+=("panel-$n")
done <<< "$SORTED"

node "$KIT/scripts/make-review.mjs" "$WS" "$PROFILE" || echo "WARN: review page regeneration failed"

echo "set makeover done: ${#DONE[@]} panels styled in $OUT (anchor: panel-$FIRST)"
echo "review: $WS/out/$PROFILE/review.html (clean/styled toggle)"
echo "clean renders remain the store deliverables unless the user picks the styled set — validate.sh the styled files before shipping them"
