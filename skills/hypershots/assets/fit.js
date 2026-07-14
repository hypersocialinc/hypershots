/* HyperShots fit + boxes dump. Include LAST in every panel:
   <script src="fit.js"></script>
   Contract: [data-fit] on shrinkable copy blocks (optional data-fit-floor, px);
   [data-protect="name"] on regions the style-edit must preserve. */
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
  const dump = document.createElement('script');
  dump.type = 'application/json';
  dump.id = 'hypershots-boxes';
  dump.textContent = JSON.stringify({ panelW, panelH, fitFailures: failures, boxes });
  document.body.appendChild(dump);
})();
