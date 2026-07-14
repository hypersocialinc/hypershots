# Style grade (optional edit pass)

Whole-panel image-to-image grade over a finished, validated render — watercolor wash, film grade, illustrated look. OFF by default.

`<skill>` = installed skill dir, `<ws>` = your workspace (default `.shots`).

> **Shipped:** `scripts/edit-pass.sh` runs this whole contract per panel — needs `genmedia` + ImageMagick (see SKILL.md prerequisites):
>
> ```bash
> bash <skill>/scripts/edit-pass.sh <ws> <profile> <locale> <panel-N> "<style prompt>" [protected|full] [style-ref]
> # e.g. edit-pass.sh .shots iphone-6.9 en panel-2 "risograph print style, warm duotone" protected
> ```
>
> The optional `style-ref` (local file — uploaded for you — or http(s) URL) is sent as a second reference image and the prompt is extended to match its grading exactly; `grade-set.sh` uses it to keep a whole set in one look (see "Set makeover" below).

## When to offer

Only when the user asks for a stylized / "cooler" / illustrated / graded look. Never apply by default — the clean deterministic render is the product.

## Non-destructive contract

- Output is `panel-N.styled.png` **beside** the clean render; the clean `panel-N.png` is never overwritten.
- Re-rendering a profile/locale purges its `out/` panels **including styled outputs** (render.sh deletes `panel-*.png` first) — always style-grade last, after the set is final.
- The clean render stays the store deliverable unless the user explicitly picks the styled one — and then the styled file must ALSO pass `validate.sh` before it ships.

## Pipeline (all steps mandatory)

1. **Upload** the clean render (+ the mask, in protected mode) to the fal CDN: `genmedia upload <file> --json`.
2. **Edit** with GPT Image 2 edit at the **nearest multiple-of-16 canvas** — the model cannot output store dims exactly (1290/1284/1320 aren't multiples of 16). The endpoint takes `image_size` as a `{"width","height"}` JSON object and `image_urls` as a JSON array — free-form `"WxH"` strings and bare URL strings are 422s.
3. **Resample** the styled output back to the exact store canvas.
4. **Re-composite protected regions** from the original render on top, through a feathered mask. This step is the guarantee: the model re-generates the WHOLE canvas — the mask sent to the API is *guidance*, the composite is the *pixel guarantee*. Skipping it ships AI-warped text and a melted device frame in "protected" mode.
5. **Validate** the styled PNG like any deliverable (dims/alpha/ICC). `edit-pass.sh` writes a `panel-N.styled.boxes.json` sibling (copied from the clean render — identical geometry) so `validate.sh`'s proof-of-clean-render check can bless the styled file; run `validate.sh` before shipping it.

## Modes

- **protected (default):** mask built from the render-time `[data-protect]` boxes in `panel-N.boxes.json` (live `getBoundingClientRect`, so transforms are included), padded ~85px for sticker/device shadow bleed. Copy block + device survive pixel-perfect; background and stickers get the grade.
- **full:** unmasked, the whole panel is re-generated. Only for text-light hero panels where warped glyphs can't happen because there are barely any.

If a panel's `boxes.json` has zero protect boxes, protected mode has nothing to protect — that's an authoring bug (see create.md marker rules), not a reason to fall back to full.

**Full-canvas protection (verified live):** the inverse failure. On a full-bleed layout — copy block spanning the top plus a large device — the padded protect union can cover the ENTIRE canvas. Protected mode then has nothing to edit: the composite would restore every pixel, and the model returns junk for an all-opaque mask (a blank paper texture in the live test), so the API call is a guaranteed paid no-op. `edit-pass.sh` detects this after building the mask and refuses **before** any upload. The outs are the same as for hard palette shifts: `full` mode on a text-light panel, or restyle the theme and re-render.

**Palette-shift caveat (verified live):** the composite restores the ORIGINAL colors inside the protected halos, so a prompt that shifts the overall palette hard (e.g. a flat gray paper turning ochre) leaves the protection rectangles visible against the graded background, and the model may paint artifacts right along the mask edge. Grades that keep the panel's overall palette (grain, texture, subtle duotone within the theme's hues) blend best; for drastic re-colors prefer `full` mode on a text-light panel, or restyle the theme and re-render instead.

## Set makeover (consistent pass)

When the user wants the WHOLE set restyled, the honest recipe is:

1. **Theme restyle first.** Palette, texture, and fonts belong in `theme.css` — a re-render is deterministic, seam-free, and free. Re-render beats re-paint for *design* changes; only reach for the edit pass when the ask is atmosphere.
2. **Grade second** for atmosphere (grain, lighting, print feel) — one command for the set:

```bash
bash <skill>/scripts/grade-set.sh <ws> <profile> <locale> "<style prompt>" [protected|full]
# e.g. grade-set.sh .shots iphone-6.9 en "warm risograph print, soft grain" protected
```

**How the anchor works:** the lowest-numbered panel is graded first with no reference — that styled output becomes the set's anchor. Every remaining panel is then graded with the anchor passed as a style-reference image (panel first in `image_urls`, anchor second) and the prompt extended to match its grading exactly. Same prompt + shared anchor is what keeps N panels in ONE look instead of N drifting interpretations. On a mid-set failure the script stops, keeps the styled panels already written (non-destructive), and a re-run resumes safely — styled outputs are simply overwritten.

**Seams:** the palette-shift caveat above applies set-wide — grades that keep each panel's overall palette blend best in `protected` mode; hard palette shifts either go `full` on text-light panels or ship with visible protection seams. Restyling the theme and re-rendering is the seam-free answer for re-colors. And the full-canvas-protection caveat gates the whole feature: if the set's layout leaves no unprotected background, `edit-pass.sh` refuses the first panel before spending anything — a protected set makeover needs panels with real editable background, otherwise it's `full` mode or a theme restyle.

**Cost:** a set makeover is N panels × the per-edit price — check before running:

```bash
genmedia pricing openai/gpt-image-2/edit
```
