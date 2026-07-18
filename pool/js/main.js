/* ============================================================================
 * Break & Run — bootstrap & input
 * ----------------------------------------------------------------------------
 * Wires the scene + simulation + rules together, runs the animation loop, and
 * translates pointer / touch / keyboard into aim, orbit, power and spin.
 * ==========================================================================*/
(function () {
  'use strict';
  const P = window.Pool;
  const canvas = document.getElementById('gl');

  const scene = new P.PoolScene(canvas);
  const sim = new P.Simulation();
  const game = new P.Game(scene, sim);
  window.__g = game; // debug/inspection hook

  // ------------------------------------------------------------- main loop
  let last = performance.now();
  function loop(now) {
    const dt = Math.min(0.1, (now - last) / 1000);
    last = now;
    game.tick(dt);
    // keep the shoot button honest
    const btn = document.getElementById('shootBtn');
    btn.disabled = !game.canShoot();
    scene.render();
    requestAnimationFrame(loop);
  }
  requestAnimationFrame(loop);

  window.addEventListener('resize', () => scene.resize());

  // ------------------------------------------------------------- menu
  let selectedMode = 'ai', selectedDiff = 'medium';
  document.getElementById('modeSeg').addEventListener('click', (e) => {
    const b = e.target.closest('button'); if (!b) return;
    selectedMode = b.dataset.mode;
    for (const x of e.currentTarget.children) x.classList.toggle('sel', x === b);
    document.getElementById('diffField').style.display = selectedMode === 'ai' ? '' : 'none';
  });
  document.getElementById('diffSeg').addEventListener('click', (e) => {
    const b = e.target.closest('button'); if (!b) return;
    selectedDiff = b.dataset.diff;
    for (const x of e.currentTarget.children) x.classList.toggle('sel', x === b);
  });
  function startGame() {
    document.getElementById('menu').classList.remove('show');
    document.getElementById('result').classList.remove('show');
    scene.cam.mode = 'aim'; scene.cam.el = 0.6; scene.cam.dist = 1.9;
    game.newGame(selectedMode, selectedDiff);
    game.power = 0.75; game.updatePowerUI();
    setSpin(0, 0);
  }
  document.getElementById('startBtn').addEventListener('click', startGame);
  document.getElementById('playAgain').addEventListener('click', startGame);
  document.getElementById('menuBtn').addEventListener('click', () => {
    document.getElementById('menu').classList.add('show');
  });

  // ------------------------------------------------------------- camera btns
  document.getElementById('camBtn').addEventListener('click', (e) => {
    scene.cam.mode = scene.cam.mode === 'aim' ? 'free' : 'aim';
    e.currentTarget.textContent = scene.cam.mode === 'aim' ? '🎥 Free' : '🎯 Aim';
    if (scene.cam.mode === 'aim') scene.cam.el = 0.6;
  });
  document.getElementById('topBtn').addEventListener('click', () => {
    scene.setOverhead();
    document.getElementById('camBtn').textContent = '🎯 Aim';
  });

  // ------------------------------------------------------------- shoot
  document.getElementById('shootBtn').addEventListener('click', () => {
    if (game.canShoot()) game.beginShot();
  });

  // ------------------------------------------------------------- power slider
  const powerTrack = document.getElementById('powerTrack');
  function setPowerFromEvent(clientY) {
    const r = powerTrack.getBoundingClientRect();
    let t = 1 - (clientY - r.top) / r.height;
    t = Math.max(0.05, Math.min(1, t));
    game.power = t;
    game.updatePowerUI();
  }
  let powerDrag = false;
  powerTrack.addEventListener('pointerdown', (e) => {
    powerDrag = true; powerTrack.setPointerCapture(e.pointerId);
    setPowerFromEvent(e.clientY); e.stopPropagation();
  });
  powerTrack.addEventListener('pointermove', (e) => { if (powerDrag) setPowerFromEvent(e.clientY); });
  powerTrack.addEventListener('pointerup', (e) => { powerDrag = false; e.stopPropagation(); });

  // ------------------------------------------------------------- spin pad
  const spinPad = document.getElementById('spinPad');
  const spinDot = document.getElementById('spinDot');
  function setSpin(side, follow) {
    const len = Math.hypot(side, follow);
    if (len > 1) { side /= len; follow /= len; }
    game.spinSide = side; game.spinFollow = follow;
    const r = spinPad.clientWidth / 2;
    spinDot.style.left = (r + side * r * 0.8) + 'px';
    spinDot.style.top = (r - follow * r * 0.8) + 'px';
  }
  function spinFromEvent(e) {
    const r = spinPad.getBoundingClientRect();
    const cx = r.left + r.width / 2, cy = r.top + r.height / 2;
    const side = (e.clientX - cx) / (r.width / 2);
    const follow = -(e.clientY - cy) / (r.height / 2);
    setSpin(Math.max(-1, Math.min(1, side)), Math.max(-1, Math.min(1, follow)));
  }
  let spinDrag = false;
  spinPad.addEventListener('pointerdown', (e) => {
    spinDrag = true; spinPad.setPointerCapture(e.pointerId); spinFromEvent(e); e.stopPropagation();
  });
  spinPad.addEventListener('pointermove', (e) => { if (spinDrag) spinFromEvent(e); });
  spinPad.addEventListener('pointerup', (e) => { spinDrag = false; e.stopPropagation(); });

  // ------------------------------------------------------------- canvas input
  const pointers = new Map();
  let orbitLast = null, pinchLast = null;

  function isOrbitGesture(e) {
    return scene.cam.mode === 'free' || e.button === 2 || e.shiftKey;
  }

  function aimToClient(clientX, clientY) {
    const cue = sim.cueBall();
    if (!cue || !cue.active) return;
    const pt = scene.screenToTable(clientX, clientY);
    if (!pt) return;
    const a = Math.atan2(pt.z - cue.z, pt.x - cue.x);
    scene.aimAngle = a;
  }

  canvas.addEventListener('pointerdown', (e) => {
    canvas.setPointerCapture(e.pointerId);
    pointers.set(e.pointerId, { x: e.clientX, y: e.clientY });

    if (game.phase === 'placing' && !game.player().isAI) {
      const pt = scene.screenToTable(e.clientX, e.clientY);
      if (pt) game.tryPlaceCue(pt.x, pt.z);
      return;
    }
    if (pointers.size === 1) {
      if (isOrbitGesture(e)) orbitLast = { x: e.clientX, y: e.clientY };
      else if (game.canShoot()) aimToClient(e.clientX, e.clientY);
    }
  });

  canvas.addEventListener('pointermove', (e) => {
    if (!pointers.has(e.pointerId)) {
      return; // hover: ignore (aim only while dragging)
    }
    pointers.set(e.pointerId, { x: e.clientX, y: e.clientY });

    if (game.phase === 'placing' && !game.player().isAI && pointers.size === 1) {
      const pt = scene.screenToTable(e.clientX, e.clientY);
      if (pt) game.tryPlaceCue(pt.x, pt.z);
      return;
    }

    if (pointers.size >= 2) {
      // two-finger orbit + pinch zoom
      const pts = [...pointers.values()];
      const cx = (pts[0].x + pts[1].x) / 2, cy = (pts[0].y + pts[1].y) / 2;
      const dist = Math.hypot(pts[0].x - pts[1].x, pts[0].y - pts[1].y);
      if (orbitLast) {
        scene.cam.az -= (cx - orbitLast.x) * 0.006;
        scene.cam.el += (cy - orbitLast.y) * 0.006;
        scene.cam.el = Math.max(0.1, Math.min(1.45, scene.cam.el));
        if (scene.cam.mode === 'aim') scene.cam.mode = 'free', document.getElementById('camBtn').textContent = '🎯 Aim';
      }
      if (pinchLast) {
        scene.cam.dist *= pinchLast / dist;
        scene.cam.dist = Math.max(0.7, Math.min(4, scene.cam.dist));
      }
      orbitLast = { x: cx, y: cy }; pinchLast = dist;
      return;
    }

    // single pointer
    if (isOrbitGesture(e) || (orbitLast && scene.cam.mode === 'free')) {
      if (!orbitLast) orbitLast = { x: e.clientX, y: e.clientY };
      scene.cam.az -= (e.clientX - orbitLast.x) * 0.006;
      scene.cam.el += (e.clientY - orbitLast.y) * 0.006;
      scene.cam.el = Math.max(0.1, Math.min(1.45, scene.cam.el));
      orbitLast = { x: e.clientX, y: e.clientY };
    } else if (game.canShoot()) {
      aimToClient(e.clientX, e.clientY);
    }
  });

  function endPointer(e) {
    const wasPlacing = game.phase === 'placing' && !game.player().isAI;
    pointers.delete(e.pointerId);
    if (pointers.size < 2) pinchLast = null;
    if (pointers.size === 0) orbitLast = null;
    if (wasPlacing && pointers.size === 0) {
      // confirm placement on release if valid
      const cue = sim.cueBall();
      if (game.isValidCuePos(cue.x, cue.z)) game.confirmPlace();
    }
  }
  canvas.addEventListener('pointerup', endPointer);
  canvas.addEventListener('pointercancel', endPointer);
  canvas.addEventListener('contextmenu', (e) => e.preventDefault());
  canvas.addEventListener('wheel', (e) => {
    scene.cam.dist *= (1 + Math.sign(e.deltaY) * 0.08);
    scene.cam.dist = Math.max(0.7, Math.min(4, scene.cam.dist));
    e.preventDefault();
  }, { passive: false });

  // ------------------------------------------------------------- keyboard
  window.addEventListener('keydown', (e) => {
    if (e.code === 'Space') {
      e.preventDefault();
      if (game.canShoot()) game.beginShot();
      else if (game.phase === 'placing' && !game.player().isAI) {
        const cue = sim.cueBall();
        if (game.isValidCuePos(cue.x, cue.z)) game.confirmPlace();
      }
      return;
    }
    const fine = e.shiftKey ? 0.004 : 0.02;
    if (e.code === 'ArrowLeft') { if (game.canShoot()) scene.aimAngle -= fine; }
    else if (e.code === 'ArrowRight') { if (game.canShoot()) scene.aimAngle += fine; }
    else if (e.code === 'ArrowUp') { game.power = Math.min(1, game.power + 0.03); game.updatePowerUI(); }
    else if (e.code === 'ArrowDown') { game.power = Math.max(0.05, game.power - 0.03); game.updatePowerUI(); }
    else if (e.code === 'KeyC') { document.getElementById('camBtn').click(); }
    else if (e.code === 'KeyT') { document.getElementById('topBtn').click(); }
  });

  game.updatePowerUI();
  setSpin(0, 0);
})();
