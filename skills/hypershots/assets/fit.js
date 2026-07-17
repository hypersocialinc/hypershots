/* HyperShots fit + boxes dump. Include LAST in every panel:
   <script src="fit.js"></script>
   Contract: [data-fit] on shrinkable copy blocks (optional data-fit-floor, px);
   [data-protect="name"] on regions the style-edit must preserve.
   Dump shape: { panelW, panelH, fitFailures, boxes, shots, copy, mockups } —
   boxes are the [data-protect] regions (mask input), shots are the .shot
   capture regions (coordinate reference only, never masked), copy is the
   marketing-copy font-size census (legibility QA), mockups are [data-mockup]
   hand-built screen regions (real-capture QA). */
(async () => {
  await document.fonts.ready;
  const root = document.documentElement;
  const cs = getComputedStyle(root);
  const panelW = parseFloat(cs.getPropertyValue('--panel-w'));
  const panelH = parseFloat(cs.getPropertyValue('--panel-h'));
  const deviceTop = panelH * parseFloat(cs.getPropertyValue('--device-top-ratio'));
  const failures = [];
  if (!isFinite(deviceTop) || !isFinite(panelW) || !isFinite(panelH)) failures.push('frame-vars-missing');
  for (const el of document.querySelectorAll('[data-fit]')) {
    const maxBottom = el.dataset.fitMax ? parseFloat(el.dataset.fitMax) : deviceTop - 14;
    const floor = el.dataset.fitFloor ? parseFloat(el.dataset.fitFloor) : 26;
    // the copy block from the fit element down must clear maxBottom: shrinking
    // the headline pulls trailing siblings (e.g. .sub) up out of the device zone
    const blockBottom = () => {
      let b = el.getBoundingClientRect().bottom;
      for (let s = el.nextElementSibling; s; s = s.nextElementSibling)
        b = Math.max(b, s.getBoundingClientRect().bottom);
      return b;
    };
    let size = parseFloat(getComputedStyle(el).fontSize);
    while (blockBottom() > maxBottom && size > floor) {
      size -= 1;
      el.style.fontSize = size + 'px';
    }
    if (blockBottom() > maxBottom) {
      failures.push(el.dataset.i18n || el.className || 'unnamed');
    }
  }
  const boxes = [...document.querySelectorAll('[data-protect]')].map(el => {
    const r = el.getBoundingClientRect();
    return { name: el.dataset.protect || el.className,
             x: r.x, y: r.y, w: r.width, h: r.height };
  });
  // capture-region boxes, dumped under a SEPARATE key: make-mask.mjs consumes
  // `boxes` wholesale, and a .shot region must never join the protect mask.
  const shots = [...document.querySelectorAll('.shot')].map(el => {
    const r = el.getBoundingClientRect();
    return { name: 'shot', x: r.x, y: r.y, w: r.width, h: r.height };
  });
  // marketing-copy census: every text-bearing element in .wrap, except the
  // eyebrow (sanctioned-small decoration). The legibility judgement lives
  // downstream (render.sh warns, make-review flags) — fit.js only measures.
  const copy = [...document.querySelectorAll('.wrap *')]
    .filter(el => !el.closest('.eyebrow'))
    .filter(el => [...el.childNodes].some(n =>
      n.nodeType === 3 && n.textContent.trim().length >= 3))
    .map(el => ({ name: el.dataset.i18n || el.className || el.tagName.toLowerCase(),
                  px: Math.round(parseFloat(getComputedStyle(el).fontSize) * 10) / 10 }));
  // mockup census: hand-built in-device UI marked data-mockup (App Review
  // 2.3.3 wants real app content). Boxes make invented UI impossible to ship
  // silently — render.sh warns, the review page banners the panel.
  const mockups = [...document.querySelectorAll('[data-mockup]')].map(el => {
    const r = el.getBoundingClientRect();
    return { name: el.dataset.mockup || 'mockup', x: r.x, y: r.y, w: r.width, h: r.height };
  });
  // debug grid: render.sh --grid sets --hs-grid:1 in the generated profile.css.
  // 50px CSS-space lines + labeled coordinates every 100px, drawn over the
  // panel (z-index 90, no layout impact — absolute + pointer-events:none).
  if (cs.getPropertyValue('--hs-grid').trim() === '1') {
    const grid = document.createElement('div');
    grid.style.cssText = 'position:absolute;left:0;top:0;width:' + panelW + 'px;height:' + panelH +
      'px;z-index:90;pointer-events:none;background:' +
      'repeating-linear-gradient(to right,rgba(255,0,128,.55) 0 1px,transparent 1px 50px),' +
      'repeating-linear-gradient(to bottom,rgba(255,0,128,.55) 0 1px,transparent 1px 50px)';
    for (let y = 0; y <= panelH; y += 100) {
      for (let x = 0; x <= panelW; x += 100) {
        const t = document.createElement('div');
        // labels near the right edge anchor left of their line so they don't clip
        const anchor = x + 46 > panelW
          ? 'right:' + (panelW - x + 2) + 'px' : 'left:' + (x + 2) + 'px';
        t.style.cssText = 'position:absolute;' + anchor + ';top:' + (y + 1) +
          'px;font:9px ui-monospace,Menlo,monospace;color:#ff0080;' +
          'background:rgba(255,255,255,.75);padding:0 2px;line-height:11px';
        t.textContent = x + ',' + y;
        grid.appendChild(t);
      }
    }
    (document.querySelector('.panel') || document.body).appendChild(grid);
  }
  const dump = document.createElement('script');
  dump.type = 'application/json';
  dump.id = 'hypershots-boxes';
  dump.textContent = JSON.stringify({ panelW, panelH, fitFailures: failures, boxes, shots, copy, mockups });
  document.body.appendChild(dump);
})();
