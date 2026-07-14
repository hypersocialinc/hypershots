# Translate gear

Localize an existing set: text swap + re-render, not a re-design. Contracts and schema details live in `i18n.md`.

`<skill>` = installed skill dir, `<ws>` = your workspace (default `.shots`).

## Runbook

1. **Extract keys** from the source panels:
   ```bash
   cd <ws> && grep -ho 'data-i18n="[^"]*"' panels/*.html | sort -u
   ```
2. **Write `<ws>/strings.<locale>.json`** (schema in `i18n.md`). You translate — there is no external MT step. Rules:
   - Keep proper nouns, the app name, and product-specific score/tier names untranslated unless the user says otherwise.
   - Match the register of the source copy (punchy marketing lines, not literal gloss).
   - `<br>` in a source string is a designed line break — keep or re-place it deliberately.
3. **Inject:**
   ```bash
   node <skill>/scripts/translate-inject.mjs <ws> <locale>
   ```
   Writes `<ws>/panels-<locale>/panel-N.html`.
4. **Render the locale:**
   ```bash
   bash <skill>/scripts/render.sh <ws> <profile> <locale>
   ```
   Any locale other than `en` renders from `panels-<locale>/`; output goes to `out/<profile>/<locale>/`.
5. **Read each localized PNG.** Auto-fit handles length (longer German headline shrinks until the copy block clears the device). You check what fit can't: bad line breaks, one-word orphan lines, awkward hyphenless wraps, a `<br>` now splitting mid-phrase. Fix the string, re-inject, re-render.
6. **Validate + contact sheet** as in create.md steps 8–9.

## Injection contract (enforced fatally by the script)

- Every key in the strings file MUST be used by some panel — an unused key is a typo or an unmarked element, i.e. English would silently ship. Exit 1.
- Every `data-i18n` element MUST have a translation — missing keys are listed and exit 1.
- Translated element content is text + `<br>` only; any other nested markup is rejected (exit 1) because it corrupts the injector's body match.
- Markers must be double-quoted (`data-i18n="p1.headline"`); single-quoted attributes are invisible to the injector.

**Atomicity:** a failed inject writes nothing (outputs are buffered until all checks pass). A successful inject purges stale `panels-<locale>/*.html` from previous runs before writing — a removed panel cannot survive.

## Caveats

- **Overlay-only by default:** in-frame screenshots (`.shot` captures) stay source-language. Honest default — matches how teams ship. Per-locale captures can be swapped into `assets/` and referenced per-locale, but that's extra authoring.
- **Launch scope: latin + latin-ext.** Vendored fonts cover Western/Central/Eastern European — incl. Turkish, Polish, Czech, Romanian, Hungarian; Vietnamese partially (see `i18n.md` for the coverage table). **RTL + CJK = roadmap**: needs a Noto fallback stack + `dir` handling. Don't ship a locale whose glyphs silently fall back to system-ui.
