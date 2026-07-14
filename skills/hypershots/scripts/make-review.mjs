#!/usr/bin/env node
// HyperShots review page: an App Store-style gallery of the rendered set.
// Usage: node make-review.mjs <workspace> [profile] [locale...]
// Locales default to every locale dir under out/<profile>/. Writes
// out/<profile>/review.html (self-contained; images by relative path).
import { readFileSync, writeFileSync, readdirSync, statSync, existsSync } from 'node:fs';
import { join, resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const die = (msg) => { console.error(`ERROR: ${msg}`); process.exit(1); };

const [ws, profile = 'iphone-6.9', ...localeArgs] = process.argv.slice(2);
if (!ws) die('usage: make-review.mjs <workspace> [profile] [locale...]');

const KIT = resolve(dirname(fileURLToPath(import.meta.url)), '..'); // skills/hypershots
const profiles = JSON.parse(readFileSync(join(KIT, 'profiles.json'), 'utf8'));
const prof = profiles[profile];
if (!prof) die(`unknown profile: ${profile}`);
const [OW, OH] = prof.out;

const profileDir = join(ws, 'out', profile);
if (!existsSync(profileDir) || !statSync(profileDir).isDirectory())
  die(`no renders at ${profileDir} — run render.sh first`);

const locales = localeArgs.length
  ? localeArgs
  : readdirSync(profileDir).filter(d => statSync(join(profileDir, d)).isDirectory()).sort();
if (!locales.length) die(`no locale dirs under ${profileDir}`);

const esc = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;')
  .replace(/>/g, '&gt;').replace(/"/g, '&quot;');

// Headline caption: pN.headline text from the workspace panel source
// (panels/ for en, panels-<locale>/ otherwise). Best-effort — null on any miss.
function headline(locale, n) {
  const src = locale === 'en' ? 'panels' : `panels-${locale}`;
  try {
    const html = readFileSync(join(ws, src, `panel-${n}.html`), 'utf8');
    const m = html.match(new RegExp(
      `<([a-z0-9]+)\\b[^>]*\\sdata-i18n="p${n}\\.headline"[^>]*>([\\s\\S]*?)</\\1>`));
    if (!m) return null;
    const text = m[2].replace(/<br\s*\/?>/gi, ' ').replace(/<[^>]+>/g, '')
      .replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>')
      .replace(/&quot;/g, '"').replace(/&#39;/g, "'")
      .replace(/\s+/g, ' ').trim();
    return text || null;
  } catch { return null; }
}

const sections = locales.map(locale => {
  const dir = join(profileDir, locale);
  if (!existsSync(dir)) die(`locale dir not found: ${dir}`);
  const files = readdirSync(dir);
  const panels = files.map(f => f.match(/^panel-(\d+)\.png$/)).filter(Boolean)
    .map(m => Number(m[1])).sort((a, b) => a - b);
  if (!panels.length) die(`no panel PNGs in ${dir}`);
  const styled = new Set(files.map(f => f.match(/^panel-(\d+)\.styled\.png$/))
    .filter(Boolean).map(m => Number(m[1])));

  const cards = panels.map((n, i) => {
    const clean = `${locale}/panel-${n}.png`;
    const styledAttr = styled.has(n) ? ` data-styled="${esc(`${locale}/panel-${n}.styled.png`)}"` : '';
    const cap = headline(locale, n);
    // Apple shows ~3 portrait shots before "Show All" — mark the fold after
    // panel 3 (or after the last panel when the whole set fits pre-fold).
    const fold = i === Math.min(2, panels.length - 1)
      ? `\n      <div class="fold"><span>visible before &ldquo;Show All&rdquo;</span></div>` : '';
    return `      <figure>
        <img src="${esc(clean)}" data-clean="${esc(clean)}"${styledAttr} alt="panel ${n} (${esc(locale)})">
        <figcaption><b>panel ${n}</b>${cap ? `<span>${esc(cap)}</span>` : ''}</figcaption>
      </figure>${fold}`;
  }).join('\n');

  const toggle = styled.size ? `
    <div class="styled-toggle" role="group" aria-label="variant">
      <button class="on" data-mode="clean" type="button">clean</button>
      <button data-mode="styled" type="button">styled</button>
    </div>` : '';

  return `  <section class="locale" data-locale="${esc(locale)}"${locale === locales[0] ? '' : ' hidden'}>
    <div class="meta"><h2>${esc(locale)}</h2>${toggle}</div>
    <div class="strip">
${cards}
    </div>
  </section>`;
}).join('\n');

const tabs = locales.length > 1 ? `
  <nav class="tabs">${locales.map((l, i) =>
    `<button${i === 0 ? ' class="on"' : ''} data-locale="${esc(l)}" type="button">${esc(l)}</button>`).join('')}</nav>` : '';

const html = `<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>HyperShots review — ${esc(profile)}</title>
<style>
  :root{ --bg:#111; --card:#1c1c1e; --ink:#f2f2f7; --mid:#98989f; --rule:#3a3a3c; --blue:#0a84ff }
  *{ margin:0; box-sizing:border-box }
  body{ background:var(--bg); color:var(--ink); font:15px/1.45 -apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif }
  header{ padding:22px 28px 14px; border-bottom:1px solid var(--rule) }
  header h1{ font-size:21px; font-weight:700; letter-spacing:-.3px }
  header .sub{ color:var(--mid); font-size:13px; margin-top:4px }
  header code{ font:12px ui-monospace,SFMono-Regular,Menlo,monospace; color:var(--mid) }
  .tabs{ display:flex; gap:8px; padding:14px 28px 0 }
  .tabs button, .styled-toggle button{ background:var(--card); color:var(--mid); border:1px solid var(--rule);
    border-radius:999px; padding:6px 16px; font-size:13px; font-weight:600; cursor:pointer }
  .tabs button.on, .styled-toggle button.on{ background:var(--blue); border-color:var(--blue); color:#fff }
  section.locale{ padding:18px 28px 8px }
  .meta{ display:flex; align-items:center; gap:14px; margin-bottom:12px }
  .meta h2{ font-size:15px; font-weight:600; color:var(--mid); text-transform:uppercase; letter-spacing:1.5px }
  .strip{ display:flex; align-items:flex-start; gap:18px; overflow-x:auto; padding:4px 2px 18px }
  figure{ flex:none }
  figure img{ height:520px; width:auto; display:block; border-radius:22px;
    background:var(--card); box-shadow:0 1px 0 rgba(255,255,255,.06) inset, 0 8px 28px rgba(0,0,0,.5) }
  figcaption{ max-width:240px; padding:10px 4px 0; font-size:13px }
  figcaption b{ display:block; color:var(--mid); font-weight:600 }
  figcaption span{ color:var(--ink) }
  .fold{ flex:none; align-self:stretch; display:flex; align-items:center;
    border-left:2px dashed var(--rule); padding-left:8px }
  .fold span{ writing-mode:vertical-rl; font-size:11px; letter-spacing:1px;
    text-transform:uppercase; color:var(--mid); white-space:nowrap }
  footer{ padding:14px 28px 26px; color:var(--mid); font-size:13px; border-top:1px solid var(--rule) }
</style></head><body>
<header>
  <h1>HyperShots review — ${esc(profile)} (${OW}×${OH})</h1>
  <div class="sub">${new Date().toISOString().slice(0, 10)} · <code>bash &lt;skill&gt;/scripts/validate.sh &lt;ws&gt; ${esc(profile)} &lt;locale&gt;</code> before shipping</div>
</header>${tabs}
${sections}
<footer>Give feedback by panel number — e.g. &ldquo;panel 3: shorter headline&rdquo;. The revise gear takes it from there.</footer>
<script>
  document.querySelectorAll('.tabs button').forEach(b => b.addEventListener('click', () => {
    document.querySelectorAll('.tabs button').forEach(x => x.classList.toggle('on', x === b));
    document.querySelectorAll('section.locale').forEach(s => s.hidden = s.dataset.locale !== b.dataset.locale);
  }));
  document.querySelectorAll('.styled-toggle button').forEach(b => b.addEventListener('click', () => {
    const sec = b.closest('section');
    sec.querySelectorAll('.styled-toggle button').forEach(x => x.classList.toggle('on', x === b));
    const styled = b.dataset.mode === 'styled';
    sec.querySelectorAll('img[data-clean]').forEach(img => {
      img.src = (styled && img.dataset.styled) || img.dataset.clean;
    });
  }));
</script>
</body></html>
`;

const outFile = join(profileDir, 'review.html');
writeFileSync(outFile, html);
const abs = resolve(outFile);
console.log(abs);
console.log(`open ${abs}`);
