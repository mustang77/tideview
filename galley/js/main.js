/* ============================================================================
 * Galley Rush — bootstrap, order cards, view sync, input
 * ==========================================================================*/
(function () {
  'use strict';
  const G = window.Galley, T = window.THREE;
  const canvas = document.getElementById('gl');

  const scene = G.buildScene(canvas);
  scene.resize();
  const steward = G.buildSteward({ apron: '#18a0a8', skin: '#e8b48c' });
  scene.addSteward(steward);
  steward.group.scale.set(1.12, 1.12, 1.12);
  steward.group.position.set(G.STATION.sink, 0.5, -0.9);

  const game = new G.Game();
  const audio = new G.Audio();

  // in-hand item (rebuilt per order type)
  let handItem = null;
  function setHandItem(type) {
    if (handItem) { steward.parts.handAnchor.remove(handItem); handItem = null; }
    if (!type) return;
    handItem = scene.makeItem(type);
    handItem.scale.set(0.9, 0.9, 0.9);
    handItem.position.set(0, -0.02, 0.02);
    if (type === 'plate') { handItem.rotation.x = Math.PI * 0.5; }
    steward.parts.handAnchor.add(handItem);
  }

  window.addEventListener('resize', () => scene.resize());
  window.addEventListener('orientationchange', () => setTimeout(() => scene.resize(), 250));

  const el = (id) => document.getElementById(id);
  const ITEM_ICON = { plate: '🍽️', bowl: '🥣', glass: '🥛' };
  const AVATARS = ['🧑', '👩', '🧔']; // one per slot
  const cards = [0, 1, 2].map(i => ({
    root: el('ocard' + i),
    item: el('ocard' + i).querySelector('.oitem'),
    avatar: el('ocard' + i).querySelector('.avatar'),
    pat: el('ocard' + i).querySelector('.patfill'),
  }));
  cards.forEach((c, i) => c.root.addEventListener('pointerdown', (e) => { e.preventDefault(); audio.ensure(); game.select(i); audio.ui(); }));

  const timeVal = el('timeVal'), timePill = el('timePill'), progNum = el('progNum'), progFill = el('progFill');
  const heartsVal = el('heartsVal'), toast = el('toast'), washFill = el('washBtn').querySelector('.fill'), washBtn = el('washBtn');

  function fmt(t) { t = Math.max(0, Math.ceil(t)); return Math.floor(t / 60) + ':' + String(t % 60).padStart(2, '0'); }
  let toastT = 0;
  function showToast(m) { toast.textContent = m; toast.classList.add('show'); toastT = 1.4; }

  // ---- input ----
  let holdingWash = false;
  washBtn.addEventListener('pointerdown', (e) => { e.preventDefault(); audio.ensure(); if (!washBtn.classList.contains('disabled')) holdingWash = true; });
  const stopWash = () => { holdingWash = false; };
  washBtn.addEventListener('pointerup', stopWash); washBtn.addEventListener('pointerleave', stopWash); washBtn.addEventListener('pointercancel', stopWash);
  window.addEventListener('keydown', (e) => {
    if (e.repeat) return; audio.ensure();
    if (e.code === 'Space') { holdingWash = true; e.preventDefault(); }
    else if (e.code === 'Digit1') game.select(0);
    else if (e.code === 'Digit2') game.select(1);
    else if (e.code === 'Digit3') game.select(2);
  });
  window.addEventListener('keyup', (e) => { if (e.code === 'Space') holdingWash = false; });

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
      else if (ev === 'pickup') { audio.pickup(); setHandItem(game.currentType()); }
      else if (ev === 'scrub') { if (scrubSndT <= 0) { audio.scrub(); scrubSndT = 0.13; } }
      else if (ev === 'served') { audio.ding(); setHandItem(null); showToast('✔ Served!'); }
      else if (ev === 'fail') { audio.lose(); showToast('😠 A waiter left! −1 ❤️'); }
      else if (ev === 'won') { audio.win(); onEnd(true); }
      else if (ev === 'lost') { audio.lose(); onEnd(false); }
    }
    game.events.length = 0;
  }
  function onEnd(won) {
    setHandItem(null);
    if (won) {
      el('winStars').textContent = '★★★☆☆☆'.slice(3 - game.stars(), 6 - game.stars());
      el('winSub').textContent = 'Served all ' + game.target + ' orders with ' + game.hearts + ' ❤️ to spare!';
      el('win').classList.add('show');
    } else {
      el('loseSub').textContent = 'You served ' + game.served + ' of ' + game.target + ' orders.';
      el('lose').classList.add('show');
    }
  }

  // ---- view sync ----
  let lastFresh = [0, 0, 0], lowTickT = 0;
  function syncView(dt) {
    // order cards
    for (let i = 0; i < 3; i++) {
      const o = game.slots[i], c = cards[i];
      if (o) {
        if (c.root.classList.contains('empty')) { c.root.classList.remove('empty'); c.root.classList.add('pop'); setTimeout(() => c.root.classList.remove('pop'), 340); }
        c.item.textContent = ITEM_ICON[o.type];
        c.avatar.textContent = AVATARS[i];
        const frac = Math.max(0, o.patience / o.max);
        c.pat.style.width = (frac * 100) + '%';
        c.root.classList.toggle('urgent', frac < 0.34);
        c.root.classList.toggle('sel', game.current && game.current.slot === i);
      } else {
        c.root.classList.add('empty'); c.root.classList.remove('sel', 'urgent');
      }
    }

    // steward pose + hand
    let pose = 'idle';
    if (game.phase === 'playing') {
      if (holdingWash && game.current) pose = 'scrub';
      else if (game.station === 'serve' && game.stationT > 0) pose = 'rack';
      else if (game.current) pose = 'carry';
    }
    steward.setState(pose, dt);
    scene.waterOn(pose === 'scrub');
    // clean sparkle: brighten the plate as it scrubs (visual only)
    if (handItem && handItem.userData.kind === 'plate' && handItem._disc) {
      const s = game.currentScrub();
      handItem._disc.material.color.setRGB(0.8 + s * 0.19, 0.75 + s * 0.24, 0.6 + s * 0.39);
    }

    // HUD
    heartsVal.textContent = game.hearts;
    timeVal.textContent = fmt(game.timeLeft);
    timePill.classList.toggle('low', game.phase === 'playing' && game.timeLeft <= 8);
    progNum.textContent = game.served + '/' + game.target;
    progFill.style.width = (100 * game.served / game.target) + '%';
    washFill.style.height = (game.current ? game.currentScrub() * 100 : 0) + '%';
    const playing = game.phase === 'playing' && !paused;
    const anyOrder = game.slots.some(Boolean);
    washBtn.classList.toggle('disabled', !playing || !anyOrder);
    washBtn.classList.toggle('pulse', playing && anyOrder && !game.current);

    if (game.phase === 'playing' && game.timeLeft <= 5) { lowTickT -= dt; if (lowTickT <= 0) { audio.tick(); lowTickT = 1; } }
  }

  // ---- loop ----
  let last = performance.now(), t = 0;
  function frame(now) {
    const dt = Math.min(0.05, (now - last) / 1000); last = now; t += dt;
    if (!paused && game.phase === 'playing') { if (holdingWash) game.scrub(dt); game.update(dt); }
    processEvents(dt);
    syncView(dt);
    scene.update(dt, t);
    if (toastT > 0) { toastT -= dt; if (toastT <= 0) toast.classList.remove('show'); }
    scene.render();
    requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);
  showBriefing();
  window.__galley = { game, scene, steward };
})();
