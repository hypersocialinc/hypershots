#!/usr/bin/env node
// Build the style-grade masks from a render's protect boxes.
// Usage: make-mask.mjs <boxes.json> <outW> <outH> <scale> <mask.png> <feather.png>
//   mask.png    hard mask for the edit API: transparent = EDIT, opaque white = keep
//   feather.png composite mask: white-on-black, blurred; white = take ORIGINAL pixels
// Boxes are CSS px from getBoundingClientRect (includes transforms); scale to
// output px and pad for shadow bleed (see references/gotchas.md).
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';

const [bj, Ws, Hs, Ss, mask, feather] = process.argv.slice(2);
if (!feather) {
  console.error('usage: make-mask.mjs <boxes.json> <outW> <outH> <scale> <mask.png> <feather.png>');
  process.exit(1);
}
const W = Number(Ws), H = Number(Hs), scale = Number(Ss);
if (!(W > 0 && H > 0 && scale > 0)) {
  console.error(`ERROR: bad dims/scale: ${Ws} ${Hs} ${Ss}`);
  process.exit(1);
}
const PAD = 85; // css px — covers .device box-shadow (bottom extent ~82) + sticker drop-shadows
const { boxes } = JSON.parse(readFileSync(bj, 'utf8'));
if (!Array.isArray(boxes) || !boxes.length) {
  console.error('ERROR: no [data-protect] boxes in ' + bj + ' — protected mode has nothing to protect. That is an authoring bug (see create.md marker rules): add data-protect to the copy block + device, re-render, and retry.');
  process.exit(1);
}
const draws = boxes.flatMap(b => {
  const x0 = Math.max(0, (b.x - PAD) * scale), y0 = Math.max(0, (b.y - PAD) * scale);
  const x1 = Math.min(W, (b.x + b.w + PAD) * scale), y1 = Math.min(H, (b.y + b.h + PAD) * scale);
  return ['-draw', `rectangle ${x0},${y0} ${x1},${y1}`];
});
// style grade is IM7-only (no IM6 fallback here, unlike validate.sh)
function magick(args) {
  try { return execFileSync('magick', args); }
  catch (e) {
    if (e.code === 'ENOENT') {
      console.error("ERROR: 'magick' not found (ImageMagick 7 'magick' binary required)");
      process.exit(1);
    }
    throw e;
  }
}
// hard mask: transparent canvas (=edit), opaque white rects (=keep).
// PNG32: forces RGBA — ImageMagick otherwise optimizes low-transparency masks
// to an alpha-less colortype, and the edit API reads the alpha channel.
magick(['-size', `${W}x${H}`, 'xc:none', '-fill', 'white', ...draws, `PNG32:${mask}`]);
// composite mask: white-on-black, feathered (white = take ORIGINAL pixels)
magick(['-size', `${W}x${H}`, 'xc:black', '-fill', 'white', ...draws, '-blur', `0x${6 * scale}`, '-alpha', 'off', feather]);
console.log(`masks written: ${mask}, ${feather} (${boxes.length} boxes, pad ${PAD}css)`);
