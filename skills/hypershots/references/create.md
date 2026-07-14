# Create gear

Author a fresh screenshot set from app captures + a brief. Run the steps in order — the self-review loop (step 7) is the reliability mechanism, not optional polish.

`<skill>` = the installed skill directory (read-only reference). All authored files live in the user's repo workspace (`<ws>`, default `.shots/`).

## 1. Preflight

```bash
bash <skill>/scripts/preflight.sh
```

Always exits 0 — it's a report, you decide what to do:

- `chrome`, `node` — **REQUIRED**. Missing either: stop and tell the user how to install (or `export CHROME=/path/to/chrome`).
- `imagemagick` — optional: alpha flattening in validate, contact sheets, style-edit compositing.
- `genmedia` — optional: AI sticker assets + style grade. Missing: degrade (see `asset-recipes.md` for the consent-gated bootstrap and the fully-supported no-genmedia paths). Never block on it.

## 2. Scaffold

```bash
bash <skill>/scripts/scaffold.sh          # default: .shots
bash <skill>/scripts/scaffold.sh <dir>    # custom workspace dir
```

Refuses to run if `<ws>/brief.md` already exists (workspace already scaffolded — you're in revise territory). Creates:

- `panels/`, `assets/`, `out/` — empty dirs
- `frame.css`, `fit.js`, `fonts.css`, `fonts/`, `profiles.json` — copied from the skill, pinned per workspace
- `theme.css` — placeholder tokens you MUST replace (step 4)
- `brief.md` — the questionnaire (step 3)

The installed skill dir stays read-only reference; never author or edit files there.

## 3. Brief questionnaire

Ask the user in ONE message, mirroring the scaffolded `brief.md` fields:

1. App name / one-line positioning
2. Captures provided (files to drop in `assets/`)
3. Panel count + per-panel headline & sub
4. Stickers / generated assets wanted (or none)
5. Device profile(s) — default `iphone-6.9`
6. Locales — default `en`

Write the answers into `<ws>/brief.md`. It persists across create → revise → translate runs.

## 4. Theme

Derive `<ws>/theme.css` from the app's **real brand** — sample colors from the actual captures in `assets/`, check the app's icon/site. **Never ship the scaffold's placeholder values unchanged.**

Required tokens (consumed by frame.css — all of them):

```
--paper --paper-hi --ink --mid --rule --accent --badge-bg --badge-ink
--font-sans --font-mono
```

Fonts: the kit vendors **Inter Tight** (variable 400–900, normal+italic) and **IBM Plex Mono** (400/500/600), latin + latin-ext subsets. Using other fonts requires vendoring the woff2 into the workspace with `@font-face` — **NEVER a remote `@import`**: it breaks offline determinism, races Chrome's `--virtual-time-budget`, and upstream font builds drift metrics.

## 5. Author panels

Write `<ws>/panels/panel-1.html` … `panel-N.html`. Bespoke HTML per app — there is no fill-in template, but the STRUCTURE below is required.

**Minimal panel skeleton** (adapt the content, keep the structure; hrefs are workspace-sibling — render.sh generates `profile.css` next to `panels/`):

```html
<!doctype html><html><head><meta charset="utf-8">
<link rel="stylesheet" href="../fonts.css">
<link rel="stylesheet" href="../frame.css">
<link rel="stylesheet" href="../theme.css">
<link rel="stylesheet" href="../profile.css">
<style>/* per-panel styles for in-screen content go here — never restyle frame classes */</style>
</head><body>
<div class="panel">
  <div class="wrap" data-protect="copy">
    <div class="eyebrow"><b data-i18n="p1.eyebrow">Check before you go</b><i></i></div>
    <div class="headline" data-fit data-i18n="p1.headline">How clean is your<br>favorite restaurant?</div>
    <div class="sub" data-i18n="p1.sub">You might not want to know.</div>
  </div>
  <div class="stage">
    <div class="device" data-protect="device"><div class="screen">
      <!-- REAL simulator capture: this img ONLY — it already contains its own
           status bar + Dynamic Island -->
      <img class="shot" src="../assets/capture-1.png">
      <!-- HAND-BUILT screen instead: replace .shot with your markup PLUS these
           two (never combine them with a real capture):
      <div class="di"></div>
      <div class="statusbar"><span class="time">9:41</span><span class="icons"></span></div>
      -->
    </div></div>
    <img class="cutout" src="../assets/sticker.png"
         style="left:-24px;top:388px;width:134px;transform:rotate(-8deg)">
  </div>
</div>
<script src="../fit.js"></script>   <!-- LAST element in <body> -->
</body></html>
```

Structure notes:

- `.wrap` is the copy block above the device (z-index 2). `.stage` is the absolute-positioned layer (`inset:0`, z-index 1) that holds the device AND the stickers — omit it and the device loses its positioning context, producing a wrong-but-validating panel. Stickers live in `.stage` as siblings of `.device`, not inside `.screen`.
- An annotated example set ships in `examples/spotless/` — if absent in your copy of the skill, the contract in this file is complete on its own.

**Frame contract** (frame.css is the geometric contract — do not restyle it):

- IMMUTABLE: `.panel` dims, `.device` geometry, `.screen` aspect, `.di` / `.statusbar` positions. Profile variables (`--panel-w`/`--panel-h`) size everything; anchors are ratios of panel size, so the same panel renders at any near-aspect iPhone profile.
- Real simulator captures go in `<img class="shot" src="../assets/capture.png">` inside `.screen`. They already contain the device's own status bar and island — **never add `.di`/`.statusbar` over a real capture** (double-Dynamic-Island bug). Use `.di` + `.statusbar` only on hand-built screens.
- Screen aspect is ~0.460 (w/h). Captures should match; `.shot` top-anchor cover-crops (`object-fit:cover; object-position:top center`) so slightly-taller captures lose bottom pixels, not get stretched.

**Marker rules** (create-time discipline that makes translate and style-edit mechanical later — full contract in `i18n.md`):

- `data-i18n="pN.key"` on EVERY translatable text node. **Double quotes only** — the injector's regex matches double-quoted attributes. Content on one line: text + `<br>` only; the injector fatally rejects any other nested markup inside a marked element. Wrap styled fragments in their own marked elements instead.
- `data-fit` on the headline (optionally `data-fit-floor="px"`, default floor 26; `data-fit-max="px"` to override the budget). Fit shrinks the element 1px at a time until it **and all its following siblings** clear the device top (budget = device-top − 14px) — shrinking the headline pulls `.sub` up out of the device zone too. Floor breach = fit failure = render exit 2.
- `data-protect="name"` on `.wrap` (e.g. `"copy"`) and `.device` (e.g. `"device"`). Render dumps their on-screen boxes to `boxes.json`; the style-edit builds its protection mask from them. Zero `data-protect` elements = nothing to protect later. Author them from panel one.

**Determinism contract:** panels must not depend on time, randomness, or animations. render.sh does two Chrome passes per panel — screenshot, then DOM dump — and they must agree; anything nondeterministic makes the boxes lie about the pixels.

**Sticker primitives** (from frame.css; position via inline `left/top/width` + `transform:rotate()`):

- `.cutout` — transparent-PNG die-cut sticker (`<img class="cutout" src="../assets/x.png" style="left:-24px;top:388px;width:134px;transform:rotate(-8deg)">`)
- `.chip` — white pill with bold value (`9.6<small>/10</small>`)
- `.pin` — map-pin callout with tail
- `.gradeBadge` — square letter-grade badge
- `.emoji` — plain emoji glyph with drop shadow (zero-dependency sticker)

Negative left/right offsets that bleed off the panel edge are fine — `.panel` clips. Sticker drop shadows extend beyond their boxes; the style-edit mask pads for it.

**Narrative arc** (from the shipped Spotless set): shock/hook → map/core value → trust/data-source → share/delight → bonus. The FIRST 3 panels are all most visitors see (see `store-specs.md`) — they carry the install decision. Lead with the emotional hook, not the feature list.

## 6. Render

```bash
bash <skill>/scripts/render.sh <ws> [profile=iphone-6.9] [locale=en]
```

What it does: resolves the profile → writes `<ws>/profile.css` (generated, do not edit/commit) → purges `out/<profile>/<locale>/panel-*` → for each panel runs Chrome twice (screenshot at exact device-scale canvas; DOM dump to extract fit results + protect boxes) → writes `panel-N.png` + `panel-N.boxes.json`.

Chrome discovery: `$CHROME` env override → macOS app path → `google-chrome`/`chromium`/`chromium-browser` on PATH. Each Chrome call has a 180s watchdog.

Exit codes:

- **1** — generic failure: no Chrome, no panels in the source dir, Chrome crash, missing boxes dump (fit.js not included last), or unknown profile (check `profiles.json` for valid names; this fails **before** `profile.css` is written — workspace untouched).
- **2** — **fit failure**: copy hit the font-size floor and still overlaps the device. The fix is a copy rewrite, not a smaller floor. No artifacts left for the failed panel.
- **3** — panel dims ≠ profile dims: almost always `../profile.css` missing from the panel head — see the `<link>` order in the skeleton above.

On any per-panel failure the PNG and partial boxes.json are deleted (no orphans for validate to bless) and `out/<p>/<l>/panel-N.chrome.log` is kept for debugging.

## 7. Self-review loop — MANDATORY

Read every rendered PNG with the Read tool and check:

- Copy overflow or awkward line breaks?
- Stickers clipped, overlapping copy, or covering the wrong UI?
- `.di`/`.statusbar` stacked on a real capture (double island)?
- Theme legible — contrast of ink on paper, accent not vibrating?
- Screenshot inside the frame stretched or mis-cropped?

Fix panels/theme → re-render → re-Read. Loop until clean. **Never skip this** — the validator checks specs, not taste; only your eyes catch a clipped sticker.

## 8. Validate

```bash
bash <skill>/scripts/validate.sh <ws> [profile=iphone-6.9] [locale=en]
```

Checks: exact dims for the profile; ≤10 panels; no alpha (flattens in place if ImageMagick present, otherwise FAILs with install instructions); ICC untagged-or-sRGB; and **every PNG must have a clean `.boxes.json` sibling** — a PNG without one was not produced by a clean render and fails. Run after every render; a set that hasn't passed is not deliverable.

## 9. Review page + contact sheet

```bash
node <skill>/scripts/make-review.mjs <ws> iphone-6.9    # locales default to all rendered
```

Writes `out/<profile>/review.html` — an App Store-style gallery strip (locale tabs, fold line after panel 3, headline captions, clean/styled toggle). Open it / show it to the user for sign-off; feedback arrives by panel number. If your runtime can publish an HTML artifact (e.g. Claude Code's Artifact tool), publish a copy with images downscaled to ~600px and inlined as data URIs (artifact sandboxes block local file paths); otherwise the local file is the review surface.

The contact sheet remains the quick-share secondary artifact:

```bash
cd <ws> && magick montage out/<profile>/<locale>/panel-*.png -tile 5x1 -geometry +8+8 contact-sheet.png
```

Adjust `-tile Nx1` to the panel count.
