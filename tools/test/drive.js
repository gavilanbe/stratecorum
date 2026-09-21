// Uso: node drive.js "<query>" "<pasos>"   pasos separados por ';'  →  w:ms | c:x,y | s:nombre | e:js | h:x,y | d:x1,y1,x2,y2
const puppeteer = require('puppeteer-core');
const path = require('path');
(async () => {
  const [query, steps, outDir] = process.argv.slice(2);
  const OUT = outDir || path.join(__dirname, 'shots'); require('fs').mkdirSync(OUT, { recursive: true });
  const browser = await puppeteer.launch({ executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', headless: 'new', args: ['--mute-audio', '--window-size=1152,700'] });
  const page = await browser.newPage();
  const MOB = process.env.MOB; if (MOB === 'p') await page.setViewport({ width: 390, height: 844, isMobile: true, hasTouch: true, deviceScaleFactor: 2 }); else if (MOB) await page.setViewport({ width: 844, height: 390, isMobile: true, hasTouch: true, deviceScaleFactor: 2 }); else await page.setViewport({ width: 1152, height: 648 });
  const errors = [];
  page.on('pageerror', e => errors.push('PAGEERROR ' + e.message));
  page.on('console', m => { if (m.type() === 'error') errors.push('CONSOLE ' + m.text()); });
  await page.goto((process.env.FILE || 'file://' + require('path').resolve(__dirname, '../../web/index.html')) + (query || ''));
  const L = async (x, y) => { const r = await page.evaluate(() => { const r = cv.getBoundingClientRect(); return { l: r.left, t: r.top, w: r.width, h: r.height }; }); return { x: r.l + x / 384 * r.w, y: r.t + y / 216 * r.h }; };
  for (const st of (steps || '').split('§').map(s => s.trim()).filter(Boolean)){
    const k = st[0], a = st.slice(2);
    if (k === 'w') await new Promise(r => setTimeout(r, +a));
    else if (k === 's') await page.screenshot({ path: path.join(OUT, a + '.png') });
    else if (k === 'c'){ const [x, y] = a.split(',').map(Number); const p = await L(x, y); if (MOB) await page.touchscreen.tap(p.x, p.y); else { await page.mouse.move(p.x, p.y); await page.mouse.down(); await page.mouse.up(); } }
    else if (k === 'h'){ const [x, y] = a.split(',').map(Number); const p = await L(x, y); await page.mouse.move(p.x, p.y); }
    else if (k === 'd'){ const [x1, y1, x2, y2] = a.split(',').map(Number); const p = await L(x1, y1), q = await L(x2, y2); await page.mouse.move(p.x, p.y); await page.mouse.down(); for (let i = 1; i <= 8; i++){ await page.mouse.move(p.x + (q.x - p.x) * i / 8, p.y + (q.y - p.y) * i / 8); await new Promise(r => setTimeout(r, 20)); } await page.mouse.up(); }
    else if (k === 'k'){ const xy = await page.evaluate(a); const p = await L(xy[0], xy[1]); if (MOB) await page.touchscreen.tap(p.x, p.y); else { await page.mouse.move(p.x, p.y); await page.mouse.down(); await page.mouse.up(); } }
    else if (k === 'f'){ const v = await page.evaluate(require('fs').readFileSync(a, 'utf8')); if (v !== undefined) console.log('EVAL', JSON.stringify(v)); }
    else if (k === 'e'){ const v = await page.evaluate(a); if (v !== undefined) console.log('EVAL', JSON.stringify(v)); }
  }
  if (errors.length) console.log(errors.join('\n'));
  await browser.close();
})();
