# HyperShots Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the `hypershots` agent skill — spec-reliable, multi-language App Store screenshots from deterministic HTML/CSS with optional AI-generated assets — as a standalone open-source repo installable via `npx skills add hypersocialinc/hypershots`.

**Architecture:** A skill repo (`skills/hypershots/`) shipping an immutable geometric frame kit (`frame.css` + `fit.js` + vendored fonts + `profiles.json`), operational scripts (preflight/scaffold/render/validate/edit-pass), reference docs for four gears (create/revise/translate/style-edit), and an annotated Spotless example set. Agents author bespoke panel HTML per app into a scaffolded `.shots/` workspace in the *user's* repo; headless Chrome renders exact store canvases; a validator enforces Apple's specs; genmedia (fal's public CLI) is a consent-gated soft dependency for generative assets only.

**Tech Stack:** Bash + Node (no npm deps at runtime), headless Chrome/Chromium, sips + ImageMagick, genmedia CLI (optional), gray-matter (dev-only, for the skill validator), GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-07-13-hypershots-skill-design.md` (rev 2). Working dir for all tasks: the repo root (this repository).

---

## File structure (locked by this plan)

```
hypershots/
  .gitignore  LICENSE  package.json  README.md
  .github/workflows/validate.yml
  scripts/validate-skills.mjs            # repo CI (copied from agent-skills)
  tests/
    fixture/panel-fixture.html  fixture/theme.css
    run-tests.sh
  skills/hypershots/
    SKILL.md
    agents/openai.yaml
    profiles.json
    assets/frame.css  assets/fit.js  assets/fonts.css
    assets/fonts/*.woff2 + OFL-InterTight.txt + OFL-IBMPlexMono.txt
    references/store-specs.md  create.md  revise.md  translate.md
               i18n.md  edit-filter.md  asset-recipes.md  gotchas.md
    scripts/preflight.sh  scaffold.sh  render.sh  validate.sh
            translate-inject.mjs  make-mask.mjs  edit-pass.sh
    examples/spotless/README.md  brief.md  theme.css  panels/panel-*.html
              contact-sheet.png
```

Every skill script takes the workspace dir as its first argument and is
path-independent (resolves its own location via `$(dirname "$0")`).

---

### Task 1: Repo base (gitignore, LICENSE, package.json)

**Files:**
- Create: `.gitignore`, `LICENSE`, `package.json`

- [ ] **Step 1: Write `.gitignore`**

```gitignore
node_modules/
.DS_Store
*.log
# rendered output inside example/test workspaces (contact sheets are committed explicitly)
tests/fixture/out/
```

- [ ] **Step 2: Write `LICENSE` (MIT)**

```text
MIT License

Copyright (c) 2026 HyperSocial Incorporated

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

---
Vendored fonts (skills/hypershots/assets/fonts/) are licensed separately under
the SIL Open Font License 1.1 — see OFL-InterTight.txt and OFL-IBMPlexMono.txt
in that directory.
```

- [ ] **Step 3: Write `package.json`** (dev-only dep for the skill validator)

```json
{
  "name": "hypershots-repo",
  "private": true,
  "type": "module",
  "scripts": {
    "validate": "node scripts/validate-skills.mjs",
    "test": "bash tests/run-tests.sh"
  },
  "devDependencies": {
    "gray-matter": "^4.0.3"
  }
}
```

- [ ] **Step 4: Commit**

```bash
git add .gitignore LICENSE package.json
git commit -m "chore: repo base (MIT license, package.json, gitignore)"
```

---

### Task 2: Skill skeleton + frontmatter (installer contract)

**Files:**
- Create: `skills/hypershots/SKILL.md` (skeleton — full content in Task 12)
- Create: `skills/hypershots/agents/openai.yaml`

- [ ] **Step 1: Write skeleton `SKILL.md`** — frontmatter is the installer contract; `name` MUST equal the directory name or `npx skills` silently drops the skill.

```markdown
---
name: hypershots
description: "Generate spec-reliable App Store screenshots from deterministic HTML/CSS panels, with optional AI-generated sticker assets and style grading. Use when the user wants App Store / store listing screenshots, marketing panels with device frames, screenshot localization or translation ('translate my screenshots'), or asks about Apple screenshot sizes and specs. Not for general image generation, social graphics, or capturing in-app screenshots from a simulator."
---

# HyperShots

(Full authoring guide lands in a later task. Layout under construction.)
```

- [ ] **Step 2: Write `agents/openai.yaml`** (catalog convention for Codex)

```yaml
interface:
  display_name: HyperShots
  short_description: Spec-reliable App Store screenshots from deterministic HTML + optional AI assets.
  default_prompt: Create App Store screenshots for my app using the hypershots skill. Ask me the brief questionnaire first.
```

- [ ] **Step 3: Commit**

```bash
git add skills/
git commit -m "feat: skill skeleton with installer frontmatter + openai.yaml"
```

---

### Task 3: Repo CI — skill validator

**Files:**
- Create: `scripts/validate-skills.mjs` (copy from the catalog repo)
- Create: `.github/workflows/validate.yml`

- [ ] **Step 1: Copy the validator from the catalog repo**

Run: `cp <catalog-repo>/scripts/validate-skills.mjs scripts/validate-skills.mjs`

Read the copied file; if it hardcodes the catalog repo's paths, adjust only the skills-dir constant so it scans `skills/` relative to the repo root (keep the frontmatter rules identical: `name` matches dir, non-empty `description`).

- [ ] **Step 2: Install dev dep and run the validator**

Run: `npm install && npm run validate`
Expected: PASS — 1 skill (`hypershots`) valid.

- [ ] **Step 3: Write `.github/workflows/validate.yml`**

```yaml
name: validate
on: [push, pull_request]
jobs:
  skills:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 20 }
      - run: npm install
      - run: npm run validate
  render:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: browser-actions/setup-chrome@v1
      - run: sudo apt-get update && sudo apt-get install -y imagemagick
      - run: CHROME="$(which chrome)" bash tests/run-tests.sh
```

(The `render` job will fail until Task 8 lands `tests/run-tests.sh`; that's fine — this repo isn't pushed until the end.)

- [ ] **Step 4: Commit**

```bash
git add scripts/ .github/ package-lock.json
git commit -m "ci: skill frontmatter validator + render test workflow"
```

---

### Task 4: profiles.json + vendored fonts

**Files:**
- Create: `skills/hypershots/profiles.json`
- Create: `skills/hypershots/assets/fonts/` (woff2 + OFL notices), `skills/hypershots/assets/fonts.css`

- [ ] **Step 1: Write `profiles.json`** — verified arithmetic: css × scale = exact store canvas.

```json
{
  "iphone-6.9": { "css": [430, 932], "scale": 3, "out": [1290, 2796], "class": "iphone", "note": "default; the only REQUIRED iPhone size" },
  "iphone-6.9-alt": { "css": [440, 956], "scale": 3, "out": [1320, 2868], "class": "iphone" },
  "iphone-6.5": { "css": [428, 926], "scale": 3, "out": [1284, 2778], "class": "iphone", "note": "legacy slot, still accepted" },
  "ipad-13": { "css": [1032, 1376], "scale": 2, "out": [2064, 2752], "class": "ipad", "note": "separate authoring pass — do not re-render iphone panels" }
}
```

- [ ] **Step 2: Download variable-font woff2 files** (Google Fonts serves woff2 to a Chrome UA; variable fonts cover all weights in one file per style)

```bash
cd skills/hypershots/assets/fonts
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36"
curl -s -A "$UA" "https://fonts.googleapis.com/css2?family=Inter+Tight:ital,wght@0,400..900;1,400..900&display=swap" -o it.css
curl -s -A "$UA" "https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;500;600&display=swap" -o pm.css
grep -oE 'https://[^)]+\.woff2' it.css pm.css | sed 's/^[^:]*://' | sort -u > urls.txt
# download each; name by hash-suffix is fine, we re-declare @font-face ourselves
i=0; while read -r u; do i=$((i+1)); curl -s "$u" -o "font-$i.woff2"; done < urls.txt
ls -la *.woff2
```

Then inspect `it.css`/`pm.css` to see which URL maps to which family/style, and rename to: `InterTight-var.woff2`, `InterTight-italic-var.woff2`, `IBMPlexMono-400.woff2`, `IBMPlexMono-500.woff2`, `IBMPlexMono-600.woff2`. Note: Google may serve per-script subsets (multiple URLs per family) — keep only the `latin` subset files (the css2 response labels each block with `/* latin */`). Delete `it.css pm.css urls.txt` and any leftover `font-*.woff2`.

- [ ] **Step 3: Fetch OFL notices**

```bash
curl -s https://raw.githubusercontent.com/google/fonts/main/ofl/intertight/OFL.txt -o OFL-InterTight.txt
curl -s https://raw.githubusercontent.com/google/fonts/main/ofl/ibmplexmono/OFL.txt -o OFL-IBMPlexMono.txt
head -3 OFL-InterTight.txt OFL-IBMPlexMono.txt   # sanity: real OFL text, not a 404 page
```

- [ ] **Step 4: Write `skills/hypershots/assets/fonts.css`**

```css
/* Vendored fonts (SIL OFL 1.1 — see fonts/OFL-*.txt). Local @font-face so
   renders are offline-deterministic: no Google Fonts network fetch, no silent
   fallback under --virtual-time-budget, no upstream metric drift. */
@font-face{font-family:'Inter Tight';src:url('fonts/InterTight-var.woff2') format('woff2');font-weight:400 900;font-style:normal;font-display:block}
@font-face{font-family:'Inter Tight';src:url('fonts/InterTight-italic-var.woff2') format('woff2');font-weight:400 900;font-style:italic;font-display:block}
@font-face{font-family:'IBM Plex Mono';src:url('fonts/IBMPlexMono-400.woff2') format('woff2');font-weight:400;font-display:block}
@font-face{font-family:'IBM Plex Mono';src:url('fonts/IBMPlexMono-500.woff2') format('woff2');font-weight:500;font-display:block}
@font-face{font-family:'IBM Plex Mono';src:url('fonts/IBMPlexMono-600.woff2') format('woff2');font-weight:600;font-display:block}
```

- [ ] **Step 5: Commit**

```bash
cd <hypershots-repo>
git add skills/hypershots/profiles.json skills/hypershots/assets/
git commit -m "feat: device profiles + vendored OFL fonts (offline-deterministic renders)"
```

---

### Task 5: frame.css (geometric contract) — the heart of the kit

**Files:**
- Create: `skills/hypershots/assets/frame.css`

Design rules (from spec): geometry only — **no brand tokens**; sized by per-profile
CSS variables so one panel re-renders across near-aspect iPhone profiles without
gutters; device anchors relative to panel dims; theme tokens are *consumed* here
but *defined* in the workspace `theme.css`.

- [ ] **Step 1: Write `frame.css`**

```css
/* HyperShots frame kit — GEOMETRIC CONTRACT. Do not put brand styling here.
   Theme tokens (--paper, --ink, --accent, fonts...) are defined per-app in the
   workspace theme.css. Panel dims come from the per-profile profile.css that
   render.sh generates: --panel-w / --panel-h.

   IMMUTABLE (agents must not restyle): .panel dims, .device geometry, .screen
   aspect, .di, .statusbar positions. VARIABLE: everything visual via theme
   tokens, plus sticker placement via inline left/top/width/transform. */

:root{
  --panel-w:428px; --panel-h:926px;      /* overridden by profile.css */
  --device-w-ratio:0.80;                 /* device width  / panel width  */
  --device-top-ratio:0.330;              /* device top    / panel height */
  --device-aspect:2.0906;                /* device height / width (715/342) */
  --device-top:calc(var(--panel-h) * var(--device-top-ratio));
}
*{box-sizing:border-box;margin:0;padding:0;-webkit-font-smoothing:antialiased;text-rendering:geometricPrecision}

.panel{
  position:relative;overflow:hidden;
  width:var(--panel-w);height:var(--panel-h);
  background:var(--paper,#f5f5f2);
  font-family:var(--font-sans,system-ui,-apple-system,sans-serif);
}

/* ---- copy block above the device ---- */
.wrap{position:relative;z-index:2;padding:42px 34px 0}
.eyebrow{display:flex;align-items:center;gap:14px}
.eyebrow b{font-family:var(--font-mono,ui-monospace,Menlo,monospace);font-weight:500;
  font-size:12px;letter-spacing:2.4px;text-transform:uppercase;color:var(--accent,#444);white-space:nowrap}
.eyebrow i{flex:1;height:1px;background:var(--rule,rgba(0,0,0,.16))}
.headline{font-weight:800;font-size:45px;line-height:1.02;letter-spacing:-1.3px;color:var(--ink,#111);margin-top:16px}
.sub{font-weight:500;font-size:19.5px;line-height:1.25;color:var(--mid,#555);margin-top:12px}

/* ---- device: FIXED geometry, identical on every panel of a set ----
   Screen aspect stays ~0.460 (matches a real 1206x2622 capture) at any
   profile because height derives from width via --device-aspect. */
.stage{position:absolute;inset:0;z-index:1}
.device{position:absolute;left:50%;top:var(--device-top);transform:translateX(-50%);
  width:calc(var(--panel-w) * var(--device-w-ratio));
  height:calc(var(--panel-w) * var(--device-w-ratio) * var(--device-aspect));
  background:#0a0a0c;border-radius:60px;padding:12px;
  box-shadow:0 34px 70px -22px rgba(0,0,0,.5), 0 0 0 2px #000 inset, 0 1px 0 rgba(255,255,255,.08) inset}
.screen{position:relative;width:100%;height:100%;border-radius:47px;overflow:hidden;background:var(--paper,#f5f5f2)}
.shot{position:absolute;inset:0;width:100%;height:100%;object-fit:cover;object-position:top center;display:block}

/* Dynamic Island + status bar — ONLY for hand-built screens. Real simulator
   captures already contain the device's own status bar + island: never stack
   these over a real capture (classic double-DI bug). */
.di{position:absolute;top:11px;left:50%;transform:translateX(-50%);width:100px;height:30px;
  background:#050506;border-radius:16px;z-index:8}
.statusbar{position:absolute;top:0;left:0;right:0;height:54px;z-index:7;color:var(--ink,#111);
  display:flex;align-items:center;justify-content:space-between;padding:16px 30px 0}
.statusbar .time{font-weight:600;font-size:16px;font-family:system-ui,-apple-system}
.statusbar .icons{display:flex;gap:6px;align-items:center}
.statusbar.light{color:#fff}

/* ---- breakout sticker primitives (position/rotate via inline style) ---- */
.sticker{position:absolute;z-index:20}
.emoji{position:absolute;z-index:20;line-height:1;filter:drop-shadow(0 10px 12px rgba(0,0,0,.28))}
.cutout{position:absolute;z-index:20;filter:drop-shadow(0 12px 16px rgba(0,0,0,.30))}
.chip{position:absolute;z-index:20;background:var(--paper-hi,#fff);border-radius:20px;
  padding:10px 16px;font-weight:800;box-shadow:0 12px 22px -8px rgba(0,0,0,.4);border:2px solid #fff}
.chip small{font-weight:600;color:var(--mid,#555);font-size:.6em}
.pin{position:absolute;z-index:20;color:#fff;font-weight:800;font-size:26px;
  padding:8px 14px;border-radius:14px;box-shadow:0 12px 20px -6px rgba(0,0,0,.45);border:2px solid #fff}
.pin::after{content:"";position:absolute;left:22px;bottom:-8px;width:16px;height:16px;
  background:inherit;border-radius:3px;transform:rotate(45deg)}
.gradeBadge{position:absolute;z-index:20;width:88px;height:88px;border-radius:22px;
  background:var(--badge-bg,#e7efe8);border:3px solid #fff;box-shadow:0 14px 26px -8px rgba(0,0,0,.42);
  display:flex;align-items:center;justify-content:center;color:var(--badge-ink,#2d5a3d);font-weight:800;font-size:52px}
```

- [ ] **Step 2: Eyeball-verify the variable math** (no render yet — that needs Task 6)

Check by hand: at 428 panel → device w = 342.4, h = 715.8, top = 305.6 (matches shipped Spotless values 342/715/306 within a pixel). At 430 → w = 344, h = 719.2, screen aspect (344−24)/(719.2−24) = 0.4603 ≈ 318/691. Write these numbers in a comment at the top of frame.css if any constant changes.

- [ ] **Step 3: Commit**

```bash
git add skills/hypershots/assets/frame.css
git commit -m "feat: geometric frame contract (profile-variable panel, fixed device aspect)"
```

---

### Task 6: fit.js + render.sh (render pipeline)

**Files:**
- Create: `skills/hypershots/assets/fit.js`
- Create: `skills/hypershots/scripts/render.sh`

- [ ] **Step 1: Write `fit.js`** — runs in-page before screenshot: waits for fonts, auto-fits `[data-fit]` text against the device-top budget (failure mode is *overlap with the device*, not overflow), dumps `[data-protect]` boxes + fit status into a DOM node that render.sh extracts via `--dump-dom`.

```js
/* HyperShots fit + boxes dump. Include LAST in every panel:
   <script src="fit.js"></script>
   Contract: [data-fit] on shrinkable copy blocks (optional data-fit-floor, px);
   [data-protect="name"] on regions the style-edit must preserve. */
(async () => {
  await document.fonts.ready;
  const root = document.documentElement;
  const cs = getComputedStyle(root);
  const deviceTop = parseFloat(cs.getPropertyValue('--panel-h')) *
                    parseFloat(cs.getPropertyValue('--device-top-ratio'));
  const failures = [];
  for (const el of document.querySelectorAll('[data-fit]')) {
    const maxBottom = el.dataset.fitMax ? parseFloat(el.dataset.fitMax) : deviceTop - 14;
    const floor = el.dataset.fitFloor ? parseFloat(el.dataset.fitFloor) : 26;
    let size = parseFloat(getComputedStyle(el).fontSize);
    while (el.getBoundingClientRect().bottom > maxBottom && size > floor) {
      size -= 1;
      el.style.fontSize = size + 'px';
    }
    if (el.getBoundingClientRect().bottom > maxBottom) {
      failures.push(el.dataset.i18n || el.className || 'unnamed');
    }
  }
  const boxes = [...document.querySelectorAll('[data-protect]')].map(el => {
    const r = el.getBoundingClientRect();
    return { name: el.dataset.protect || el.className,
             x: r.x, y: r.y, w: r.width, h: r.height };
  });
  const dump = document.createElement('script');
  dump.type = 'application/json';
  dump.id = 'hypershots-boxes';
  dump.textContent = JSON.stringify({ fitFailures: failures, boxes });
  document.body.appendChild(dump);
})();
```

- [ ] **Step 2: Write `render.sh`**

Interface: `render.sh <workspace> [profile] [locale]` (defaults: `iphone-6.9`, `en`).
Renders `<workspace>/panels/panel-*.html` (or `panels-<locale>/` for non-en) →
`<workspace>/out/<profile>/<locale>/panel-N.png` + `panel-N.boxes.json`.

```bash
#!/usr/bin/env bash
# HyperShots renderer: headless Chrome at an exact per-profile canvas.
set -euo pipefail

WS="${1:?usage: render.sh <workspace> [profile] [locale]}"
PROFILE="${2:-iphone-6.9}"
LOCALE="${3:-en}"
KIT="$(cd "$(dirname "$0")/.." && pwd)"     # skills/hypershots

find_chrome() {
  if [ -n "${CHROME:-}" ]; then echo "$CHROME"; return; fi
  local mac="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
  [ -x "$mac" ] && { echo "$mac"; return; }
  for c in google-chrome chromium chromium-browser; do
    command -v "$c" >/dev/null 2>&1 && { command -v "$c"; return; }
  done
  echo "ERROR: no Chrome/Chromium found. Set \$CHROME." >&2; exit 1
}
CHROME_BIN="$(find_chrome)"

# profile -> css dims + scale (node parses profiles.json; no jq dependency)
read -r W H SCALE OW OH <<< "$(node -e "
  const p=require('$KIT/profiles.json')['$PROFILE'];
  if(!p){console.error('unknown profile: $PROFILE');process.exit(1)}
  console.log(p.css[0],p.css[1],p.scale,p.out[0],p.out[1])")"

# per-profile variable injection (the mechanism that prevents gutters)
cat > "$WS/profile.css" <<EOF
/* generated by render.sh — do not edit */
:root{ --panel-w:${W}px; --panel-h:${H}px; }
EOF

SRC="$WS/panels"; [ "$LOCALE" != "en" ] && SRC="$WS/panels-$LOCALE"
OUT="$WS/out/$PROFILE/$LOCALE"; mkdir -p "$OUT"

FLAGS=(--headless=new --disable-gpu --hide-scrollbars --no-sandbox
  --force-device-scale-factor="$SCALE" --window-size="$W,$H"
  --default-background-color=FFFFFFFF --force-color-profile=srgb
  --virtual-time-budget=8000)

shopt -s nullglob
PANELS=("$SRC"/panel-*.html)
[ ${#PANELS[@]} -gt 0 ] || { echo "ERROR: no panels in $SRC" >&2; exit 1; }

for f in "${PANELS[@]}"; do
  n="$(basename "$f" .html)"
  # pass 1: screenshot (no || true — a Chrome crash must fail the build)
  "$CHROME_BIN" "${FLAGS[@]}" --screenshot="$OUT/$n.png" "file://$f" 2>/dev/null
  # pass 2: dump DOM -> boxes + fit failures (fit.js is deterministic across passes)
  "$CHROME_BIN" "${FLAGS[@]}" --dump-dom "file://$f" 2>/dev/null \
    | node -e '
      let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{
        const m=s.match(/<script type="application\/json" id="hypershots-boxes">(.*?)<\/script>/s);
        if(!m){console.error("ERROR: no boxes dump — is fit.js included last in the panel?");process.exit(1)}
        const j=JSON.parse(m[1]);
        if(j.fitFailures.length){console.error("FIT FAILURE (copy needs a rewrite): "+j.fitFailures.join(", "));process.exit(2)}
        console.log(JSON.stringify(j,null,1));})' > "$OUT/$n.boxes.json"
  echo "rendered $n -> $OUT/$n.png (target ${OW}x${OH})"
done
echo "OK: ${#PANELS[@]} panels rendered for $PROFILE/$LOCALE"
```

- [ ] **Step 3: Make executable, quick syntax check**

Run: `chmod +x skills/hypershots/scripts/render.sh && bash -n skills/hypershots/scripts/render.sh && node --check skills/hypershots/assets/fit.js`
Expected: no output (clean parse). Full behavior test comes with the fixture in Task 8.

- [ ] **Step 4: Commit**

```bash
git add skills/hypershots/assets/fit.js skills/hypershots/scripts/render.sh
git commit -m "feat: render pipeline (profile-exact canvas, fonts-gated auto-fit, boxes dump)"
```

---

### Task 7: validate.sh (the enforcement arm)

**Files:**
- Create: `skills/hypershots/scripts/validate.sh`

Rules (spec): exact dims per profile; **no alpha** (flatten via ImageMagick if
present, else fail with instructions); ICC profile must be absent-or-sRGB
(requiring an sRGB tag would fail every correct Chrome render); ≤10 panels.

- [ ] **Step 1: Write `validate.sh`**

```bash
#!/usr/bin/env bash
# HyperShots validator: the "cannot be rejected for asset specs" guarantee.
set -euo pipefail
WS="${1:?usage: validate.sh <workspace> [profile] [locale]}"
PROFILE="${2:-iphone-6.9}"
LOCALE="${3:-en}"
KIT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$WS/out/$PROFILE/$LOCALE"

read -r OW OH <<< "$(node -e "
  const p=require('$KIT/profiles.json')['$PROFILE'];
  if(!p){console.error('unknown profile: $PROFILE');process.exit(1)}
  console.log(p.out[0],p.out[1])")"

have_magick() { command -v magick >/dev/null 2>&1; }

# image prop reader: sips on macOS, magick identify elsewhere
props() { # $1=png -> "W H hasAlpha profileDesc"
  if command -v sips >/dev/null 2>&1; then
    local w h a p
    w=$(sips -g pixelWidth  "$1" | awk 'END{print $2}')
    h=$(sips -g pixelHeight "$1" | awk 'END{print $2}')
    a=$(sips -g hasAlpha    "$1" | awk 'END{print $2}')
    p=$(sips -g profile     "$1" 2>/dev/null | sed -n 's/^ *profile: //p'; true)
    echo "$w $h $a ${p:-<nil>}"
  else
    local fmt; fmt=$(magick identify -format "%w %h %A %[icc:description]" "$1" 2>/dev/null)
    echo "$fmt" | awk '{a=($3=="True"||$3=="Blend")?"yes":"no"; printf "%s %s %s %s\n",$1,$2,a,($4==""?"<nil>":$4)}'
  fi
}

shopt -s nullglob
PNGS=("$OUT"/panel-*.png)
COUNT=${#PNGS[@]}
[ "$COUNT" -gt 0 ]  || { echo "FAIL: no PNGs in $OUT" >&2; exit 1; }
[ "$COUNT" -le 10 ] || { echo "FAIL: $COUNT panels — App Store max is 10 per device size per localization" >&2; exit 1; }

FAILED=0
for f in "${PNGS[@]}"; do
  read -r w h a prof <<< "$(props "$f")"
  ok=1; msgs=()
  [ "$w" = "$OW" ] && [ "$h" = "$OH" ] || { ok=0; msgs+=("dims ${w}x${h}, expected ${OW}x${OH}"); }
  if [ "$a" = "yes" ]; then
    if have_magick; then
      magick "$f" -background white -alpha remove -alpha off "$f"
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
[ $FAILED -eq 0 ] && echo "VALIDATED: $COUNT panels, ${OW}x${OH}, store-compliant" || exit 1
```

- [ ] **Step 2: Syntax check + chmod**

Run: `chmod +x skills/hypershots/scripts/validate.sh && bash -n skills/hypershots/scripts/validate.sh`
Expected: clean. Behavior tests in Task 8.

- [ ] **Step 3: Commit**

```bash
git add skills/hypershots/scripts/validate.sh
git commit -m "feat: store-spec validator (dims, alpha flatten, sRGB-or-untagged, count)"
```

---

### Task 8: Test fixture + tests (proves render + validate end-to-end)

**Files:**
- Create: `tests/fixture/theme.css`, `tests/fixture/panels/panel-1.html`
- Create: `tests/run-tests.sh`

- [ ] **Step 1: Write the fixture theme + panel** — a minimal panel exercising: theme tokens, a deliberately long `data-fit` headline (must auto-shrink), `data-protect` on device + copy, a built screen with DI/statusbar.

`tests/fixture/theme.css`:
```css
:root{
  --paper:#F0EEE8; --paper-hi:#FFFFFF; --ink:#1A1A1A; --mid:#666; --rule:rgba(0,0,0,.15);
  --accent:#0A5AD4; --font-sans:'Inter Tight',system-ui,sans-serif; --font-mono:'IBM Plex Mono',monospace;
}
```

`tests/fixture/panels/panel-1.html` (note the `../../` paths — the fixture
workspace consumes the kit in place; a real workspace gets copies via scaffold):
```html
<!doctype html><html><head><meta charset="utf-8">
<link rel="stylesheet" href="../../../skills/hypershots/assets/fonts.css">
<link rel="stylesheet" href="../../../skills/hypershots/assets/frame.css">
<link rel="stylesheet" href="../theme.css">
<link rel="stylesheet" href="../profile.css">
</head><body>
<div class="panel">
  <div class="wrap" data-protect="copy">
    <div class="eyebrow"><b data-i18n="p1.eyebrow">Fixture</b><i></i></div>
    <div class="headline" data-fit data-fit-floor="24" data-i18n="p1.headline">
      An intentionally very very long fixture headline that cannot possibly fit at forty-five pixels</div>
    <div class="sub" data-i18n="p1.sub">Auto-fit must shrink the line above.</div>
  </div>
  <div class="stage">
    <div class="device" data-protect="device"><div class="screen">
      <div style="position:absolute;inset:0;background:var(--paper-hi)"></div>
      <div class="di"></div>
      <div class="statusbar"><span class="time">9:41</span><span class="icons"></span></div>
    </div></div>
    <div class="chip" style="left:20px;top:640px;transform:rotate(-6deg)">9.6<small>/10</small></div>
  </div>
</div>
<script src="../../../skills/hypershots/assets/fit.js"></script>
</body></html>
```

Note: `profile.css` is generated by render.sh into the *workspace* root
(`tests/fixture/profile.css`), so the `<link>` above resolves. Panels in a real
workspace use `href="../profile.css"` the same way — document in create.md.

- [ ] **Step 2: Write `tests/run-tests.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
R=skills/hypershots/scripts/render.sh
V=skills/hypershots/scripts/validate.sh
WS=tests/fixture
rm -rf "$WS/out" "$WS/profile.css"

echo "== T1: render at iphone-6.9 =="
bash "$R" "$WS" iphone-6.9 en

echo "== T2: exact dims + no alpha =="
png="$WS/out/iphone-6.9/en/panel-1.png"
node -e "
  const b=require('fs').readFileSync('$png');
  const w=b.readUInt32BE(16),h=b.readUInt32BE(20),ct=b[25];
  if(w!==1290||h!==2796){console.error('dims '+w+'x'+h);process.exit(1)}
  if(ct===4||ct===6){console.error('PNG has alpha (colortype '+ct+')');process.exit(1)}
  console.log('dims 1290x2796, colortype '+ct+' (no alpha) OK')"

echo "== T3: boxes dump exists + fit ran =="
node -e "
  const j=require('./$WS/out/iphone-6.9/en/panel-1.boxes.json');
  if(!j.boxes.find(b=>b.name==='device'))throw new Error('no device box');
  if(!j.boxes.find(b=>b.name==='copy'))throw new Error('no copy box');
  if(j.fitFailures.length)throw new Error('unexpected fit failure');
  console.log('boxes:',j.boxes.map(b=>b.name).join(','),'OK')"

echo "== T4: validator passes the good render =="
bash "$V" "$WS" iphone-6.9 en

echo "== T5: validator fails a wrong-size PNG =="
node -e "
  const z=require('zlib'),fs=require('fs');
  // tiny 100x100 RGB PNG, hand-assembled
  const chunk=(t,d)=>{const l=Buffer.alloc(4);l.writeUInt32BE(d.length);
    const c=Buffer.concat([Buffer.from(t),d]);const crc=require('zlib').crc32?0:0;
    const {crc32}=require('zlib');const cc=Buffer.alloc(4);cc.writeUInt32BE(crc32(c)>>>0);
    return Buffer.concat([l,c,cc])};
  const ihdr=Buffer.alloc(13);ihdr.writeUInt32BE(100,0);ihdr.writeUInt32BE(100,4);ihdr[8]=8;ihdr[9]=2;
  const row=Buffer.concat([Buffer.from([0]),Buffer.alloc(300,200)]);
  const idat=z.deflateSync(Buffer.concat(Array(100).fill(row)));
  fs.writeFileSync('$WS/out/iphone-6.9/en/panel-9.png',Buffer.concat(
    [Buffer.from([137,80,78,71,13,10,26,10]),chunk('IHDR',ihdr),chunk('IDAT',idat),chunk('IEND',Buffer.alloc(0))]));"
if bash "$V" "$WS" iphone-6.9 en; then echo "T5 FAILED: validator accepted a 100x100 png"; exit 1
else echo "validator correctly rejected wrong-size png"; fi
rm "$WS/out/iphone-6.9/en/panel-9.png"

echo "== T6: fit failure fails the render =="
mkdir -p "$WS/panels-xx"
sed 's/data-fit-floor="24"/data-fit-floor="60"/' "$WS/panels/panel-1.html" > "$WS/panels-xx/panel-1.html"
if bash "$R" "$WS" iphone-6.9 xx; then echo "T6 FAILED: render accepted an unfittable headline"; exit 1
else echo "render correctly failed on fit floor"; fi
rm -rf "$WS/panels-xx" "$WS/out/iphone-6.9/xx"

echo "ALL TESTS PASSED"
```

(`zlib.crc32` requires Node ≥ 20.11; CI pins Node 20 — if the local Node lacks
it, replace the hand-assembled PNG with `magick -size 100x100 xc:gray
"$WS/out/iphone-6.9/en/panel-9.png"`.)

- [ ] **Step 3: Run the tests**

Run: `chmod +x tests/run-tests.sh && bash tests/run-tests.sh`
Expected: `ALL TESTS PASSED`. Debug render.sh/fit.js/validate.sh until green —
this is the checkpoint that the deterministic core actually works.

- [ ] **Step 4: Read the rendered fixture PNG** (agent visual check: headline
shrunk, no device overlap, DI present, chip sticker placed)

Run: Read `tests/fixture/out/iphone-6.9/en/panel-1.png`

- [ ] **Step 5: Commit**

```bash
git add tests/
git commit -m "test: fixture workspace + end-to-end render/validate/fit tests"
```

---

### Task 9: scaffold.sh + preflight.sh

**Files:**
- Create: `skills/hypershots/scripts/scaffold.sh`, `skills/hypershots/scripts/preflight.sh`

- [ ] **Step 1: Write `scaffold.sh`** — initializes the workspace in the USER'S repo (the installed skill dir is read-only reference).

```bash
#!/usr/bin/env bash
# Initialize a HyperShots workspace (default: .shots/) in the user's project.
set -euo pipefail
WS="${1:-.shots}"
KIT="$(cd "$(dirname "$0")/.." && pwd)"
[ -e "$WS/brief.md" ] && { echo "ERROR: $WS already scaffolded"; exit 1; }
mkdir -p "$WS/panels" "$WS/assets" "$WS/out"
cp "$KIT/assets/frame.css" "$KIT/assets/fit.js" "$KIT/assets/fonts.css" "$WS/"
cp -R "$KIT/assets/fonts" "$WS/fonts"
cp "$KIT/profiles.json" "$WS/"
cat > "$WS/theme.css" <<'EOF'
/* Per-app theme layer — derive from the app's brand (see references/create.md).
   REQUIRED tokens consumed by frame.css: */
:root{
  --paper:#f5f5f2;      /* panel background */
  --paper-hi:#ffffff;   /* card / chip surface */
  --ink:#111111;        /* primary text */
  --mid:#555555;        /* secondary text */
  --rule:rgba(0,0,0,.15);
  --accent:#333333;     /* brand accent (eyebrow, highlights) */
  --font-sans:'Inter Tight',system-ui,sans-serif;
  --font-mono:'IBM Plex Mono',ui-monospace,monospace;
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
```

Note: scaffold copies the kit (pinned per workspace) but panel `<link>` hrefs
then point at the *workspace* copies: `href="../frame.css"` etc. — document the
two href layouts (fixture-style vs workspace-style) in create.md.

- [ ] **Step 2: Write `preflight.sh`** — reports; never installs (consent + install commands live in SKILL.md).

```bash
#!/usr/bin/env bash
# Dependency report. Exit 0 always — SKILL.md decides what to do about gaps.
set -uo pipefail
ok(){ echo "OK   $1"; }; miss(){ echo "MISS $1 — $2"; }
if [ -n "${CHROME:-}" ] && [ -x "$CHROME" ]; then ok "chrome (\$CHROME)"
elif [ -x "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" ]; then ok "chrome (macOS app)"
elif command -v google-chrome >/dev/null || command -v chromium >/dev/null; then ok "chrome (PATH)"
else miss "chrome" "REQUIRED. Install Chrome/Chromium or set \$CHROME"; fi
command -v node >/dev/null && ok "node" || miss "node" "REQUIRED for render/validate helpers"
command -v magick >/dev/null && ok "imagemagick" \
  || miss "imagemagick" "optional: alpha flattening + style-edit compositing (brew install imagemagick)"
if command -v genmedia >/dev/null; then
  ok "genmedia ($(genmedia --version 2>/dev/null | head -c 40)...)"
else
  miss "genmedia" "optional: AI assets + style grade. Offer: npm i -g genmedia && genmedia setup"
fi
command -v sips >/dev/null && ok "sips" || echo "INFO sips absent (non-macOS) — validator uses magick"
```

- [ ] **Step 3: Test scaffold in a temp dir**

Run:
```bash
chmod +x skills/hypershots/scripts/{scaffold.sh,preflight.sh}
T=$(mktemp -d) && bash skills/hypershots/scripts/scaffold.sh "$T/.shots" \
  && ls "$T/.shots" && bash skills/hypershots/scripts/preflight.sh && rm -rf "$T"
```
Expected: scaffold lists `panels theme.css brief.md frame.css fit.js fonts.css fonts profiles.json assets out`; preflight prints OK/MISS lines and exits 0.

- [ ] **Step 4: Commit**

```bash
git add skills/hypershots/scripts/scaffold.sh skills/hypershots/scripts/preflight.sh
git commit -m "feat: workspace scaffold + dependency preflight"
```

---

### Task 10: translate-inject.mjs (translate gear mechanics)

**Files:**
- Create: `skills/hypershots/scripts/translate-inject.mjs`

Contract (goes in i18n.md, Task 11): every translatable element carries
`data-i18n="pN.key"`, its content lives on ONE line, and may contain only
`<br>` as markup.

- [ ] **Step 1: Write `translate-inject.mjs`**

```js
#!/usr/bin/env node
// Usage: node translate-inject.mjs <workspace> <locale>
// Reads panels/*.html + strings.<locale>.json -> writes panels-<locale>/*.html
import { readFileSync, writeFileSync, mkdirSync, readdirSync } from 'fs';
import { join } from 'path';

const [ws, locale] = process.argv.slice(2);
if (!ws || !locale) { console.error('usage: translate-inject.mjs <workspace> <locale>'); process.exit(1); }
const strings = JSON.parse(readFileSync(join(ws, `strings.${locale}.json`), 'utf8')).strings;
const outDir = join(ws, `panels-${locale}`);
mkdirSync(outDir, { recursive: true });

let used = new Set(), missing = new Set();
for (const f of readdirSync(join(ws, 'panels')).filter(f => f.endsWith('.html'))) {
  let html = readFileSync(join(ws, 'panels', f), 'utf8');
  html = html.replace(
    /(<([a-z0-9]+)\b[^>]*\bdata-i18n="([^"]+)"[^>]*>)([\s\S]*?)(<\/\2>)/g,
    (m, open, tag, key, body, close) => {
      if (!(key in strings)) { missing.add(key); return m; }
      used.add(key);
      return open + strings[key] + close;
    });
  writeFileSync(join(outDir, f), html);
}
const unused = Object.keys(strings).filter(k => !used.has(k));
if (missing.size) { console.error('MISSING translations: ' + [...missing].join(', ')); process.exit(1); }
if (unused.length) console.error('WARN unused keys: ' + unused.join(', '));
console.log(`injected ${used.size} strings -> ${outDir}`);
```

- [ ] **Step 2: Test against the fixture**

Run:
```bash
cat > tests/fixture/strings.es.json <<'EOF'
{ "locale": "es", "strings": {
  "p1.eyebrow": "Prueba",
  "p1.headline": "Un titular de prueba deliberadamente largo que no cabe a cuarenta y cinco píxeles",
  "p1.sub": "El ajuste automático debe encoger la línea." } }
EOF
node skills/hypershots/scripts/translate-inject.mjs tests/fixture es
bash skills/hypershots/scripts/render.sh tests/fixture iphone-6.9 es
bash skills/hypershots/scripts/validate.sh tests/fixture iphone-6.9 es
```
Expected: `injected 3 strings`, render OK (auto-fit handles the long Spanish), `VALIDATED: 1 panels`.

- [ ] **Step 3: Read the ES render to confirm the localized panel looks right**

Run: Read `tests/fixture/out/iphone-6.9/es/panel-1.png`

- [ ] **Step 4: Commit** (include the es fixture as a living example)

```bash
git add skills/hypershots/scripts/translate-inject.mjs tests/fixture/strings.es.json
git commit -m "feat: translate gear string injection + es fixture"
```

---

### Task 11: Reference docs (the eight files)

**Files:**
- Create: `skills/hypershots/references/{store-specs,create,revise,translate,i18n,edit-filter,asset-recipes,gotchas}.md`

Write each with REAL content (source: the spec + Spotless pipeline). Required
content per file — write these fully, not as stubs:

- [ ] **Step 1: `store-specs.md`** — dated header ("verified 2026-07; re-verify at Apple's Screenshot specifications page before trusting"). The profile table from the spec (6.9″ required/default incl. both px options; 6.5″ legacy-accepted; iPad 13″ only-if-iPad-build; note that ASC's old "6.7″" label is the same slot as 6.9″). Rules list: PNG or JPG; flattened, no alpha; untagged-or-sRGB ICC; ≤10 per device size per localization; first ~3 portrait shots visible pre-"Show All" (app previews precede them). Google Play section marked ROADMAP with 1080×1920 + 1024×500 feature graphic. Statement that `validate.sh` + `profiles.json` are the enforcement of this table and must be updated together.

- [ ] **Step 2: `create.md`** — the create-gear runbook: (1) preflight; (2) scaffold; (3) brief questionnaire (copy the scaffolded brief.md fields); (4) derive theme.css from the app's brand — REQUIRED tokens list (`--paper --paper-hi --ink --mid --rule --accent --font-sans --font-mono`), guidance: sample the app's real UI colors from captures, never reuse the example theme; (5) author panels — the frame contract (immutable: `.panel/.device/.screen/.di/.statusbar` geometry; NEVER add `.di`/`.statusbar` over a real simulator capture; variable: theme + sticker placement via inline `left/top/width/transform:rotate()`); the two `<link>` layouts (workspace: `../frame.css`; include `fit.js` LAST); marker rules (`data-i18n` on every translatable node — one line, `<br>` only; `data-fit` + `data-fit-floor` on headline/sub; `data-protect` on `.wrap` and `.device`); narrative arc guidance from Spotless (shock → map → trust → share → AI-bonus; first 3 panels carry the install decision); (6) render; (7) MANDATORY self-review loop: Read every rendered PNG checking overflow/clipped stickers/DI collisions/theme legibility, fix, re-render; (8) validate; (9) contact sheet (`magick montage out/<p>/<l>/panel-*.png -tile 5x1 -geometry +8+8 contact-sheet.png`) and show the user.

- [ ] **Step 3: `revise.md`** — shortest doc: locate the panel in `<ws>/panels/`, edit HTML/theme, re-render the affected profile+locale, re-run the self-review Read on changed panels, re-validate, regenerate the contact sheet. Never edit files in `out/` (they're generated) and never edit `panels-<locale>/` by hand (regenerate via translate-inject).

- [ ] **Step 4: `translate.md`** — runbook: extract keys (grep `data-i18n` across panels → build the key list), write `strings.<locale>.json` (agent translates: keep proper nouns like app name/score names untranslated; match register of the source copy), `node translate-inject.mjs <ws> <locale>`, render, **Read each localized PNG** (auto-fit handles length but the agent checks line-breaks/awkward hyphenation), validate, contact sheet. Overlay-only caveat verbatim from spec (in-frame screenshots stay source-language unless per-locale captures are provided — swap capture files in `assets/` and re-render for that). Launch scope Latin/Cyrillic; RTL/CJK is roadmap (needs Noto fallback + `dir="rtl"` handling).

- [ ] **Step 5: `i18n.md`** — the contracts: `data-i18n` marker rules; `strings.<locale>.json` schema (`{"locale":"es","strings":{"p1.headline":"..."}}`); key naming `p<N>.<slot>`; auto-fit mechanism description (fonts.ready → shrink to device-top budget → floor → loud failure with exit 2) and how to set `data-fit-floor`/`data-fit-max`; locale output layout `out/<profile>/<locale>/`.

- [ ] **Step 6: `edit-filter.md`** — the style-grade doc: when to offer (user asks for "cooler"/stylized/illustrated look), OFF by default, non-destructive `.styled.png`. The 5-step pipeline verbatim from the spec (upload → edit at nearest-16 → resample to exact canvas → re-composite protected regions feathered → validate), WHY each step exists (gpt-image re-generates the whole canvas — mask is guidance, composite is the guarantee; dims not multiples of 16). `protected` (default) vs `full` mode. Consistency: same style prompt across every panel of the set + optional style reference image. Cost note (~per-image genmedia pricing; check `genmedia pricing openai/gpt-image-2/edit`).

- [ ] **Step 7: `asset-recipes.md`** — pinned known-good recipes with full genmedia commands from the proven Spotless run:

````markdown
## Die-cut cutout sticker (proven recipe)
1. Generate:
   genmedia run openai/gpt-image-2 \
     --prompt "A single die-cut glossy 3D sticker of <SUBJECT>, thick clean white die-cut sticker border around the whole silhouette, centered, on a solid flat bright magenta background, soft studio lighting, high detail, no text" \
     --image_size square_hd --quality high --json
2. Strip background (BiRefNet v2 -> transparent PNG):
   genmedia run fal-ai/birefnet/v2 --image_url <URL-from-step-1> \
     --output_format png --download ./assets/<name>.png --json
Notes: solid bright background (magenta/cyan) makes the matte clean; keep
"no text" in the prompt; params are --flags (not key=value); image_size uses
presets (square_hd).

## Photographic background
   genmedia run fal-ai/flux/schnell --prompt "<scene>" --image_size portrait_16_9 \
     --download ./assets/<name>.png --json

## Picking a different model
Install the catalog: genmedia skills install fal-models-catalog — then choose
by task; keep BiRefNet v2 as the background-strip stage regardless of generator.

## Without genmedia (degraded mode — fully supported)
User-provided PNGs in assets/, plain emoji via the .emoji primitive, or no
stickers. Never block create/revise/translate on genmedia.
````

- [ ] **Step 8: `gotchas.md`** — one entry each (symptom → cause → fix): double Dynamic Island (CSS `.di` over a real capture); alpha-channel rejection (transparent Chrome background / gutter — render.sh uses opaque bg; validator flattens); Google-Fonts-at-render-time (why fonts are vendored; never add remote `@import` to theme.css); fit measured before fonts loaded (fit.js gates on fonts.ready — keep fit.js LAST in body); text *overlaps device* rather than overflowing (why the fit budget is device-top); stretched screenshots (capture aspect must be ~0.46; use `object-fit:cover` + top anchoring); `|| true` swallowing Chrome crashes (never re-add); sticker shadows bleeding outside protect boxes (mask padding ~70px in make-mask.mjs); cross-machine antialiasing differences (determinism scope).

- [ ] **Step 9: Commit**

```bash
git add skills/hypershots/references/
git commit -m "docs: reference runbooks for all four gears + specs + gotchas"
```

---

### Task 12: Full SKILL.md

**Files:**
- Modify: `skills/hypershots/SKILL.md` (replace skeleton body; keep frontmatter EXACTLY as committed in Task 2)

- [ ] **Step 1: Write the full body** with these sections (house style: When to Use → router → steps → mistakes → checklist):

````markdown
# HyperShots — spec-reliable App Store screenshots

Deterministic where it must be (HTML/CSS: frames, fonts, copy, exact canvas,
locales), generative only where it helps (cut-out stickers, optional style
grade). You author bespoke panel HTML per app; scripts guarantee the specs.

## When to use / when not
Use for: App Store screenshot sets, localizing an existing set, revising
panels, "make my screenshots cooler". NOT for: general image generation,
social/OG images, capturing simulator screenshots (point user at fastlane
snapshot), uploading to App Store Connect (that's fastlane deliver).

## Intent router
| User wants | Read | Then |
|---|---|---|
| New screenshot set | references/create.md | full create flow |
| Change existing panel(s) | references/revise.md | edit → re-render → validate |
| Localized set | references/translate.md + i18n.md | inject → render → validate |
| Stylized "cool" look | references/edit-filter.md | optional grade, protected default |
| Generated stickers/photos | references/asset-recipes.md | genmedia recipes |
| Spec questions | references/store-specs.md | answer from the dated table |

## Prerequisites (run first, every session)
bash <skill>/scripts/preflight.sh
- chrome + node are REQUIRED — stop and help install if missing.
- genmedia is OPTIONAL: if missing and the task wants generated assets or the
  style grade, ASK the user before installing:
  npm i -g genmedia && genmedia setup --non-interactive   (needs FAL_KEY)
  then: genmedia skills install genmedia fal-models-catalog
  If the user declines, proceed in degraded mode (references/asset-recipes.md
  "Without genmedia").

## The frame contract (memorize before authoring)
IMMUTABLE: .panel/.device/.screen geometry (profile variables size them),
.di/.statusbar (and NEVER over a real capture), screen aspect ~0.460.
REQUIRED MARKERS: data-i18n on every translatable node (one line, <br> only);
data-fit (+ data-fit-floor) on headline/sub; data-protect on .wrap + .device.
VARIABLE: theme.css tokens (derive from the app's real brand), sticker
placement via inline style, per-panel screen content.
Include LAST in body: <script src="../fit.js"></script>

## Workspace
scripts/scaffold.sh [dir=.shots] creates the workspace in the USER'S repo.
This installed skill dir is read-only reference — author only in the workspace.
Read ONE annotated example (examples/spotless/panels/panel-1.html) before
authoring your first panel.

## The loop that makes output good (mandatory)
render.sh → **Read every rendered PNG yourself** (overflow? clipped sticker?
DI collision? legible over the theme?) → fix → re-render → validate.sh →
contact sheet → show the user. Never skip the Read.

## Common mistakes
- Adding .di/.statusbar over a real simulator capture (double status bar).
- Restyling .device / hardcoding panel px (breaks profiles → gutters → alpha
  → App Store rejection).
- Remote font @import in theme.css (breaks offline determinism).
- Editing out/ or panels-<locale>/ by hand (both are generated).
- Skipping validate.sh because the render "looks right".
- Re-rendering iphone panels for ipad-13 (separate authoring pass).

## Review checklist (before showing the user)
- [ ] validate.sh prints VALIDATED for every profile+locale shipped
- [ ] You Read every PNG after the last edit
- [ ] ≤10 panels; the first 3 carry the install decision
- [ ] data-i18n/data-fit/data-protect present on every panel
- [ ] theme derived from the app (not the example theme)
````

- [ ] **Step 2: Re-run the skill validator**

Run: `npm run validate`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add skills/hypershots/SKILL.md
git commit -m "docs: full SKILL.md (router, frame contract, mandatory review loop)"
```

---

### Task 13: Spotless example port (annotated gold reference + proves the kit on real content)

**Files:**
- Create: `skills/hypershots/examples/spotless/{README.md,brief.md,theme.css}`
- Create: `skills/hypershots/examples/spotless/panels/panel-1.html … panel-5.html`
- Create: `skills/hypershots/examples/spotless/contact-sheet.png`

Source material: `<spotless-repo>/.shots/html/` (panels 1–5,
frame.css for the theme tokens, assets). The example ships HTML + ONE small
contact sheet — NOT full-res PNGs and NOT the capture/sticker assets (installer
copies the whole skill dir into every agent).

- [ ] **Step 1: Write `theme.css`** — extract Spotless's brand tokens from the old frame.css `:root` (paper #F4ECE0, ink #161413, accent #C44322, greens/reds, Inter Tight/IBM Plex Mono) into the theme-token contract, including the paper-grain `::after` rule moved here (it's brand, not geometry) as `.panel::after`.

- [ ] **Step 2: Port the 5 panels** to the new contract. For each: swap the stylesheet links to the workspace layout (`../fonts.css`, `../frame.css`, `../theme.css`, `../profile.css`), keep per-panel `<style>` blocks, add `data-i18n` markers on every marketing string (`p1.eyebrow/p1.headline/p1.sub`, panel-4 receipt lines, panel-5 chat strings), `data-fit data-fit-floor="34"` on headlines, `data-protect="copy"` on `.wrap` / `data-protect="device"` on `.device`, `<script src="../fit.js"></script>` last. Replace asset `src` paths with `assets/<name>.png` and add an HTML comment atop each file noting assets are not shipped (see README.md).
- Add **annotation comments** (the teaching layer) at each decision: why the fixed device slot, why panel-2/3 have no `.di` (real captures), why panel-4 is frameless, sticker rotation conventions, the first-3-arc rationale.

- [ ] **Step 3: Write `brief.md`** — the actual Spotless brief as filled example (positioning "check before you eat", 5 panels with the shipped headlines, arc note, stickers list, profile iphone-6.9, locales en+es).

- [ ] **Step 4: Write `README.md`** — one paragraph: "These panels were submitted to the App Store with Spotless v1.0 (July 2026). Assets (captures/stickers/photos) are not included; the HTML is the reference. See contact-sheet.png for the rendered result." Plus the render-it-yourself note (copy into a workspace, add your own assets).

- [ ] **Step 5: Build the contact sheet** — temporarily copy the example + real Spotless assets into a scratch workspace, render at **iphone-6.9**, validate, montage:

```bash
T=$(mktemp -d)
bash skills/hypershots/scripts/scaffold.sh "$T/ws"
cp skills/hypershots/examples/spotless/panels/*.html "$T/ws/panels/"
cp skills/hypershots/examples/spotless/theme.css "$T/ws/theme.css"
cp <spotless-repo>/.shots/html/assets/* "$T/ws/assets/"
bash skills/hypershots/scripts/render.sh "$T/ws" iphone-6.9 en
bash skills/hypershots/scripts/validate.sh "$T/ws" iphone-6.9 en
magick montage "$T/ws/out/iphone-6.9/en/"panel-*.png -tile 5x1 -geometry +8+8 \
  -background '#111' skills/hypershots/examples/spotless/contact-sheet.png
magick skills/hypershots/examples/spotless/contact-sheet.png -resize 2000x skills/hypershots/examples/spotless/contact-sheet.png
```
Expected: `VALIDATED: 5 panels, 1290x2796` — **this is the proof the whole port works at the required 6.9″ size.** Keep `$T` around for Task 15 (README hero assets).

- [ ] **Step 6: Read the contact sheet** — visual check that the 6.9″ re-render didn't break any panel (fit, stickers, frames identical).

- [ ] **Step 7: Commit**

```bash
git add skills/hypershots/examples/
git commit -m "feat: annotated Spotless example set (submitted to the App Store), 6.9-inch verified"
```

---

### Task 14: edit-pass (style grade) — make-mask.mjs + edit-pass.sh

**Files:**
- Create: `skills/hypershots/scripts/make-mask.mjs`, `skills/hypershots/scripts/edit-pass.sh`

- [ ] **Step 1: Write `make-mask.mjs`** — boxes.json → hard mask (for the API: transparent = EDIT, opaque = KEEP) + feathered composite mask.

```js
#!/usr/bin/env node
// Usage: make-mask.mjs <boxes.json> <outW> <outH> <scale> <mask.png> <feather.png>
// Boxes are CSS px from getBoundingClientRect (includes transforms); we scale
// to output px and pad for shadow bleed.
import { execFileSync } from 'child_process';
import { readFileSync } from 'fs';
const [bj, W, H, scale, mask, feather] = process.argv.slice(2);
const PAD = 70; // css px — covers .device box-shadow + sticker drop-shadows
const boxes = JSON.parse(readFileSync(bj, 'utf8')).boxes;
const draws = boxes.flatMap(b => {
  const x0 = Math.max(0, (b.x - PAD) * scale), y0 = Math.max(0, (b.y - PAD) * scale);
  const x1 = Math.min(W, (b.x + b.w + PAD) * scale), y1 = Math.min(H, (b.y + b.h + PAD) * scale);
  return ['-draw', `rectangle ${x0},${y0} ${x1},${y1}`];
});
// hard mask: transparent canvas (=edit), opaque white rects (=keep)
execFileSync('magick', ['-size', `${W}x${H}`, 'xc:none', '-fill', 'white', ...draws, mask]);
// composite mask: same, feathered, on black (white=take original pixels)
execFileSync('magick', ['-size', `${W}x${H}`, 'xc:black', '-fill', 'white', ...draws, '-blur', '0x6', feather]);
console.log(`masks written: ${mask}, ${feather} (${boxes.length} boxes, pad ${PAD}css)`);
```

- [ ] **Step 2: Write `edit-pass.sh`**

```bash
#!/usr/bin/env bash
# Optional style grade. Usage:
#   edit-pass.sh <workspace> <profile> <locale> <panel-N> "<style prompt>" [protected|full]
set -euo pipefail
WS="$1"; PROFILE="$2"; LOCALE="$3"; PANEL="$4"; STYLE="$5"; MODE="${6:-protected}"
KIT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$WS/out/$PROFILE/$LOCALE"; SRC="$OUT/$PANEL.png"; BOX="$OUT/$PANEL.boxes.json"
[ -f "$SRC" ] || { echo "ERROR: $SRC not rendered"; exit 1; }
command -v genmedia >/dev/null || { echo "ERROR: style grade needs genmedia (see SKILL.md prerequisites)"; exit 1; }
command -v magick   >/dev/null || { echo "ERROR: style grade needs ImageMagick"; exit 1; }

read -r OW OH SCALE <<< "$(node -e "
  const p=require('$KIT/profiles.json')['$PROFILE'];console.log(p.out[0],p.out[1],p.scale)")"
# nearest multiple-of-16 canvas for gpt-image-2 (it cannot output ours exactly)
EW=$(( (OW + 8) / 16 * 16 )); EH=$(( (OH + 8) / 16 * 16 ))

IMG_URL=$(genmedia upload "$SRC" --json | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>console.log(JSON.parse(s).url))')
ARGS=(--image_urls "$IMG_URL" --prompt "$STYLE" --image_size "${EW}x${EH}" --quality high)
if [ "$MODE" = "protected" ]; then
  node "$KIT/scripts/make-mask.mjs" "$BOX" "$OW" "$OH" "$SCALE" "$OUT/$PANEL.mask.png" "$OUT/$PANEL.feather.png"
  MASK_URL=$(genmedia upload "$OUT/$PANEL.mask.png" --json | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>console.log(JSON.parse(s).url))')
  ARGS+=(--mask_url "$MASK_URL")
fi
genmedia run openai/gpt-image-2/edit "${ARGS[@]}" --download "$OUT/$PANEL.styled.raw.png" --json >/dev/null

# resample back to the exact store canvas
magick "$OUT/$PANEL.styled.raw.png" -resize "${OW}x${OH}!" "$OUT/$PANEL.styled.png"
if [ "$MODE" = "protected" ]; then
  # composite = the actual pixel guarantee (model re-generates everything;
  # the mask was only guidance). white in feather = take ORIGINAL pixels.
  magick "$OUT/$PANEL.styled.png" "$SRC" "$OUT/$PANEL.feather.png" -composite "$OUT/$PANEL.styled.png"
fi
rm -f "$OUT/$PANEL.styled.raw.png"
echo "styled: $OUT/$PANEL.styled.png (clean render untouched at $PANEL.png)"
```

- [ ] **Step 3: Static checks + mask unit test** (no paid API call)

Run:
```bash
chmod +x skills/hypershots/scripts/edit-pass.sh
bash -n skills/hypershots/scripts/edit-pass.sh && node --check skills/hypershots/scripts/make-mask.mjs
node skills/hypershots/scripts/make-mask.mjs tests/fixture/out/iphone-6.9/en/panel-1.boxes.json \
  1290 2796 3 /tmp/hs-mask.png /tmp/hs-feather.png
magick identify /tmp/hs-mask.png /tmp/hs-feather.png
```
Expected: both masks 1290×2796; mask.png has alpha (transparent = edit regions).

- [ ] **Step 4: Live smoke test (MANUAL, costs ~$0.10–0.25, requires FAL_KEY)** — run edit-pass on the fixture panel with style prompt `"risograph print style, warm duotone, subtle grain"`, mode `protected`; Read the `.styled.png`; verify the copy block + device are crisp (composited) and the background is stylized. If genmedia's upload/run JSON shapes differ from the parsing above, fix the parsing (verify with `genmedia upload --help` / `--json` output).

- [ ] **Step 5: Commit**

```bash
git add skills/hypershots/scripts/make-mask.mjs skills/hypershots/scripts/edit-pass.sh
git commit -m "feat: optional style grade (mask-guided edit + protected re-composite)"
```

---

### Task 15: README landing page

**Files:**
- Create: `README.md`, `docs/img/` (hero, comparison, translate pair)

- [ ] **Step 1: Produce the visual assets** (uses the Task 13 scratch workspace; re-create it if cleaned):
  - `docs/img/hero.png` — the 5-panel EN contact sheet (already built; copy).
  - `docs/img/translate-pair.png` — render the example ES set (write `strings.es.json` from the Spotless `.shots/html/panel-*-es.html` copy), montage EN panel-1 beside ES panel-1.
  - `docs/img/comparison.png` — the thesis image: generate the "bad" example ONCE via genmedia (`genmedia run openai/gpt-image-2 --prompt "App Store screenshot for a restaurant-hygiene app called Spotless, iPhone device frame, headline 'How clean is your favorite restaurant?', map UI with score pins" --image_size portrait_16_9 --quality high`) and montage it beside the real panel-1 with labels "one-shot AI generation" / "HyperShots". (MANUAL: costs one generation; pick the most representative melty result of 2–3 attempts.)

- [ ] **Step 2: Write `README.md`** in the spec's landing order: hero image → one-line pitch ("App Store screenshots that pass validation the first time, in every language — deterministic HTML where Apple has rules, generative AI where it sells.") → install one-liner → comparison image + 3-sentence thesis → translate pair → 60-second quickstart (scaffold → brief → agent authors → render → validator PASS transcript) → How it works (deterministic/generative table) → store-spec table → **How this differs** (name fastlane frameit, ParthJadhav/app-store-screenshots, adamlyttleapps' skill — one honest sentence each + the four ownable pieces) → Requirements (Chrome, node; optional genmedia+FAL_KEY, ImageMagick) → Roadmap (Play "good first PR", iPad pass, landscape, dark-mode, RTL/CJK, provider choice, preview video pointer to transparent-video) → FAQ (simulator capture → fastlane snapshot; upload → fastlane deliver; "supersedes the old private shots skill") → License (MIT + OFL notice).

- [ ] **Step 3: Read the README top-to-bottom** — check every image renders (relative paths), every claim matches the spec, install command exact.

- [ ] **Step 4: Commit**

```bash
git add README.md docs/img/
git commit -m "docs: landing README (hero, comparison, translate proof, quickstart)"
```

---

### Task 16: Final validation + ship

**Files:**
- Modify: `<catalog-repo>/README.md` (cross-link)

- [ ] **Step 1: Full local check**

Run: `npm run validate && bash tests/run-tests.sh`
Expected: validator PASS + `ALL TESTS PASSED`.

- [ ] **Step 2: Fresh-eyes spec sweep** — open the spec, walk each section, confirm a shipped file covers it (thesis→README; four gears→references; bootstrap→SKILL.md prerequisites; workspace→scaffold.sh; compliance→validate.sh+store-specs.md; examples→Task 13; migration→Task 16 step 4). Fix gaps before pushing.

- [ ] **Step 3: Push (CONFIRM WITH USER FIRST — repo is public; this is the launch-visible first push)**

```bash
git push -u origin main
```
Then verify CI is green on GitHub (both `skills` and `render` jobs).

- [ ] **Step 4: Catalog cross-link** — in `<catalog-repo>/README.md`, add under "Related skills (hosted elsewhere)":

```markdown
- [`hypershots`](https://github.com/hypersocialinc/hypershots) — Spec-reliable App Store
  screenshots: deterministic HTML/CSS panels (exact canvases, device frames, localization
  with auto-fit) + optional AI-generated sticker assets and style grading.

    npx skills add hypersocialinc/hypershots --skill hypershots --agent claude-code
```

Commit in that repo: `docs: cross-link hypershots skill` (push only with user's OK).

- [ ] **Step 5: Real-world install test**

Run: `npx skills add hypersocialinc/hypershots --list`
Expected: lists `hypershots`. (If the CLI caches, retry with its cache-bust flag.)

- [ ] **Step 6: Retire-the-predecessor note** — remind the user: the private `shots` skill in `spotless/.claude/skills/shots/` shares trigger phrases with hypershots; remove or rename it in the spotless repo when adopting hypershots there.

---

## Self-review (done at plan-writing time)

- **Spec coverage:** thesis/positioning → T15; four gears → T6/T7 (render+validate), T10 (translate), T14 (style-edit), revise is docs-only (T11); genmedia bootstrap → T9 preflight + T12 SKILL.md; workspace → T9; frame/theme split → T5 + T13; fonts vendored → T4; profiles + iPad-note → T4/T11; validator rules incl. untagged-ICC → T7; CI/frontmatter → T2/T3; examples → T13; README → T15; catalog link + shots retirement → T16. Google Play, RTL/CJK, landscape, dark-mode: roadmap-only per spec (documented in T11/T15, no build tasks — intentional).
- **Placeholders:** none — every script/config is complete; reference-doc tasks enumerate their full required content.
- **Type consistency:** `render.sh <ws> <profile> <locale>` signature matches validate.sh/edit-pass.sh/tests; boxes.json shape (`{fitFailures, boxes:[{name,x,y,w,h}]}`) consistent across fit.js → render.sh → make-mask.mjs; profile key `iphone-6.9` used everywhere; workspace layout identical in scaffold.sh, tests, create.md, SKILL.md.
