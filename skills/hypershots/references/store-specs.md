# Store screenshot specs

Exact canvas sizes and asset rules the store enforces. **Verified 2026-07 — re-verify at Apple's screenshot-specifications page before trusting.**

`profiles.json` + `scripts/validate.sh` are the executable form of this table. If Apple changes a size, update all three together — a doc-only edit changes nothing the pipeline enforces.

## Apple App Store (portrait)

| Profile | Device class | Exact px | Notes |
|---|---|---|---|
| `iphone-6.9` | iPhone 6.9″ | 1290×2796 | **Default.** The only *required* iPhone size — Apple auto-scales it down for smaller devices. |
| `iphone-6.9-alt` | iPhone 6.9″ | 1320×2868 | Alternate accepted canvas for the same slot. |
| `iphone-6.5` | iPhone 6.5″ | 1284×2778 | Legacy slot, still accepted. Only needed if you want to control the smaller rendition instead of letting Apple downscale. (Apple also accepts 1242×2688 — no shipped profile; add one to profiles.json if you need it.) |
| `ipad-13` | iPad 13″ | 2064×2752 | Required **only if the app ships an iPad build**. (Apple also accepts 2048×2732 — no shipped profile.) |

App Store Connect's old **"6.7 inch"** label is the same slot as 6.9″ — one slot under two names, not two sizes to fill.

## Asset rules (what validate.sh enforces)

- **File size:** max **8 MB** per screenshot — `validate.sh` enforces it.
- **Format:** Apple accepts PNG or JPG; this pipeline produces and validates **PNG only** (render.sh writes .png, validate.sh globs `panel-*.png` — a stray .jpg is invisible to it).
- **Alpha:** flattened, NO alpha channel. An RGBA PNG is rejected at upload. `render.sh` prevents it at the source (`--default-background-color=FFFFFFFF`); `validate.sh` flattens in place with ImageMagick if one slips through.
- **ICC profile:** untagged or sRGB. Headless Chrome emits **untagged** PNGs and ASC treats untagged as sRGB — a validator that *required* an sRGB tag would fail every correct render. `validate.sh` accepts untagged (`<nil>`), `*sRGB*`, and `*IEC 61966*`; anything else fails.
- **Count:** max 10 per device size per localization. `validate.sh` fails an 11-panel set.
- **Visibility:** only the first ~3 portrait screenshots show on the product page before "Show All" — and app preview videos, if any, come first. Panels 1–3 carry the install decision.

## One set = one device class

A panel set targets ONE device class:

- **Near-aspect iPhone profiles re-render.** The same `panels/` render correctly at `iphone-6.9`, `iphone-6.9-alt`, and `iphone-6.5` because the frame contract sizes everything from `--panel-w`/`--panel-h`.
- **iPad is a separate authoring pass.** `ipad-13` is 0.75 aspect — a phone layout stretched to it looks wrong and the phone-frame device makes no sense on an iPad listing. Author iPad panels fresh from the same brief. Never re-render iphone panels at `ipad-13`.

## Google Play — ROADMAP (not implemented)

Not in `profiles.json` yet. When it lands: phone screenshots 1080×1920 (each side min 320px, max 3840px), plus a 1024×500 feature graphic. Documented here so nobody invents numbers.
