# Revise gear

Change an existing set — headline tweak, sticker move, theme fix. The cheapest and most common request.

`<skill>` = installed skill dir, `<ws>` = your workspace (default `.shots`).

## Loop

1. Edit `<ws>/panels/panel-N.html` and/or `<ws>/theme.css`.
2. Re-render every affected profile+locale:
   ```bash
   bash <skill>/scripts/render.sh <ws> <profile> <locale>
   ```
3. Read the changed PNGs (same checklist as create.md step 7).
4. Re-validate:
   ```bash
   bash <skill>/scripts/validate.sh <ws> <profile> <locale>
   ```
5. Regenerate the contact sheet and show the user:
   ```bash
   cd <ws> && magick montage out/<profile>/<locale>/panel-*.png -tile 5x1 -geometry +8+8 contact-sheet.png
   ```
   (`-tile Nx1` = panel count; same command as create.md step 9.)

## Rules

- **Never edit `out/`** — generated; render purges it.
- **Never hand-edit `panels-<locale>/`** — generated; regenerate via `translate-inject.mjs` (the injector purges stale files on success).
- **After copy changes, re-run translate for every shipped locale.** Strings files must stay in sync with the markers: the injector fails on missing keys AND on unused keys, so a renamed/added/removed `data-i18n` key breaks every locale until its `strings.<locale>.json` is updated. See translate.md.
