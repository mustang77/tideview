/* ============================================================================
 * Galley Rush — bootstrap, view sync, HUD, input
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

  // in-hand plate parented to the right hand
  const handPlate = scene.makePlate(true);
  handPlate.rotation.x = Math.PI * 0.5;
  handPlate.position.set(0, -0.03, 0.02);
  steward.parts.handAnchor.add(handPlate);
  handPlate.visible = false;
  const CLEAN = new T.Color('#fbfdff'), DIRTY = new T.Color('#cdbf9a');

  window.addEventListener('resize', () => scene.resize());
  window.addEventListener('orientationchange', () => setTimeout(() => scene.resize(), 250));

  // ---------------------------------------------------------------- HUD refs
  const el = (id) => document.getElementById(id);
  const timeVal = el('timeVal'), timePill = el('timePill'), progNum = el('progNum'), progFill = el('progFill');
  const rackDots = el('rackDots'), toast = el('toast'), washFill = el('washBtn').querySelector('.fill');
  const washBtn = el('washBtn'), rackBtn = el('rackBtn'), runBtn = el('runBtn');

  function fmt(t) { t = Math.max(0, Math.ceil(t)); return Math.floor(t / 60) + ':' + String(t % 60).padStart(2, '0'); }
  let toastT = 0;
  function showToast(m) { toast.textContent = m; toast.classList.add('show'); toastT = 1.6; }

  function buildRackDots() {
    rackDots.innerHTML = '';
    for (let i = 0; i < game.rackSize; i++) { const d = document.createElement('span'); d.className = 'dot'; rackDots.appendChild(d); }
  }

  // ---------------------------------------------------------------- input
  let holdingWash = false;
  function press(btn, downFn, upFn) {
    btn.addEventListener('pointerdown', (e) => { e.preventDefault(); audio.ensure(); if (!btn.classList.contains('disabled')) downFn(); });
    if (upFn) { btn.addEventListener('pointerup', upFn); btn.addEventListener('pointerleave', upFn); btn.addEventListener('pointercancel', upFn); }
  }
  press(washBtn, () => { holdingWash = true; }, () => { holdingWash = false; });
  press(rackBtn, () => { if (game.toRack()) {} });
  press(runBtn, () => { if (game.run()) {} });

  window.addEventListener('keydown', (e) => {
    if (e.repeat) return; audio.ensure();
    if (e.code === 'Space') { holdingWash = true; e.preventDefault(); }
    else if (e.code === 'KeyR') game.toRack();
    else if (e.code === 'Enter' || e.code === 'KeyF') game.run();
  });
  window.addEventListener('keyup', (e) => { if (e.code === 'Space') holdingWash = false; });

  // overlays
  function hideOverlays() { for (const id of ['briefing', 'win', 'lose', 'pause']) el(id).classList.remove('show'); }
  function showBriefing() {
    el('briefSub').textContent = 'Shift ' + (game.level + 1) + ' — dish-washing duty!';
    el('briefGoal').textContent = 'Wash ' + game.dishes + ' dishes in ' + fmt(game.timeLimit);
    buildRackDots();
    el('briefing').classList.add('show');
  }
  el('startBtn').addEventListener('click', () => { audio.ensure(); hideOverlays(); game.start(); });
  el('nextBtn').addEventListener('click', () => { audio.ensure(); game.nextLevel(); hideOverlays(); showBriefing(); });
  el('retryBtn').addEventListener('click', () => { audio.ensure(); game.retry(); hideOverlays(); showBriefing(); });
  el('pauseBtn').addEventListener('click', () => { if (game.phase === 'playing') { paused = true; el('pause').classList.add('show'); } });
  el('resumeBtn').addEventListener('click', () => { paused = false; hideOverlays(); });
  el('restartBtn').addEventListener('click', () => { paused = false; game.retry(); hideOverlays(); showBriefing(); });
  el('soundBtn').addEventListener('click', (e) => { audio.ensure(); const on = audio.enabled; audio.setEnabled(!on); e.currentTarget.textContent = on ? '🔇' : '🔊'; });
  let paused = false;

  // ---------------------------------------------------------------- events
  let scrubSndT = 0;
  function processEvents(dt) {
    scrubSndT -= dt;
    for (const ev of game.events) {
      if (ev === 'pickup') audio.pickup();
      else if (ev === 'scrub') { if (scrubSndT <= 0) { audio.scrub(); scrubSndT = 0.13; } }
      else if (ev === 'clean') audio.ding();
      else if (ev === 'rack') { audio.clink(); scene.setRack(game.rack); }
      else if (ev === 'run') { audio.startHum(); scene.openDoor(true); scene.setWasherLoad(game.washer.load); scene.setLight('run'); setTimeout(() => scene.openDoor(false), 500); }
      else if (ev === 'cycleDone') { audio.stopHum(); audio.ding(); scene.setLight('done'); scene.setWasherLoad(0); scene.setDone(game.done); showToast('✨ ' + game.done + ' done!'); setTimeout(() => scene.setLight('idle'), 1200); }
      else if (ev === 'won') { audio.win(); onWin(); }
      else if (ev === 'lost') { audio.lose(); audio.stopHum(); onLose(); }
    }
    game.events.length = 0;
  }
  function onWin() {
    el('winStars').textContent = '★★★☆☆☆'.slice(3 - game.stars(), 6 - game.stars());
    el('winSub').textContent = 'All ' + game.dishes + ' dishes sparkling — ' + fmt(game.timeLeft) + ' to spare!';
    el('win').classList.add('show');
  }
  function onLose() {
    el('loseSub').textContent = 'You washed ' + game.done + ' of ' + game.dishes + ' dishes.';
    el('lose').classList.add('show');
  }

  // ---------------------------------------------------------------- view sync
  const stationX = { sink: G.STATION.sink, rack: G.STATION.rack, washer: G.STATION.washer, pile: G.STATION.pile, idle: G.STATION.sink };
  let lowTickT = 0;
  function syncView(dt) {
    // dish counts
    scene.setDirty(game.dirty + (game.hand ? 1 : 0)); // include the one in hand? no — keep pile = dirty
    scene.setDirty(game.dirty);
    scene.setRack(game.rack);
    scene.setDone(game.done);

    // hand plate
    if (game.hand) {
      handPlate.visible = true;
      const c = game.hand.stage === 'clean' ? CLEAN : DIRTY.clone().lerp(CLEAN, game.hand.scrub);
      handPlate._disc.material.color.copy(c);
      if (handPlate._grime) handPlate._grime.visible = game.hand.scrub < 0.6;
    } else handPlate.visible = false;

    // steward slide + pose
    const tx = stationX[game.station] || G.STATION.sink;
    steward.group.position.x += (tx - steward.group.position.x) * Math.min(1, dt * 6);
    let pose = 'idle';
    if (game.phase === 'playing') {
      if (game.station === 'washer' && game.washer.running) pose = 'run';
      else if (game.station === 'rack' && game.stationT > 0) pose = 'rack';
      else if (holdingWash && game.hand && game.hand.stage === 'dirty') pose = 'scrub';
      else if (game.hand && game.hand.stage === 'clean') pose = 'carry';
    }
    steward.setState(pose, dt);
    scene.waterOn(pose === 'scrub');

    // HUD
    timeVal.textContent = fmt(game.timeLeft);
    timePill.classList.toggle('low', game.phase === 'playing' && game.timeLeft <= 8);
    progNum.textContent = game.done + '/' + game.dishes;
    progFill.style.width = (100 * game.done / game.dishes) + '%';
    washFill.style.height = (game.hand && game.hand.stage === 'dirty' ? game.hand.scrub * 100 : 0) + '%';
    // rack dots
    const dots = rackDots.children;
    for (let i = 0; i < dots.length; i++) dots[i].classList.toggle('on', i < game.rack);
    // button states
    const playing = game.phase === 'playing' && !paused;
    washBtn.classList.toggle('disabled', !playing || (game.dirty <= 0 && !(game.hand && game.hand.stage === 'dirty')));
    rackBtn.classList.toggle('disabled', !playing || !game.canRack());
    rackBtn.classList.toggle('pulse', playing && game.canRack());
    runBtn.classList.toggle('disabled', !playing || !game.canRun());
    runBtn.classList.toggle('pulse', playing && game.canRun() && (game.rackFull() || game.dirty === 0));

    // low-time ticks
    if (game.phase === 'playing' && game.timeLeft <= 5) { lowTickT -= dt; if (lowTickT <= 0) { audio.tick(); lowTickT = 1; } }
  }

  // ---------------------------------------------------------------- loop
  buildRackDots();
  let last = performance.now(), t = 0;
  function frame(now) {
    const dt = Math.min(0.05, (now - last) / 1000); last = now; t += dt;
    if (!paused && game.phase === 'playing') {
      if (holdingWash) game.scrub(dt);
      game.update(dt);
    }
    processEvents(dt);
    syncView(dt);
    scene.update(dt, t);
    if (toastT > 0) { toastT -= dt; if (toastT <= 0) toast.classList.remove('show'); }
    scene.render();
    requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);
  showBriefing();
  window.__galley = { game, scene, steward }; // debug hook
})();
