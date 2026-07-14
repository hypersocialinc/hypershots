# HyperShots — App Store screenshot skill (design)

**Date:** 2026-07-13 (rev 2 — post three-lens subagent review: technical feasibility, skill-design conventions, product/positioning)
**Status:** design, pending user review
**Repo:** `github.com/hypersocialinc/hypershots` (standalone, public, MIT)
**Install:** `npx skills add hypersocialinc/hypershots --skill hypershots --agent claude-code`

## Purpose

A reusable agent skill that produces **spec-reliable, multi-language App Store
screenshots** by rendering deterministic HTML/CSS panels (device frames, fonts,
marketing copy, exact canvas dimensions) and using generative AI **only** where it
helps — cut-out asset stickers, photographic backgrounds, and an *optional*
whole-panel style grade.

Extracted and generalized from the pipeline built for Spotless (`spotless/.shots/`),
which produced the shipped v1.0 App Store set.

## Thesis (why this approach)

> **Deterministic where it must be, generative only where it helps.**

Full-image generation fails for anything spec-bound: device frames come out at
inconsistent radii/tilts/proportions, app UI gets stretched, text is redrawn as
warped "AI text," and dimensions never land on Apple's exact canvas. The frame and
canvas are **pure geometry** — an agent expresses that perfectly in CSS
(arithmetic); an image model approximates it (statistics).

- **Deterministic (HTML/CSS + headless Chrome):** device frame, screen aspect,
  Dynamic Island/status bar, fonts, copy, layout, exact canvas, per-locale text.
- **Generative (GPT Image 2 → BiRefNet v2):** cut-out stickers, photographic
  backgrounds, optional post-render style grade.

Scope of the determinism claim: pixel-identical **within one machine + Chrome
version per set** (cross-OS antialiasing differs; store compliance is unaffected).

## Positioning (honest — the category is not empty)

Existing players the README must name and differentiate against:
- **ParthJadhav/app-store-screenshots** (~6.1k★): agent-scaffolded Next.js editor,
  multi-store, multi-locale.
- **adamlyttleapps/claude-skill-aso-appstore-screenshots** (~1.6k★): deterministic
  Pillow scaffold + AI polish pass.
- **fastlane frameit**: frames-only, dated aesthetics. **AppScreens /
  AppLaunchpad / Screenshots.pro**: template/editor SaaS.

Ownable combination (no surveyed tool has all four): (a) the **validator** — "your
set cannot be rejected for asset specs" is checkable; (b) **translate mode with
auto-fit** as a first-class gear; (c) the **generative cutout-sticker pipeline**;
(d) the **protected style grade** (mask + re-composite).

**Pitch:** "App Store screenshots that pass validation the first time, in every
language — deterministic HTML where Apple has rules, generative AI where it sells."

Name check: npm + GitHub clean; `hypershots.app` is taken (unrelated) — use
`hypershots.dev` or none. Keep the name.

## Operations (four gears, one skill)

SKILL.md opens with an **intent router table** (create / revise / translate /
style-edit → reference file), following the proven `shots`-predecessor shape.

### 1. `create`
Author a fresh set from app captures + a brief.
- **Brief questionnaire** (one message): captures, positioning, panel count,
  per-panel headline/sub, assets/stickers wanted, device profile(s), locale(s).
- The agent authors bespoke panel HTML per app (no fill-in templates), cloning the
  frame kit + one annotated gold example, deriving a per-app **theme layer**
  (colors/fonts/texture) from the brand — never shipping Spotless's theme.
- Panels are authored with **`data-i18n` markers on every translatable node** and
  **`data-protect` on frame/text regions** (create-time rules that make translate
  and style-edit mechanical later).
- **Mandatory self-review loop:** render → **agent Reads the rendered PNG**
  (overflow, clipped stickers, DI collisions) → `validate.sh` → contact sheet to
  the user. This loop, not the examples, is the reliability mechanism.

### 2. `revise`
The most common real request ("change panel 3's headline"): edit the workspace
HTML → re-render → re-validate. Cheap; must be first-class.

### 3. `translate`
Existing set → localized variants. Text-swap + re-render, not a re-design.
- Extract strings via the `data-i18n` markers → `strings.<lang>.json` (schema in
  `references/i18n.md`) → translate → re-inject → re-render to
  `out/<profile>/<locale>/`.
- **Auto-fit mechanism (`fit.js`, shipped with the kit):** in-page script that
  (1) awaits `document.fonts.ready`, (2) for each `[data-fit]` block decrements
  font-size until `getBoundingClientRect().bottom <= var(--device-top) - margin`
  (the failure mode is **overlap with the device**, not overflow — Spotless's
  Spanish set needed a hand 40px shrink; this automates it), (3) has a floor size
  that fails loudly ("copy needs a rewrite") instead of shrinking forever.
- Default localizes the **marketing overlay** only; screenshots inside the frame
  stay source-language unless per-locale captures are provided (honest default,
  matches how teams actually ship).
- Launch scope: **Latin/Cyrillic scripts.** RTL + CJK documented as roadmap (needs
  Noto fallback stack + direction handling in `i18n.md`).

### 4. Style-edit (render option, not a top-level mode)
Optional per-panel image-to-image grade via GPT Image 2 edit. Off by default,
non-destructive (`panel-N.styled.png` beside the clean render).

**Pipeline (all steps mandatory — reviewer-verified against the live fal schema):**
1. Upload render (+ mask in `protected` mode) to fal CDN.
2. Edit at nearest multiple-of-16 size — gpt-image-2 **cannot output our exact
   canvases** (1284/1290/1320 aren't multiples of 16).
3. Resample styled output back to the exact canvas.
4. **Re-composite protected regions from the original render on top** (feathered
   mask edges). The model re-generates the whole canvas; the mask is *guidance*,
   the composite is the *pixel guarantee*. Without this step "protected" mode
   still ships AI-warped text.
5. Validate.

**Modes:** `protected` (default) — mask from **render-time
`getBoundingClientRect()` of `[data-protect]` elements** (includes transforms;
authored CSS boxes don't), padded ~60–80px for shadow bleed, dumped to
`boxes.json` by the render pass. `full` — unmasked, for text-light hero panels.
Consistency across a set via a shared style prompt + optional reference image.

## Asset generation (via `genmedia` — a soft dependency the skill bootstraps)

The original review flagged `genmedia` as Hypersocial-internal; **verified false**:
it is a public npm CLI ("AI media generation CLI powered by fal.ai") maintained by
a fal.ai employee — effectively fal's official agent-first CLI, with
`setup --non-interactive` for agents/CI and its own skills registry. Keeping it
beats a hand-rolled REST script: fal maintains polling/upload/retries, `genmedia
upload` covers the style-edit CDN step, `genmedia schema` gives self-serve
parameter discovery, and the user's own `FAL_KEY` powers it either way.

- **Bootstrap preflight (consent-gated, never silent):** if `genmedia` is missing,
  the skill *offers* to install it via the official channel (verify current
  channel — npm shows an older beta than the shipping binary — at implementation
  time); then `genmedia setup --non-interactive` with the user's `FAL_KEY` if
  unconfigured; then `genmedia skills install genmedia fal-models-catalog` so the
  authoring agent knows the CLI and can pick the best current endpoint for an
  asset rather than being frozen to a hardcoded model.
- `references/asset-recipes.md` pins the **proven known-good default**: GPT Image 2
  die-cut sticker prompt → BiRefNet v2 → transparent PNG, using `--download` on
  the generation call (no grep-parsing of output URLs). The `fal-models-catalog`
  skill is the sanctioned upgrade path when better endpoints land.
- **Graceful degradation is a hard requirement:** create/revise/translate work
  fully with user-provided PNGs, plain emoji glyphs, or no stickers. Only asset
  generation and style-edit need genmedia + `FAL_KEY`. The deterministic half is
  never hostage to the generative half.
- Preflight step 1 in SKILL.md: check Chrome/Chromium (required), genmedia +
  `FAL_KEY` (optional → offer bootstrap → degrade), ImageMagick (optional,
  validator fix-ups).

## Components / repo layout

```
hypershots/
  README.md                     # landing page (outline below)
  LICENSE                       # MIT + OFL notices for vendored fonts
  .github/workflows/validate.yml# runs validate-skills.mjs (installer silently
  scripts/validate-skills.mjs   #   drops skills with bad frontmatter)
  skills/hypershots/
    SKILL.md                    # frontmatter + router + contract (below)
    agents/openai.yaml          # Codex support (catalog convention)
    assets/
      frame.css                 # geometric frame contract ONLY (see split below)
      fit.js                    # fonts.ready + auto-fit + boxes.json dump
      fonts/                    # vendored woff2 (Inter Tight, IBM Plex Mono, OFL)
    references/
      store-specs.md            # dated Apple (+ Play roadmap) spec table
      create.md / revise.md / translate.md / edit-filter.md / i18n.md
      asset-recipes.md          # sticker/photo prompts (never call them "Apple emoji")
      gotchas.md                # alpha, sRGB, DI clash, font races, shadows
    scripts/
      scaffold.sh               # init workspace in the USER'S repo
      render.sh                 # per-profile canvas; opaque bg; no `|| true`
      preflight.sh              # deps check + consent-gated genmedia bootstrap
      edit-pass.sh              # upload→edit→resample→re-composite→validate
      validate.sh               # reads profiles/store-specs; sips check, magick fix
    profiles.json               # device profiles (CSS w/h + scale)
    examples/spotless/          # panel HTML w/ annotation comments + small contact
                                # sheet — NOT five full-res PNGs (installer copies
                                # the whole dir into every agent)
```

**SKILL.md contract (per catalog conventions — validate-skills.mjs enforced):**
- Frontmatter: `name: hypershots` (must equal dir name) + quoted `description`
  packed with trigger phrases ("app store screenshots", "localize screenshots",
  "screenshot specs") and non-triggers (general image gen, social graphics).
- Sections: When to Use/When Not → intent router → prerequisites preflight →
  **frame contract** (immutable: `.device` geometry, screen aspect 318/691, never
  restyle the frame, never add a fake status bar over real captures; variable:
  theme layer) → brief questionnaire → do/don't pairs (headline length budget,
  sticker z-order, first-3 install-sheet rule) → ordered steps with the mandatory
  render-and-Read self-review loop → Common Mistakes → Review Checklist.
- Directs the agent to read one annotated example before authoring.

**frame.css split (review finding — as-is it ships Spotless's brand):**
(a) immutable geometric contract — `.device`, `.screen`, `.di`, `.statusbar`,
sticker primitives, canvas plumbing; (b) a **theme layer** of `:root` tokens +
fonts the agent derives per app. Fonts vendored via `@font-face` (no Google Fonts
`@import` — network-dependent, silently falls back under `--virtual-time-budget`,
and Google updates font builds so metrics drift).

## Workspace contract (where agent-authored files live)

The installed skill dir is read-only reference. `scaffold.sh` initializes a
workspace in the **user's repo** (default `.shots/`):

```
.shots/
  brief.md                      # the answered questionnaire
  panels/panel-N.html           # agent-authored, data-i18n + data-protect marked
  theme.css                     # per-app theme layer
  frame.css fit.js profiles.json# copied from the skill (pinned per workspace)
  assets/                       # captures + generated/user-provided art
  strings.<lang>.json           # translate gear
  out/<profile>/<locale>/       # rendered + validated PNGs, boxes.json, contact sheet
```

State persists across create → revise → translate → style-edit runs.

## Rendering & profiles

Verified arithmetic: 428×926 @3 = 1284×2778 (shipped set), 430×932 @3 = 1290×2796,
440×956 @3 = 1320×2868, iPad **@2**: 1032×1376 = 2064×2752, 1024×1366 = 2048×2732.

- Panel dimensions come from **per-profile CSS custom properties** (injected via a
  per-profile override sheet), with key anchors (device `top`) relative to panel
  height — a hardcoded 428×926 panel rendered in a 430×932 window leaves a
  transparent gutter → RGBA PNG → **App Store rejection**.
- A panel set targets **one device class**. Near-aspect iPhone profiles re-render;
  **iPad (0.75 aspect) is a separate authoring pass from the same brief**, not a
  free re-render.
- `render.sh`: opaque `--default-background-color` (alpha fixed at the source, not
  just in the validator), `--force-color-profile=srgb`, screenshot gated on
  `document.fonts.ready` (via fit.js), Chrome path discovery (`$CHROME` env →
  Chrome → chromium; Linux/CI documented, `npx playwright` as fallback), and **no
  `|| true`** — a swallowed Chrome crash must fail the build, because the
  validator can't distinguish a correct render from a correctly-sized blank one.

## Store-spec compliance

Compliance = HTML (control) + profile (right canvas) + **validator (enforcement)**.

`references/store-specs.md` (dated; validator reads this table rather than
hardcoding constants):

| Device class | Exact px (portrait) | Notes |
|---|---|---|
| iPhone 6.9″ | 1290×2796 or 1320×2868 | the only *required* iPhone size; Apple auto-scales down. **Default profile; examples re-rendered at this size for launch** |
| iPhone 6.5″ | 1284×2778 or 1242×2688 | legacy slot, still accepted (Spotless shipped it) |
| iPad 13″ | 2064×2752 or 2048×2732 | required only if shipping an iPad build |

(6.7″ is the same ASC slot as 6.9″ under an old name — one slot, not a separate row.)

Rules: PNG/JPG, **flattened (no alpha)**, **untagged or sRGB ICC** (headless Chrome
emits untagged, which ASC treats as sRGB — a validator that *requires* an sRGB
profile would fail every correct render), ≤10 per device size per localization;
first ~3 portrait shots visible before "Show All" (app previews, if any, precede
them).

`validate.sh`: checks with `sips` (always on macOS: dims, hasAlpha, profile),
fixes with ImageMagick when present (`-alpha remove`), fails loudly with
instructions otherwise. Runs after every render.

## README (landing page) outline

1. **Hero:** 5-panel Spotless strip (one wide image) + one-line pitch.
2. **Install one-liner** above the fold.
3. **Killer comparison:** pure-AI generation (melted frame, warped text — we
   generate this bad example deliberately) vs a HyperShots panel.
4. **Translate proof:** EN panel beside its ES twin.
5. **60-second quickstart** ending in the validator's green PASS output.
6. "How it works" (deterministic/generative diagram) · spec table · **"How this
   differs"** (names fastlane + the incumbent skills) · Requirements (Chrome;
   optional genmedia + FAL_KEY) · **Roadmap** · FAQ · License.

Examples note: panels submitted to the App Store (trust signal). Before
publishing: confirm comfort with real businesses/scores on the map panel + map-tile
redistribution terms.

## Scope & roadmap

- **v1: Apple iOS, portrait, Latin/Cyrillic locales.**
- **Roadmap (stated in README to pre-empt the first 10 issues):** Google Play
  (1080×1920 + 1024×500 feature graphic — labeled "good first PR"), iPad
  authoring pass (required with iPad builds — higher priority than it looks),
  landscape, dark-mode sets (cheap via theme tokens), RTL/CJK, provider choice
  beyond fal/genmedia, simulator-capture pointer (fastlane snapshot), app-preview video
  (out of scope; future bridge: the `transparent-video` skill).

## Migration / ecosystem

- **Supersedes the private `shots` skill** (identical trigger phrases, opposite
  philosophy — full-image GPT composites); retire it in projects adopting
  hypershots and say so in the README.
- Add a "Related skills (hosted elsewhere)" entry in
  `hypersocial-agent-skills/README.md` (the `instax-print` precedent).

## Non-goals (YAGNI)

- No fill-in-the-blank template library (agent authors bespoke panels).
- No unmasked full-panel edit as default (opt-in only).
- No app-preview video in v1.
- No upload to App Store Connect (that's `fastlane deliver`'s job; this skill
  produces the assets a deliver lane consumes).
