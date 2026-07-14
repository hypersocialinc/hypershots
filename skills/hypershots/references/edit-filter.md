# Style grade (optional edit pass)

Whole-panel image-to-image grade over a finished, validated render — watercolor wash, film grade, illustrated look. OFF by default.

`<skill>` = installed skill dir, `<ws>` = your workspace (default `.shots`).

> **Shipped:** `scripts/edit-pass.sh` runs this whole contract per panel — needs `genmedia` + ImageMagick (see SKILL.md prerequisites):
>
> ```bash
> bash <skill>/scripts/edit-pass.sh <ws> <profile> <locale> <panel-N> "<style prompt>" [protected|full]
> # e.g. edit-pass.sh .shots iphone-6.9 en panel-2 "risograph print style, warm duotone" protected
> ```

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

**Palette-shift caveat (verified live):** the composite restores the ORIGINAL colors inside the protected halos, so a prompt that shifts the overall palette hard (e.g. a flat gray paper turning ochre) leaves the protection rectangles visible against the graded background, and the model may paint artifacts right along the mask edge. Grades that keep the panel's overall palette (grain, texture, subtle duotone within the theme's hues) blend best; for drastic re-colors prefer `full` mode on a text-light panel, or restyle the theme and re-render instead.

## Consistency across a set

Use the SAME style prompt for every panel of a set, plus an optional shared reference image, or the five panels come back in five different styles.

## Cost

Check current pricing before running a whole set:

```bash
genmedia pricing openai/gpt-image-2/edit
```
