# Gotchas

Failure modes this pipeline was hardened against. Symptom → cause → fix. If something looks wrong, check here before debugging from scratch.

## Double Dynamic Island

**Symptom:** two islands / two status bars stacked at the top of the screen.
**Cause:** `.di` + `.statusbar` added over a real simulator capture — the capture already contains the device's own.
**Fix:** hand-built screens get `.di`/`.statusbar`; real captures (`<img class="shot">`) never do. Pick one per panel.

## Alpha-channel rejection

**Symptom:** App Store Connect rejects the upload (RGBA PNG).
**Cause:** any transparent pixel — classically a panel smaller than the render window leaving a transparent gutter.
**Fix:** already handled twice. render.sh prevents it at the source (`--default-background-color=FFFFFFFF`, panel sized by profile variables so there's no gutter); validate.sh flattens any surviving alpha in place with ImageMagick, or FAILs with instructions if magick is absent. If validate reports alpha, something bypassed render — don't hand-place PNGs.

## Remote font @import

**Symptom:** panels render in fallback fonts, or metrics shift between runs/machines.
**Cause:** `@import url(fonts.googleapis.com/…)` — a network fetch that silently loses the race against Chrome's `--virtual-time-budget`, plus Google updates font builds so metrics drift over time.
**Fix:** fonts are vendored (`fonts.css` + `fonts/`, copied into the workspace by scaffold). New fonts must be vendored the same way — local woff2 + `@font-face`, never a remote import.

## Fit measured before fonts load

**Symptom:** copy fits in the render but the boxes/shrink decisions look wrong; or would, if the gate were removed.
**Cause:** measuring text in fallback-font metrics before the real face arrives.
**Fix:** fit.js awaits `document.fonts.ready` before measuring — which only protects you if fit.js is the LAST element in `<body>`. Render fails with "no boxes dump — is fit.js included last in the panel?" when it's missing.

## Copy overlaps the device instead of "overflowing"

**Symptom (prevented):** a long localized headline pushes `.sub` down onto the device frame — nothing overflows the panel, so naive overflow checks pass.
**Cause:** the panel is fixed-height; excess copy collides with the device, it doesn't scroll.
**Fix:** the fit budget is the **device top** (− 14px), and blockBottom is sibling-aware — shrinking the `[data-fit]` headline must pull the whole trailing copy block clear. Floor breach = exit 2 = rewrite the copy.

## Stretched screenshots in the frame

**Symptom:** the in-frame app capture looks squashed or stretched.
**Cause:** capture aspect doesn't match the screen's ~0.460 w/h and something overrode `.shot`.
**Fix:** use `<img class="shot">` as-is: `object-fit:cover; object-position:top center` top-anchor cover-crops mismatched captures (bottom pixels lost, nothing distorted). Prefer captures at ~0.460 aspect (e.g. 1206×2622).

## Render exit codes

**1** generic (Chrome/panels/profile problems — check the kept `panel-N.chrome.log`), **2** fit failure (rewrite the copy, not the floor), **3** profile.css not linked. Full table: create.md, render step.

## validate.sh failed — what to do

- **dims** → rendered at the wrong profile, or a hand-placed file. Re-render at the intended profile.
- **alpha** → install ImageMagick (`brew install imagemagick`) so validate can flatten in place, or re-render.
- **non-sRGB ICC** → something other than the shipped render.sh produced the file. Re-render (it passes `--force-color-profile=srgb`).
- **count > 10** → trim the set to ≤10 panels per device size per localization.
- **missing/dirty boxes.json** → the PNG was not produced by a clean render. Re-render; never hand-place files in `out/`.

## Stale outputs

**Symptom:** a deleted/renamed panel still shows up in `out/`, or an old translation survives.
**Cause:** trusting leftover files.
**Fix:** the pipeline purges for you — render.sh deletes `out/<profile>/<locale>/panel-*` before rendering; translate-inject purges `panels-<locale>/*.html` on success. Never hand-place files in `out/`: validate.sh requires each PNG's clean `.boxes.json` sibling precisely so a hand-placed PNG can't get blessed.

## Sticker shadows bleeding outside protect boxes

**Symptom:** in a protected style-edit, a hard rectangle of un-graded pixels hugs the device or a sticker.
**Cause:** `.cutout`/`.chip`/`.gradeBadge` drop shadows extend well beyond their layout boxes; an exact-box mask cuts through the shadow.
**Fix:** the style-edit mask pads protect boxes ~85px and feathers the edges (built into `scripts/make-mask.mjs`, which `scripts/edit-pass.sh` runs for you; see edit-filter.md). Nothing to do at author time except keep `data-protect` on the right elements.

## Cross-machine pixel differences

**Symptom:** the "same" render differs by a few pixels between macOS and Linux CI.
**Cause:** font antialiasing/hinting differs across OS + Chrome versions.
**Fix:** none needed — the determinism claim is scoped to one machine + one Chrome version per set. Store compliance is unaffected. Render a whole set (all locales) on one machine.

## profile.css is generated per render

**Symptom:** panels render at the wrong size, or a diff shows profile.css churning.
**Cause:** `profile.css` is written by render.sh into the workspace on every run — it's the current profile's dims.
**Fix:** don't commit it, don't hand-edit it, and run renders **sequentially**: two concurrent renders of *different* profiles in one workspace race on the shared file.

## Zero data-protect elements

**Symptom:** a protected style-edit grades right over the copy and device — nothing was protected.
**Cause:** panels authored without `data-protect` markers; `boxes.json` has an empty `boxes` array.
**Fix:** author `data-protect` on `.wrap` and `.device` from panel one (create.md step 5). It costs nothing at create time and can't be reconstructed from the PNG later.
