# Typography — choosing and vendoring fonts

The kit default (Inter Tight + IBM Plex Mono) is a safe utility voice, not a brand. A set that mirrors the app's own type reads like the app's marketing; a set in default type reads like a template. Pick deliberately, then vendor with `scripts/fetch-fonts.sh` (below).

## 1. The hierarchy: mirror the app's real brand FIRST

Before picking anything, find what the app actually uses:

- **Native iOS:** `Info.plist` → `UIAppFonts` array, plus `.ttf`/`.otf` files in the app bundle / Xcode project. No `UIAppFonts` = the app uses SF (system) — the kit default is a fine stand-in.
- **Web / Next.js / React Native:** `tailwind.config.{js,ts}` `fontFamily`, global CSS `@font-face` rules, `next/font` imports (`next/font/google` names the family literally), RN `expo-font`/`useFonts` calls and bundled font assets.
- **Fallback:** the app's marketing site `<head>` and computed styles on its headings.

If the brand font is on Google Fonts (OFL), fetch it directly. If it isn't freely redistributable (SF Pro, proprietary faces, licensed foundry fonts), **do not copy the files** — pick the closest match from the menu below.

## 2. Curated menu — display + body [+ mono]

All Google Fonts, OFL, verified latin + latin-ext. Body/mono defaults to the kit's IBM Plex Mono unless listed. Weights are what to fetch.

| App personality | Display | Body | Why it works |
|---|---|---|---|
| Editorial / food / recipes | **Fraunces** (600;900) | **Inter** (400;700) | Warm wonky serif with real flavor at 900; Inter stays invisible under it. |
| Premium / lifestyle / travel | **Playfair Display** (700;900) | **Source Sans 3** (400;600) | High-contrast didone reads "editorial luxury"; Source Sans is quiet and wide-ranged. |
| Playful / kids / social | **Baloo 2** (700;800) or **Nunito** (700;900) | **Nunito** (400;700) | Rounded terminals read friendly at thumbnail size without going clownish; keep 700+. |
| Bold / sport / fitness | **Archivo** (500;800) | **Archivo** (400;500) | One grotesque family, huge weight span — condensed-feeling 800 headlines, same voice in body. |
| Calm / wellness / sleep | **DM Serif Display** (400) | **DM Sans** (400;700) | A matched pair by design; the serif is soft at display size, DM Sans keeps UI copy airy. |
| Utility / technical / dev tools | **Inter Tight** + **IBM Plex Mono** | (kit default) | Already vendored — zero fetches; tight grotesque + mono eyebrow is the kit's native voice. |

Rationale discipline: pick ONE display voice per set; the body face should disappear. When in doubt between two rows, choose by what the app's own UI feels like, not by the category label.

Verify any family beyond this menu before promising it: `curl` the css2 URL (free, no key) and confirm HTTP 200 with `/* latin */` and `/* latin-ext */` blocks — `fetch-fonts.sh` does this check for you and fails loudly on unknown families.

## 3. Rules (non-negotiable)

- Fonts load **ONLY via workspace `@font-face`** (`<ws>/fonts.css` + `<ws>/fonts/`) — never a remote `@import`: it races Chrome's `--virtual-time-budget` and upstream builds drift metrics (gotchas.md, "Remote font @import").
- Fetch **latin + latin-ext** subsets — localized renders (tr/pl/cs/ro/hu) must not per-glyph fall back to system-ui.
- **Keep OFL notices**: the license file lands in `<ws>/fonts/` next to the woff2 — don't delete it.
- **Headline weight ≥700** for store legibility; the display faces above are chosen to hold up at ~200px-wide thumbnails.

## 4. Fetching

```bash
bash <skill>/scripts/fetch-fonts.sh <ws> "Fraunces" "600;900"
bash <skill>/scripts/fetch-fonts.sh <ws> "Inter"                # weights default to "400;700"
```

Downloads latin + latin-ext woff2 into `<ws>/fonts/`, appends matching `@font-face` rules (unicode-range from the css2 response, `font-display:block`) to `<ws>/fonts.css`, and fetches the family's OFL license. Idempotent: existing files are kept, existing `@font-face` blocks aren't duplicated. Then point `theme.css` at the family:

```css
--font-display:'Fraunces',serif;   /* if you restyle .headline with a separate display face */
--font-sans:'Inter',system-ui,sans-serif;
```
