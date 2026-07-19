/* ============================================================================
 * Galley Rush — bootstrap, view sync, input (strategic hand-wash)
 * ==========================================================================*/
(function () {
  'use strict';
  const G = window.Galley;
  const canvas = document.getElementById('gl');

  const scene = G.buildScene(canvas);
  scene.resize();
  const game = new G.Game();
  const audio = new G.Audio();

  window.addEventListener('resize', () => scene.resize());
  window.addEventListener('orientationchange', () => setTimeout(() => scene.resize(), 250));

  const el = (id) => document.getElementById(id);
  const ITEM_ICON = { plate: '🍽️', bowl: '🥣', glass: '🥛' };
  const AVATARS = ['🧑', '👩', '🧔', '👱‍♀️'];

  // waiter cards (serve on tap)
  const cards = [0, 1, 2, 3].map(i => {
    const root = el('ocard' + i);
    root.addEventListener('pointerdown', (e) => { e.preventDefault(); audio.ensure(); game.serve(i); });
    return { root, item: root.querySelector('.oitem'), avatar: root.querySelector('.avatar'), pat: root.querySelector('.patfill') };
  });

  // wash-type buttons (queue a wash on tap)
  ['plate', 'bowl', 'glass'].forEach(type => {
    el('wash-' + type).addEventListener('pointerdown', (e) => {
      e.preventDefault(); audio.ensure();
      if (game.queueWash(type)) { audio.pickup(); const b = el('wash-' + type); b.classList.add('flash'); setTimeout(() => b.classList.remove('flash'), 300); }
    });
  });
  window.addEventListener('keydown', (e) => {
    audio.ensure();
    if (e.code === 'Digit1') game.queueWash('plate');
    else if (e.code === 'Digit2') game.queueWash('bowl');
    else if (e.code === 'Digit3') game.queueWash('glass');
    else if (e.code === 'KeyQ') game.serve(0); else if (e.code === 'KeyW') game.serve(1);
    else if (e.code === 'KeyE') game.serve(2); else if (e.code === 'KeyR') game.serve(3);
  });

  const timeVal = el('timeVal'), timePill = el('timePill'), progNum = el('progNum'), progFill = el('progFill');
  const heartsVal = el('heartsVal'), toast = el('toast');
  const sinkItem = el('sinkItem'), washBarFill = el('washBarFill'), queueDots = el('queueDots');

  function fmt(t) { t = Math.max(0, Math.ceil(t)); return Math.floor(t / 60) + ':' + String(t % 60).padStart(2, '0'); }
  let toastT = 0;
  function showToast(m) { toast.textContent = m; toast.classList.add('show'); toastT = 1.3; }

  // ---- overlays ----
  let paused = false;
  function hideOverlays() { for (const id of ['briefing', 'win', 'lose', 'pause']) el(id).classList.remove('show'); }
  function showBriefing() {
    el('briefSub').textContent = 'Shift ' + (game.level + 1) + ' — clean & serve!';
    el('briefGoal').textContent = 'Serve ' + game.target + ' orders in ' + fmt(game.timeLimit);
    el('briefing').classList.add('show');
  }
  el('startBtn').addEventListener('click', () => { audio.ensure(); hideOverlays(); game.start(); });
  el('nextBtn').addEventListener('click', () => { audio.ensure(); game.nextLevel(); hideOverlays(); showBriefing(); });
  el('retryBtn').addEventListener('click', () => { audio.ensure(); game.retry(); hideOverlays(); showBriefing(); });
  el('pauseBtn').addEventListener('click', () => { if (game.phase === 'playing') { paused = true; el('pause').classList.add('show'); } });
  el('resumeBtn').addEventListener('click', () => { paused = false; hideOverlays(); });
  el('restartBtn').addEventListener('click', () => { paused = false; game.retry(); hideOverlays(); showBriefing(); });
  el('soundBtn').addEventListener('click', (e) => { audio.ensure(); const on = audio.enabled; audio.setEnabled(!on); e.currentTarget.textContent = on ? '🔇' : '🔊'; });

  // ---- events ----
  let scrubSndT = 0;
  function processEvents(dt) {
    scrubSndT -= dt;
    for (const ev of game.events) {
      if (ev === 'newOrder') audio.clink();
      else if (ev === 'washStart') audio.pickup();
      else if (ev === 'washed') audio.ding();
      else if (ev === 'served') { audio.ding(); showToast('✔ Served!'); }
      else if (ev === 'noStock') showToast('Wash one first!');
      else if (ev === 'stockFull') showToast('Stock full');
      else if (ev === 'queueFull') showToast('Sink is busy!');
      else if (ev === 'fail') { audio.lose(); showToast('😠 Left! −1 ❤️'); }
      else if (ev === 'won') { audio.win(); onEnd(true); }
      else if (ev === 'lost') { audio.lose(); onEnd(false); }
    }
    game.events.length = 0;
  }
  function onEnd(won) {
    if (won) {
      el('winStars').textContent = '★★★☆☆☆'.slice(3 - game.stars(), 6 - game.stars());
      el('winSub').textContent = 'Served all ' + game.target + ' orders with ' + game.hearts + ' ❤️ left!';
      el('win').classList.add('show');
    } else {
      el('loseSub').textContent = 'You served ' + game.served + ' of ' + game.target + ' orders.';
      el('lose').classList.add('show');
    }
  }

  // ---- view sync ----
  function syncView(dt) {
    // waiter cards
    for (let i = 0; i < 4; i++) {
      const o = game.slots[i], c = cards[i];
      if (o && i < game.maxOrders) {
        if (c.root.classList.contains('empty')) { c.root.classList.remove('empty'); c.root.classList.add('pop'); setTimeout(() => c.root.classList.remove('pop'), 340); }
        c.item.textContent = ITEM_ICON[o.type];
        c.avatar.textContent = AVATARS[i];
        const frac = Math.max(0, o.patience / o.max);
        c.pat.style.width = (frac * 100) + '%';
        c.root.classList.toggle('urgent', frac < 0.34);
        // ready-to-serve hint: pulse if we have matching stock
        c.root.classList.toggle('sel', game.cleanStock[o.type] > 0);
      } else {
        c.root.classList.add('empty'); c.root.classList.remove('sel', 'urgent');
      }
    }

    // sink + wash
    scene.setWashing(game.washType(), game.washFrac());
    scene.setCleanStock(game.cleanStock.plate + game.cleanStock.bowl + game.cleanStock.glass);
    sinkItem.textContent = game.washType() ? ITEM_ICON[game.washType()] : '—';
    washBarFill.style.width = (game.washFrac() * 100) + '%';
    // queue dots
    let q = ''; for (const t of game.washQueue) q += ITEM_ICON[t];
    queueDots.textContent = q;

    // stock badges
    for (const type of ['plate', 'bowl', 'glass']) {
      const s = el('stock-' + type); const n = game.cleanStock[type];
      s.textContent = n; s.classList.toggle('zero', n === 0);
    }

    // HUD
    heartsVal.textContent = game.hearts;
    timeVal.textContent = fmt(game.timeLeft);
    timePill.classList.toggle('low', game.phase === 'playing' && game.timeLeft <= 8);
    progNum.textContent = game.served + '/' + game.target;
    progFill.style.width = (100 * game.served / game.target) + '%';

    if (game.phase === 'playing' && game.timeLeft <= 5) { lowTickT -= dt; if (lowTickT <= 0) { audio.tick(); lowTickT = 1; } }
  }
  let lowTickT = 0;

  // ---- loop ----
  let last = performance.now(), t = 0;
  function frame(now) {
    const dt = Math.min(0.05, (now - last) / 1000); last = now; t += dt;
    if (!paused && game.phase === 'playing') game.update(dt);
    processEvents(dt);
    syncView(dt);
    scene.update(dt, t);
    if (toastT > 0) { toastT -= dt; if (toastT <= 0) toast.classList.remove('show'); }
    scene.render();
    requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);
  showBriefing();
  window.__galley = { game, scene };
})();
