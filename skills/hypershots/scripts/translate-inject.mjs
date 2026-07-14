#!/usr/bin/env node
// Usage: node translate-inject.mjs <workspace> <locale>
// Reads panels/*.html + strings.<locale>.json -> writes panels-<locale>/*.html
// Atomic: nothing is written unless every key resolves AND every key is used.
import { readFileSync, writeFileSync, mkdirSync, readdirSync, unlinkSync } from 'fs';
import { join } from 'path';

const [ws, locale] = process.argv.slice(2);
if (!ws || !locale) { console.error('usage: translate-inject.mjs <workspace> <locale>'); process.exit(1); }
const parsed = JSON.parse(readFileSync(join(ws, `strings.${locale}.json`), 'utf8'));
const strings = parsed.strings;
if (!strings || typeof strings !== 'object' || Array.isArray(strings)) {
  console.error(`ERROR: strings.${locale}.json has no "strings" object`); process.exit(1);
}
const outDir = join(ws, `panels-${locale}`);

const used = new Set(), missing = new Set();
const outputs = [];  // buffered [file, html] — written only after all checks pass
for (const f of readdirSync(join(ws, 'panels')).filter(f => f.endsWith('.html'))) {
  let html = readFileSync(join(ws, 'panels', f), 'utf8');
  html = html.replace(
    /(<([a-z0-9]+)\b[^>]*\sdata-i18n="([^"]+)"[^>]*>)([\s\S]*?)(<\/\2>)/g,
    (m, open, tag, key, body, close) => {
      // tripwire: nested markup inside a translated element corrupts the
      // non-greedy body match — only <br> line breaks are tolerated
      if (/</.test(body.replace(/<\/?br\s*\/?>/gi, ''))) {
        console.error(`ERROR: data-i18n="${key}" in ${f} wraps nested markup (only <br> allowed inside a translated element)`);
        process.exit(1);
      }
      if (!(key in strings)) { missing.add(key); return m; }
      used.add(key);
      return open + strings[key] + close;
    });
  outputs.push([f, html]);
}
if (missing.size) { console.error('MISSING translations: ' + [...missing].join(', ')); process.exit(1); }
// unused keys are fatal: strings files are authored per-panel, so a leftover
// key means a typo'd/unmarked element — i.e. English would silently ship
const unused = Object.keys(strings).filter(k => !used.has(k));
if (unused.length) { console.error('unused keys (typo or unmarked element?): ' + unused.join(', ')); process.exit(1); }

mkdirSync(outDir, { recursive: true });
for (const f of readdirSync(outDir).filter(f => f.endsWith('.html'))) unlinkSync(join(outDir, f));
for (const [f, html] of outputs) writeFileSync(join(outDir, f), html);
console.log(`injected ${used.size} strings -> ${outDir}`);
