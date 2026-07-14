---
name: hypershots
description: "Generate spec-reliable App Store screenshots from deterministic HTML/CSS panels, with optional AI-generated sticker assets and style grading. Use when the user wants App Store / store listing screenshots, marketing panels with device frames, screenshot localization or translation ('translate my screenshots'), or asks about Apple screenshot sizes and specs. Not for general image generation, social graphics, or capturing in-app screenshots from a simulator."
---

# HyperShots — spec-reliable App Store screenshots

Deterministic where it must be (HTML/CSS: device frames, fonts, copy, exact canvas, locales), generative only where it helps (cutout stickers, optional style grade). You author bespoke panel HTML per app; the scripts guarantee the specs.

## When to use / when not

Use for: App Store screenshot sets, localizing an existing set, revising panels, "make my screenshots cooler", Apple screenshot-spec questions. NOT for: general image generation, social/OG images, capturing simulator screenshots (→ fastlane snapshot), uploading to ASC (→ fastlane deliver).

## Intent router

| User wants | Read first | Then |
|---|---|---|
| New screenshot set | `references/create.md` | scaffold → brief → theme → author → render → self-review → validate |
| Tweak headline/sticker/theme | `references/revise.md` | edit → re-render → re-validate |
| Localize an existing set | `references/translate.md` + `references/i18n.md` | extract keys → strings.<locale>.json → inject → render → validate |
| Stylized/graded look | `references/edit-filter.md` | `edit-pass.sh` per panel, `grade-set.sh` for a set-consistent pass (needs genmedia + ImageMagick) |
| Generated stickers/backgrounds | `references/asset-recipes.md` | pinned genmedia recipes + degraded mode |
| Need captures / mid-gesture frames | `references/capture-recipes.md` | simctl status-bar/appearance/burst recipes |
| Apple size/spec question | `references/store-specs.md` | canvas table, asset rules |
| Something looks wrong | `references/gotchas.md` | symptom → cause → fix |

## Prerequisites (every session)

```bash
bash <skill>/scripts/preflight.sh
```

Always exits 0 — it's a report, not a gate. `chrome` and `node` are **REQUIRED**: if either is missing, stop and help the user install (or `export CHROME=/path/to/chrome`). `imagemagick` is optional (alpha flatten, style-edit compositing). `genmedia` is optional — needed only for generated assets or a style grade; if missing and the task wants those, **ask the user before installing**: `npm i -g genmedia && genmedia setup` (needs their `FAL_KEY`), then `genmedia skills install genmedia && genmedia skills install fal-models-catalog`. If they decline, use degraded mode (`references/asset-recipes.md`).

## The frame contract

The part every agent must hold even without reading `create.md`:

- Geometry classes are IMMUTABLE (`.panel` `.stage` `.device` `.screen` `.di` `.statusbar`) — sized by profile CSS variables (`--panel-w`/`--panel-h`). Never hardcode panel px, never restyle `.device`. Screen aspect is ~0.460 (w/h). Type classes (`.headline` `.sub` `.eyebrow`) MAY be restyled in theme.css — that's the brand layer's job (fit.js measures actual boxes, so size/weight changes are safe).
- `.stage` is the required absolute layer (`inset:0`) holding the device AND the stickers as siblings — omit it and the device loses its positioning context (wrong but validating).
- NEVER add `.di`/`.statusbar` over a real simulator capture (`<img class="shot">` already contains its own status bar + island) — double-DI bug.
- REQUIRED markers on every panel: `data-i18n="pN.key"` (double-quoted, one line, text + `<br>` only — no other nested markup) on every translatable node; `data-fit` on the headline/sub block; `data-protect="name"` on `.wrap` and `.device`.
- `fit.js` must be the LAST element in `<body>` — it awaits `document.fonts.ready` and dumps the fit/protect boxes render.sh needs.
- Panels must not depend on time, randomness, or animation — render.sh does two Chrome passes (screenshot + DOM dump) and they must agree.
- Full authoring skeleton, sticker primitives, narrative-arc guidance: `references/create.md`.

## Workspace

```bash
bash <skill>/scripts/scaffold.sh [dir=.shots]
```

Runs in the **user's repo** — the installed skill dir is read-only reference, never author there. Refuses to run if `<ws>/brief.md` already exists (you're in revise territory). Panels link kit copies as workspace-sibling paths (`../frame.css`, `../theme.css`, etc.). If `examples/spotless/panels/panel-1.html` exists in your copy of the skill, read it as an annotated example before authoring your first panel.

## The loop that makes output good — mandatory

```
render.sh → Read every rendered PNG yourself → fix → re-render → validate.sh → review page (make-review.mjs) + contact sheet → show the user
```

Read each PNG and check: copy overflow or awkward breaks, clipped/overlapping stickers, `.di`/`.statusbar` double-island, legibility (ink-on-paper contrast, accent not vibrating), stretched/mis-cropped capture. **Never skip the Read** — the validator checks specs, not taste; only your eyes catch a clipped sticker.

`render.sh <ws> [profile=iphone-6.9] [locale=en]` exit codes: **1** generic (no Chrome, no panels, Chrome crash, unknown profile — check `profiles.json`); **2** fit failure (copy hit the floor and still overlaps the device — rewrite the copy, not the floor); **3** panel dims ≠ profile (almost always `../profile.css` missing from the panel `<head>`).

## Common mistakes

`.di`/`.statusbar` over a real capture; hardcoding panel px or restyling `.device` (breaks profiles → gutters → alpha → rejection); a remote font `@import` in theme.css (fonts must be vendored, `font-display:block`); hand-editing `out/` or `panels-<locale>/` (both generated — render purges `out/`, a successful inject purges stale `panels-<locale>/*.html`); skipping `validate.sh` because it "looks right"; re-rendering iPhone panels at `ipad-13` (ipad is a separate authoring pass, 0.75 aspect); single-quoted `data-i18n` (invisible to the injector — ships English, surfaces later as a fatal unused-key error).

## Review checklist (before showing the user)

- [ ] `validate.sh` prints `VALIDATED` for every shipped profile+locale
- [ ] You Read every PNG after the last edit
- [ ] ≤10 panels; the first 3 carry the install decision (only ~3 show before "Show All")
- [ ] Every panel has its markers: `data-i18n`, `data-fit`, `data-protect`
- [ ] Theme is derived from the app's actual brand, not the scaffold's placeholder tokens

## Verify

- Check every command/flag/exit-code claim above against the actual scripts before relying on it — this file summarizes; the scripts are ground truth.
- `npm run validate` (repo root — checks SKILL.md frontmatter) and `bash tests/run-tests.sh` (fixture render/validate/translate suite) should both be green before you consider a skill change done.
