#!/usr/bin/env bash
# Initialize a HyperShots workspace (default: .shots/) in the user's project.
set -euo pipefail
WS="${1:-.shots}"
KIT="$(cd "$(dirname "$0")/.." && pwd)"
[ -e "$WS/brief.md" ] && { echo "ERROR: $WS already scaffolded"; exit 1; }
mkdir -p "$WS/panels" "$WS/assets" "$WS/out"
cp "$KIT/assets/frame.css" "$KIT/assets/fit.js" "$KIT/assets/fonts.css" "$WS/"
rm -rf "$WS/fonts"   # recovery from a mid-run failure: avoid fonts/fonts nesting
cp -R "$KIT/assets/fonts" "$WS/fonts"
cp "$KIT/profiles.json" "$WS/"
cat > "$WS/theme.css" <<'EOF'
/* Per-app theme layer — derive from the app's brand (see references/create.md).
   REQUIRED tokens consumed by frame.css: */
:root{
  --paper:#f5f5f2;      /* panel background */
  --paper-hi:#ffffff;   /* card / chip surface (also sticker borders) */
  --ink:#111111;        /* primary text */
  --mid:#555555;        /* secondary text */
  --rule:rgba(0,0,0,.15);
  --accent:#333333;     /* brand accent (eyebrow, highlights) */
  --badge-bg:#eeeeee;   /* gradeBadge surface */
  --badge-ink:#333333;  /* gradeBadge glyph */
  --font-sans:'Inter Tight',system-ui,sans-serif;
  --font-mono:'IBM Plex Mono',ui-monospace,monospace;
  /* optional, set-wide: --device-top-ratio: 0.33;  sanctioned 0.28–0.36 — see gotchas.md */
}
EOF
cat > "$WS/brief.md" <<'EOF'
# Screenshot brief
- App name / one-line positioning:
- Captures provided (files in assets/):
- Panel count + per-panel headline & sub:
- Stickers / generated assets wanted (or none):
- Device profile(s): iphone-6.9
- Locales: en
EOF
echo "scaffolded $WS (panels/, theme.css, brief.md, kit copies)"
