# Asset recipes

Pinned, proven generation recipes — these exact commands produced the stickers in Spotless's shipped App Store set (example set ships in `examples/spotless/` — if absent in your copy, the recipes below are complete on their own). Start here; upgrade models only via the catalog skill.

`<skill>` = installed skill dir, `<ws>` = your workspace (default `.shots`).

All recipes need the `genmedia` CLI (fal.ai). If it's missing, see **Degraded mode** below — never block create/revise/translate on it. Run recipes from the workspace so `--download ./assets/…` lands in the right place:

```bash
cd <ws>
```

## Die-cut cutout sticker (the workhorse)

Two stages: generate on a solid loud background, then strip it with BiRefNet.

```bash
genmedia run openai/gpt-image-2 \
  --prompt "A single die-cut glossy 3D sticker of <SUBJECT>, thick clean white die-cut sticker border around the whole silhouette, centered, on a solid flat bright magenta background, soft studio lighting, high detail, no text" \
  --image_size square_hd --quality high --json
```

Take the output image URL, then:

```bash
genmedia run fal-ai/birefnet/v2 --image_url <URL> \
  --output_format png --download ./assets/<name>.png --json
```

Notes that matter:

- **Solid bright background (magenta/cyan)** → BiRefNet returns a clean matte. Busy or white backgrounds produce halos and eaten edges.
- **Keep "no text"** in the prompt — the model loves captioning stickers, and AI text is exactly what this pipeline exists to avoid.
- Params are `--flags`, not `key=value`. `--image_size` takes presets (`square_hd`, `portrait_16_9`, …), not pixel dims.
- `--download` saves straight into the workspace — no grep-parsing of output URLs.
- Result drops into a panel as `<img class="cutout" src="../assets/<name>.png" style="left:…;top:…;width:…;transform:rotate(…)">`.

## Photographic background

```bash
genmedia run fal-ai/flux/schnell --prompt "<scene>" \
  --image_size portrait_16_9 --download ./assets/<name>.png --json
```

## Picking different models

```bash
genmedia skills install fal-models-catalog
```

Then choose by task from the catalog. Whatever generates the sticker, **keep BiRefNet v2 as the strip stage** — it's the proven matte.

## Degraded mode (no genmedia) — fully supported

- User-provided PNGs dropped into `assets/` (transparent PNGs work as `.cutout` directly).
- Plain emoji via the `.emoji` primitive — zero dependencies, shipped-quality shadow.
- No stickers at all — the frame + copy + capture carry the panel.

The deterministic half of the pipeline is never hostage to the generative half.

## genmedia bootstrap (consent-gated)

If `genmedia` is missing AND the task wants generated assets: **ASK the user first**, then

```bash
npm i -g genmedia && genmedia setup     # needs the user's FAL_KEY
genmedia skills install genmedia && genmedia skills install fal-models-catalog
```

Never install silently. If the user declines, use degraded mode.
