/* ============================================================================
 * Deck & Horizon — bootstrap, input, HUD, interactions
 * ----------------------------------------------------------------------------
 * Left half of the screen = a floating movement joystick; right half = drag to
 * look. Buttons for jump / interact / sound. Keyboard + mouse also supported.
 * ==========================================================================*/
(function () {
  'use strict';
  const C = window.Cruise, T = window.THREE;
  const canvas = document.getElementById('gl');

  const renderer = new T.WebGLRenderer({ canvas, antialias: true });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 1.75)); // cap for mobile GPUs
  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = T.PCFSoftShadowMap;
  renderer.outputColorSpace = T.SRGBColorSpace;

  const scene = new T.Scene();
  const camera = new T.PerspectiveCamera(72, 1, 0.1, 2000);
  const BASE_FOV = 72, ZOOM_FOV = 26;

  const world = C.buildWorld(scene, renderer);
  const player = new C.Player(camera);
  const audio = new C.Audio();

  function resize() {
    const w = window.innerWidth, h = window.innerHeight;
    renderer.setSize(w, h, false);
    camera.aspect = w / h; camera.updateProjectionMatrix();
  }
  window.addEventListener('resize', resize);
  window.addEventListener('orientationchange', () => setTimeout(resize, 250));
  resize();

  // ------------------------------------------------------------- input state
  const input = { moveX: 0, moveY: 0, lookDX: 0, lookDY: 0, run: false };
  const keys = {};
  let zoomed = false;

  const ctx = {
    audio,
    toast: showToast,
    toggleZoom() {
      zoomed = !zoomed;
      camera.fov = zoomed ? ZOOM_FOV : BASE_FOV;
      camera.updateProjectionMatrix();
      document.getElementById('scopeVig').classList.toggle('show', zoomed);
      audio.ui();
    },
  };

  // ------------------------------------------------------------- touch input
  const joyBase = document.getElementById('joyBase');
  const joyKnob = document.getElementById('joyKnob');
  const JOY_R = 58;
  const pointers = new Map(); // id -> {kind, ...}

  function startJoy(id, x, y) {
    joyBase.style.left = x + 'px'; joyBase.style.top = y + 'px';
    joyBase.classList.add('show');
    pointers.set(id, { kind: 'move', ox: x, oy: y });
    updateJoy(id, x, y);
  }
  function updateJoy(id, x, y) {
    const p = pointers.get(id); if (!p) return;
    let dx = x - p.ox, dy = y - p.oy;
    const d = Math.hypot(dx, dy);
    if (d > JOY_R) { dx *= JOY_R / d; dy *= JOY_R / d; }
    joyKnob.style.transform = `translate(${dx}px,${dy}px)`;
    input.moveX = dx / JOY_R;
    input.moveY = -dy / JOY_R;
  }
  function endJoy() {
    joyBase.classList.remove('show');
    joyKnob.style.transform = 'translate(0,0)';
    input.moveX = 0; input.moveY = 0;
  }

  canvas.addEventListener('pointerdown', (e) => {
    canvas.setPointerCapture(e.pointerId);
    const joyZoneW = window.innerWidth * 0.45;
    if (e.clientX < joyZoneW) startJoy(e.pointerId, e.clientX, e.clientY);
    else pointers.set(e.pointerId, { kind: 'look', lx: e.clientX, ly: e.clientY });
    audio.ensure();
  });
  canvas.addEventListener('pointermove', (e) => {
    const p = pointers.get(e.pointerId); if (!p) return;
    if (p.kind === 'move') updateJoy(e.pointerId, e.clientX, e.clientY);
    else { input.lookDX += e.clientX - p.lx; input.lookDY += e.clientY - p.ly; p.lx = e.clientX; p.ly = e.clientY; }
  });
  function endPtr(e) {
    const p = pointers.get(e.pointerId); if (!p) return;
    if (p.kind === 'move') endJoy();
    pointers.delete(e.pointerId);
  }
  canvas.addEventListener('pointerup', endPtr);
  canvas.addEventListener('pointercancel', endPtr);
  canvas.addEventListener('contextmenu', (e) => e.preventDefault());

  // ------------------------------------------------------------- buttons
  function bindHold(id, downFn, upFn) {
    const el = document.getElementById(id);
    el.addEventListener('pointerdown', (e) => { e.stopPropagation(); e.preventDefault(); audio.ensure(); downFn(); });
    if (upFn) el.addEventListener('pointerup', (e) => { e.stopPropagation(); upFn(); });
  }
  bindHold('jumpBtn', () => player.jump());
  bindHold('interactBtn', () => tryInteract());
  bindHold('runBtn', () => { input.run = true; document.getElementById('runBtn').classList.add('on'); },
    () => { input.run = false; document.getElementById('runBtn').classList.remove('on'); });
  document.getElementById('soundBtn').addEventListener('pointerdown', (e) => {
    e.stopPropagation(); audio.ensure(); const on = audio.enabled; audio.setEnabled(!on);
    e.currentTarget.textContent = on ? '🔇' : '🔊';
  });

  // ------------------------------------------------------------- keyboard
  window.addEventListener('keydown', (e) => {
    keys[e.code] = true;
    if (e.code === 'Space') { player.jump(); e.preventDefault(); }
    if (e.code === 'KeyE') tryInteract();
    if (e.code === 'ShiftLeft') input.run = true;
  });
  window.addEventListener('keyup', (e) => { keys[e.code] = false; if (e.code === 'ShiftLeft') input.run = false; });
  // mouse-look on desktop is covered by pointer handlers (drag on right side)
  function readKeys() {
    let mx = 0, my = 0;
    if (keys['KeyW'] || keys['ArrowUp']) my += 1;
    if (keys['KeyS'] || keys['ArrowDown']) my -= 1;
    if (keys['KeyA'] || keys['ArrowLeft']) mx -= 1;
    if (keys['KeyD'] || keys['ArrowRight']) mx += 1;
    if (mx || my) { input.moveX = mx; input.moveY = my; }
  }

  // ------------------------------------------------------------- interactions
  let current = null;
  function updateInteractable() {
    let best = null, bestD = Infinity;
    for (const it of world.interactables) {
      const d = Math.hypot(player.x - it.x, player.z - it.z);
      if (d < it.r && d < bestD) { bestD = d; best = it; }
    }
    current = best;
    const prompt = document.getElementById('prompt');
    const ib = document.getElementById('interactBtn');
    if (best) { prompt.textContent = best.prompt; prompt.classList.add('show'); ib.classList.add('show'); }
    else { prompt.classList.remove('show'); ib.classList.remove('show'); }
  }
  function tryInteract() {
    if (!current) return;
    current.action(ctx);
    audio.ui();
  }

  let toastT = 0;
  function showToast(msg) {
    const el = document.getElementById('toast');
    el.textContent = msg; el.classList.add('show'); toastT = 2.2;
  }

  // ------------------------------------------------------------- menu / start
  document.getElementById('startBtn').addEventListener('click', () => {
    document.getElementById('menu').classList.remove('show');
    audio.ensure();
  });

  // ------------------------------------------------------------- loop
  let last = performance.now(), t = 0, gullT = 6 + Math.random() * 6, stepT = 0;
  function frame(now) {
    const dt = Math.min(0.05, (now - last) / 1000); last = now; t += dt;
    readKeys();
    const r = player.update(dt, world, input);
    world.update(dt, t, camera);

    // footsteps
    if (r.moving && player.grounded && !player.swimming) {
      stepT -= dt * r.speed;
      if (stepT <= 0) { audio.footstep(); stepT = 2.2; }
    }
    // pool splash on entry
    if (player.swimming && !player._wasSwimming) { audio.splash(); showToast('🏊 Splash! Walk to the edge to climb out'); }
    player._wasSwimming = player.swimming;

    // occasional gulls
    gullT -= dt; if (gullT <= 0) { audio.gull(); gullT = 10 + Math.random() * 12; }

    // underwater tint
    document.getElementById('water').classList.toggle('show', player.underwater);

    updateInteractable();
    if (toastT > 0) { toastT -= dt; if (toastT <= 0) document.getElementById('toast').classList.remove('show'); }

    renderer.render(scene, camera);
    requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);
  window.__cruise = { player, world, camera }; // debug hook
})();
