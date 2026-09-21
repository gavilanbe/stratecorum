// Prueba en línea: dos páginas (anfitrión + invitado) juegan una partida completa con la IA decidiendo por cada humano a través de la interfaz.
const puppeteer = require('puppeteer-core'); const path = require('path');
const FILE = process.env.FILE || 'file://' + path.resolve(__dirname, '../../web/index.html');
const sleep = ms => new Promise(r => setTimeout(r, ms));
const HASH = `(function(){ if(!G) return null; return JSON.stringify({ t:G.stats.turns, cur:G.cur, moves:G.moves, deck:G.deck.map(c=>c.id), disc:G.discard.length, cem:G.cem.map(c=>c.id), seedv:seed,
  P:G.players.map(P=>({h:P.hand.map(c=>c.id).sort(), l:P.lives.map(L=>[L.card.id,L.up,L.dmg,L.att.map(a=>a.id)]), lk:P.luck.map(c=>c.id), m:P.money.map(c=>c.id), a:P.alive, tu:P.turns})), over:G.over, w:G.winner }); })()`;
const STEP = `(function(){ if (APP!=='game' || !G) return 'noapp'; if (G.cur===ME && UI.mode==='idle'){ const s0 = seed; const a = aiAction(ME); seed = s0; UI.resolve(a); return 'act:'+a.type; }
  if (UI.mode==='defend'){ { const s0 = seed; const d = aiDefense(ME, UI.ctx.val, UI.ctx.life); seed = s0; UI.resolve(d); } return 'defend'; } if (UI.mode==='discard'){ UI.resolve(aiDiscard(ME)); return 'discard'; }
  if (UI.mode==='peek'){ const s0 = seed; const L = aiPeek(ME, UI.ctx.tp); seed = s0; UI.resolve(L); return 'peek'; } if (UI.mode==='cem'){ UI.resolve({type:'end'}); return 'cem-end'; } return (G.over ? 'over' : 'wait:'+UI.mode+':'+G.cur) + '@' + (performance.now()/1000|0); })()`;
(async () => {
  const browser = await puppeteer.launch({ executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', headless: 'new', args: ['--mute-audio', '--disable-background-timer-throttling', '--disable-renderer-backgrounding', '--disable-backgrounding-occluded-windows', '--disable-features=CalculateNativeWinOcclusion,IntensiveWakeUpThrottling'] });
  const mk = async name => { const p = await browser.newPage(); await p.setViewport({ width: 768, height: 432 }); p._errs = []; p.on('pageerror', e => p._errs.push(name + ' PAGEERROR ' + e.message)); p.on('framenavigated', f => { if (f === p.mainFrame()) console.log(name, 'NAVIGATED', f.url().slice(-60)); }); p.on('error', e => console.log(name, 'CRASH', e.message)); p.on('console', m => { if (m.type() === 'error' || m.type() === 'warning') p._errs.push(name + ' ' + m.type() + ' ' + m.text()); }); return p; };
  const A = await mk('A'), B = await mk('B'), Cc = process.env.THREE ? await mk('C') : null;
  await A.goto(FILE + '?mute=1' + (process.env.QS || '')); await A.evaluate('NET.open(); NET.create()');
  let code = null; for (let i = 0; i < 100 && !code; i++){ await sleep(200); code = await A.evaluate('NET.on ? NET.code : null'); }
  console.log('sala', code, code ? '' : 'ERROR: no se creó la sala'); if (!code){ console.log(await A.evaluate('JSON.stringify({view:NET.view,err:NET.err,status:NET.status,peer:!!window.Peer})')); console.log(A._errs.join('\n')); await browser.close(); process.exit(1); }
  await B.goto(FILE + '?mute=1' + (process.env.QS || '') + '&sala=' + code);
  if (Cc) await Cc.goto(FILE + '?mute=1&sala=' + code);
  let g = 0; for (let i = 0; i < 100 && g < (Cc ? 2 : 1); i++){ await sleep(200); g = await A.evaluate('NET.guests'); }
  console.log('invitados', g); if (Cc) await A.evaluate('NET.cpus = 1');
  await A.evaluate('NET.start()');
  const pages = [A, B].concat(Cc ? [Cc] : []);
  for (let i = 0; i < 50; i++){ await sleep(200); const apps = await Promise.all(pages.map(p => p.evaluate('APP'))); if (apps.every(a => a === 'game')) break; }
  console.log('inicio', await Promise.all(pages.map(p => p.evaluate('JSON.stringify({ME:ME, seed:seed, kinds:G.players.map(P=>P.human?"L":P.remote?"R":"C")})'))));
  const t0 = Date.now(); let last = ''; let leaveDone = false;
  while (Date.now() - t0 < +(process.env.T || 90000)){
    await sleep(250);
    const rs = await Promise.all(pages.map(p => p.isClosed() ? Promise.resolve('closed') : p.evaluate(STEP).catch(e => { console.log('EVAL ERROR', e.message, 'url', p.url().slice(-40)); return 'error'; })));
    const s = rs.map(r => String(r).replace(/@\d+/, '')).join(' | '); if (s !== last){ last = s; console.log(((Date.now()-t0)/1000|0)+'s', s); }
    if (process.env.LEAVE && !leaveDone && Date.now() - t0 > 25000){ console.log('B se va'); await B.close(); leaveDone = true;
      if (process.env.REJOIN){ await sleep(16000); const B2 = await mk('B2'); await B2.goto(FILE + '?mute=1'); await B2.evaluate(`sessionStorage.setItem('st_net', JSON.stringify({ code: '${code}', seat: 1 }))`); await B2.evaluate(`NET.open('${code}')`);
        let ok = false; for (let i = 0; i < 100 && !ok; i++){ await sleep(300); ok = await B2.evaluate('APP === "game" && !NET.replaying'); } console.log('B2 reanuda', ok, await B2.evaluate('JSON.stringify({ME:ME, turns:G.stats.turns, rejoinAt:G.players[ME].rejoinAt, log:G.log.slice(-2).map(l=>l.s)})')); pages[1] = B2; } }
    const overs = await Promise.all(pages.map(p => p.isClosed() ? Promise.resolve(true) : p.evaluate('!!(G && G.over)')));
    if (overs.every(Boolean)) break;
  }
  await sleep(1500);
  const hashes = await Promise.all(pages.map(p => p.isClosed() ? Promise.resolve('closed') : p.evaluate(HASH)));
  const same = hashes.filter(h => h !== 'closed').every(h => h === hashes[0]);
  console.log('over', await Promise.all(pages.map(p => p.isClosed() ? 'closed' : p.evaluate('JSON.stringify({over:G.over,w:G.winner,turns:G.stats.turns,app:APP,log:G.log.slice(-2).map(l=>l.s)})'))));
  console.log('ESTADOS IGUALES:', same); if (!same) console.log(hashes.join('\n')); console.log('diag', await Promise.all(pages.map(p => p.isClosed() ? 'closed' : p.evaluate('JSON.stringify({mode:UI.mode,cur:G.cur,moves:G.moves,waiters:[...NET.waiters.keys()],inbox:[...NET.inbox.entries()].map(e=>[e[0],e[1].length]),left:[...NET.left],limbo:G.limbo.length,duel:!!G.duel,pend:G.pendingMult,why:NET.why,aborted:NET.aborted})'))));
  for (const p of pages) if (p._errs.length) console.log(p._errs.slice(0, 8).join('\n'));
  await browser.close();
})();
