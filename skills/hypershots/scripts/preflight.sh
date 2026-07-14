#!/usr/bin/env bash
# Dependency report. Exit 0 always — SKILL.md decides what to do about gaps.
set -uo pipefail
ok(){ echo "OK   $1"; }; miss(){ echo "MISS $1 — $2"; }
if [ -n "${CHROME:-}" ] && [ -x "$CHROME" ]; then ok "chrome (\$CHROME)"
elif [ -x "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" ]; then ok "chrome (macOS app)"
elif command -v google-chrome >/dev/null || command -v chromium >/dev/null || command -v chromium-browser >/dev/null; then ok "chrome (PATH)"
else miss "chrome" "REQUIRED. Install Chrome/Chromium or set \$CHROME"; fi
command -v node >/dev/null && ok "node" || miss "node" "REQUIRED for render/validate helpers"
command -v magick >/dev/null && ok "imagemagick" \
  || miss "imagemagick" "optional: alpha flattening + style-edit compositing (brew install imagemagick)"
if command -v genmedia >/dev/null; then
  # 10s alarm: a wedged genmedia must not hang the report; flatten to one line
  ok "genmedia ($(perl -e 'alarm 10; exec @ARGV' -- genmedia --version 2>/dev/null | tr -d '\n' | head -c 60)...)"
else
  miss "genmedia" "optional: AI assets + style grade. Offer: npm i -g genmedia && genmedia setup"
fi
command -v sips >/dev/null && ok "sips" || echo "INFO sips absent (non-macOS) — validator uses magick"
exit 0
