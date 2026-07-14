# Spotless example set

These panels were submitted to the App Store with Spotless v1.0 (July 2026) — this directory is the kit's annotated gold example, ported to the HyperShots contract.

**Assets are not included.** The captures, stickers, photos, and receipt referenced by `../assets/…` stay with the Spotless repo; the HTML structure, marker discipline, and `<!-- why -->` annotations are the reference. See `contact-sheet.png` for the rendered result (panels rendered at 1290×2796, iphone-6.9).

To render it yourself: scaffold a workspace (`bash scripts/scaffold.sh ws`), copy `panels/` and `theme.css` from here into it, drop your own images into `ws/assets/` under the referenced filenames, then `bash scripts/render.sh ws iphone-6.9 en`.

Contents: `brief.md` (the filled questionnaire behind the set), `theme.css` (the brand layer), `panels/panel-1..5.html` (shock → map → trust → share → AI-bonus), `contact-sheet.png`.

`strings.es.json` — the shipped Spanish copy, ready for `translate-inject.mjs` (completes the example as an en+es set).
