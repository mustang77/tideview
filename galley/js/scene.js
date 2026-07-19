/* ============================================================================
 * Galley Rush — scene (bright cartoon cruise-ship galley)
 * ----------------------------------------------------------------------------
 * The wash station the whole game happens at: counter with a dirty-dish tray,
 * a sink, a drying rack, and a dishwasher, a sunset porthole behind the crew,
 * and warm cheerful lighting. Exposes station X positions + setters the game
 * calls to reflect state (dirty count, rack fill, machine, done count).
 * ==========================================================================*/
(function (global) {
  'use strict';
  const T = global.THREE;
  const mat = (c, r, m) => new T.MeshStandardMaterial({ color: c, roughness: r == null ? 0.7 : r, metalness: m || 0 });

  // stations along the counter (X)
  const STATION = { pile: -2.25, sink: -0.85, rack: 0.7, washer: 2.25 };
  const COUNTER_Y = 1.0;

  function backdropTexture() {
    const w = 1024, h = 512, cv = document.createElement('canvas'); cv.width = w; cv.height = h;
    const g = cv.getContext('2d');
    const sky = g.createLinearGradient(0, 0, 0, h);
    sky.addColorStop(0, '#ff9d5c'); sky.addColorStop(0.4, '#ffb98a'); sky.addColorStop(0.62, '#ffd9b0'); sky.addColorStop(0.68, '#8fd0e6'); sky.addColorStop(1, '#3a95c4');
    g.fillStyle = sky; g.fillRect(0, 0, w, h);
    // sun
    g.fillStyle = 'rgba(255,247,220,0.95)'; g.beginPath(); g.arc(w * 0.5, h * 0.5, 60, 0, Math.PI * 2); g.fill();
    g.fillStyle = 'rgba(255,240,200,0.35)'; g.beginPath(); g.arc(w * 0.5, h * 0.5, 100, 0, Math.PI * 2); g.fill();
    // sea
    g.fillStyle = '#2f88b8'; g.fillRect(0, h * 0.68, w, h * 0.32);
    g.fillStyle = 'rgba(255,220,170,0.5)'; g.fillRect(w * 0.42, h * 0.68, w * 0.16, h * 0.32); // sun glitter
    // distant resort hills
    g.fillStyle = '#c98a6a'; g.beginPath(); g.moveTo(0, h * 0.68); g.lineTo(w * 0.2, h * 0.55); g.lineTo(w * 0.4, h * 0.68); g.fill();
    g.beginPath(); g.moveTo(w * 0.6, h * 0.68); g.lineTo(w * 0.8, h * 0.52); g.lineTo(w, h * 0.68); g.fill();
    return new T.CanvasTexture(cv);
  }

  function tileTexture(a, b) {
    const s = 256, cv = document.createElement('canvas'); cv.width = cv.height = s; const g = cv.getContext('2d');
    g.fillStyle = a; g.fillRect(0, 0, s, s);
    g.fillStyle = b; g.fillRect(0, 0, s / 2, s / 2); g.fillStyle = b; g.fillRect(s / 2, s / 2, s / 2, s / 2);
    const tex = new T.CanvasTexture(cv); tex.wrapS = tex.wrapT = T.RepeatWrapping; return tex;
  }

  function build(canvas) {
    const renderer = new T.WebGLRenderer({ canvas, antialias: true });
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 1.75));
    renderer.shadowMap.enabled = true; renderer.shadowMap.type = T.PCFSoftShadowMap;
    renderer.outputColorSpace = T.SRGBColorSpace;

    const scene = new T.Scene();
    scene.background = new T.Color('#ffd9b0');
    const camera = new T.PerspectiveCamera(46, 1, 0.1, 100);
    camera.position.set(0.2, 2.55, 5.0);
    camera.lookAt(0, 1.25, -0.3);

    // ---- lighting (warm & bright) ----
    scene.add(new T.AmbientLight('#fff2e0', 0.75));
    scene.add(new T.HemisphereLight('#ffe9d0', '#6a5540', 0.6));
    const key = new T.DirectionalLight('#ffdca8', 1.4);
    key.position.set(-3, 6, 5); key.castShadow = true;
    key.shadow.mapSize.set(1024, 1024);
    const sc = key.shadow.camera; sc.left = -6; sc.right = 6; sc.top = 6; sc.bottom = -6; sc.near = 1; sc.far = 30; key.shadow.bias = -0.0004;
    scene.add(key);
    const rim = new T.DirectionalLight('#bfe6ff', 0.5); rim.position.set(4, 4, -4); scene.add(rim);

    // ---- floor ----
    const floorTex = tileTexture('#d9c4a8', '#c9b193'); floorTex.repeat.set(6, 6);
    const floor = new T.Mesh(new T.PlaneGeometry(24, 24), mat('#d9c4a8', 0.9));
    floor.material.map = floorTex; floor.rotation.x = -Math.PI / 2; floor.receiveShadow = true; scene.add(floor);

    // ---- back wall + sunset window ----
    const wall = new T.Mesh(new T.BoxGeometry(24, 8, 0.3), mat('#f3ead8', 0.9));
    wall.position.set(0, 4, -2.2); wall.receiveShadow = true; scene.add(wall);
    const win = new T.Mesh(new T.PlaneGeometry(9, 3.4), new T.MeshBasicMaterial({ map: backdropTexture() }));
    win.position.set(0, 2.7, -2.03); scene.add(win);
    const frame = new T.Mesh(new T.BoxGeometry(9.5, 3.9, 0.16), mat('#e8b06a', 0.5, 0.2));
    frame.position.set(0, 2.7, -2.12); scene.add(frame);
    // window mullions
    for (const x of [-3, 0, 3]) { const b = new T.Mesh(new T.BoxGeometry(0.12, 3.4, 0.12), mat('#e8b06a', 0.5, 0.2)); b.position.set(x, 2.7, -2.0); scene.add(b); }

    // ---- neon sign: WORLD CRUISE ACADEMY (hangs over the station) ----
    (function neonSign() {
      const w = 1024, h = 230, cv = document.createElement('canvas'); cv.width = w; cv.height = h;
      const g = cv.getContext('2d');
      g.fillStyle = '#0b0b14'; g.fillRect(0, 0, w, h);
      g.textAlign = 'center'; g.textBaseline = 'middle';
      g.font = '900 118px Arial Black, Arial, sans-serif';
      // glow pass
      g.shadowColor = '#22e6ff'; g.shadowBlur = 34;
      g.fillStyle = '#8ff8ff'; g.fillText('WORLD CRUISE', w / 2, 70);
      g.shadowColor = '#ff49b0'; g.shadowBlur = 30;
      g.font = '900 96px Arial Black, Arial, sans-serif';
      g.fillStyle = '#ffb3e0'; g.fillText('ACADEMY', w / 2, 170);
      // crisp core
      g.shadowBlur = 0;
      g.fillStyle = '#eafffe'; g.font = '900 118px Arial Black, Arial, sans-serif'; g.fillText('WORLD CRUISE', w / 2, 70);
      g.fillStyle = '#ffe6f5'; g.font = '900 96px Arial Black, Arial, sans-serif'; g.fillText('ACADEMY', w / 2, 170);
      const tex = new T.CanvasTexture(cv);
      const Y = 2.62;  // hangs in the clear band between HUD and the steward
      const board = new T.Mesh(new T.BoxGeometry(4.4, 0.86, 0.14), mat('#0c0c16', 0.5, 0.3));
      board.position.set(0, Y, -1.5); scene.add(board);
      const face = new T.Mesh(new T.PlaneGeometry(4.2, 0.74), new T.MeshBasicMaterial({ map: tex }));
      face.position.set(0, Y, -1.42); scene.add(face);
      // glowing tube frame
      const frameBar = (x, y, w2, h2, c) => { const m = new T.Mesh(new T.BoxGeometry(w2, h2, 0.05), new T.MeshBasicMaterial({ color: c })); m.position.set(x, y, -1.4); scene.add(m); };
      frameBar(0, Y + 0.44, 4.4, 0.06, '#22e6ff'); frameBar(0, Y - 0.44, 4.4, 0.06, '#ff49b0');
      frameBar(-2.2, Y, 0.06, 0.9, '#22e6ff'); frameBar(2.2, Y, 0.06, 0.9, '#ff49b0');
      // hanging rods up out of frame
      for (const x of [-1.5, 1.5]) { const rod = new T.Mesh(new T.CylinderGeometry(0.02, 0.02, 1.4, 6), mat('#3a3a44', 0.4, 0.6)); rod.position.set(x, Y + 1.1, -1.5); scene.add(rod); }
      const glow = new T.PointLight('#39d6ff', 0.5, 6, 2); glow.position.set(0, Y, -1.0); scene.add(glow);
    })();

    // ---- counter ----
    const counter = new T.Group(); scene.add(counter);
    // brushed stainless commercial worktable
    const steel = () => mat('#c7d0d6', 0.34, 0.72);
    const steelDark = () => mat('#9aa4ab', 0.42, 0.6);
    const cTop = new T.Mesh(new T.BoxGeometry(8.4, 0.1, 1.15), steel());
    cTop.position.set(0, COUNTER_Y, -0.1); cTop.receiveShadow = true; cTop.castShadow = true; counter.add(cTop);
    // raised back splash
    const splash = new T.Mesh(new T.BoxGeometry(8.4, 0.22, 0.06), steel()); splash.position.set(0, COUNTER_Y + 0.1, -0.66); counter.add(splash);
    // apron + under-shelf + legs (open commercial table)
    const apron = new T.Mesh(new T.BoxGeometry(8.4, 0.14, 1.02), steelDark()); apron.position.set(0, COUNTER_Y - 0.12, -0.12); counter.add(apron);
    const undershelf = new T.Mesh(new T.BoxGeometry(8.2, 0.05, 0.9), steelDark()); undershelf.position.set(0, 0.28, -0.12); counter.add(undershelf);
    for (const lx of [-4.0, -1.3, 1.3, 4.0]) for (const lz of [0.28, -0.5]) {
      const leg = new T.Mesh(new T.CylinderGeometry(0.045, 0.045, COUNTER_Y - 0.05, 10), steelDark());
      leg.position.set(lx, (COUNTER_Y - 0.05) / 2, lz); leg.castShadow = true; counter.add(leg);
      const foot = new T.Mesh(new T.CylinderGeometry(0.06, 0.05, 0.05, 10), mat('#2a2f33', 0.6)); foot.position.set(lx, 0.02, lz); counter.add(foot);
    }

    // ---- station: dirty-dish landing tray (stainless, with a lip) ----
    const tray = new T.Mesh(new T.BoxGeometry(1.0, 0.06, 0.8), steelDark());
    tray.position.set(STATION.pile, COUNTER_Y + 0.08, -0.1); scene.add(tray);
    for (const [dx, dz, w, d] of [[0, 0.4, 1.0, 0.05], [0, -0.4, 1.0, 0.05], [0.5, 0, 0.05, 0.8], [-0.5, 0, 0.05, 0.8]]) {
      const lip = new T.Mesh(new T.BoxGeometry(w, 0.07, d), steelDark()); lip.position.set(STATION.pile + dx, COUNTER_Y + 0.12, -0.1 + dz); scene.add(lip);
    }
    const dirtyGroup = new T.Group(); scene.add(dirtyGroup);

    // ---- station: deep commercial sink + pre-rinse spray unit ----
    const sinkX = STATION.sink;
    // deep basin (recessed box, open top)
    const basinOuter = new T.Mesh(new T.BoxGeometry(1.0, 0.4, 0.8), steel());
    basinOuter.position.set(sinkX, COUNTER_Y - 0.06, -0.05); scene.add(basinOuter);
    const basinIn = new T.Mesh(new T.BoxGeometry(0.86, 0.36, 0.66), steelDark());
    basinIn.material.side = T.BackSide; basinIn.position.set(sinkX, COUNTER_Y - 0.02, -0.05); scene.add(basinIn);
    // pre-rinse spray unit: riser + coil spring + gooseneck + spray gun
    const spray = new T.Group(); spray.position.set(sinkX - 0.34, COUNTER_Y, -0.34);
    const riser = new T.Mesh(new T.CylinderGeometry(0.028, 0.03, 0.42, 10), mat('#e2e8ec', 0.25, 0.85)); riser.position.y = 0.21; spray.add(riser);
    const valve = new T.Mesh(new T.CylinderGeometry(0.05, 0.05, 0.09, 10), mat('#d33b3b', 0.4)); valve.position.y = 0.44; valve.rotation.z = Math.PI / 2; valve.position.x = 0.06; spray.add(valve);
    // coiled spring hose (stack of torus rings)
    const coilMat = mat('#cfd6db', 0.3, 0.8);
    for (let i = 0; i < 14; i++) { const ring = new T.Mesh(new T.TorusGeometry(0.055, 0.012, 6, 16), coilMat); ring.position.set(0, 0.5 + i * 0.045, 0); ring.rotation.x = Math.PI / 2; spray.add(ring); }
    // gooseneck arch over the sink
    const neck = new T.Mesh(new T.TorusGeometry(0.16, 0.02, 8, 20, Math.PI * 0.9), mat('#e2e8ec', 0.25, 0.85));
    neck.position.set(0.15, 1.14, 0); neck.rotation.z = -Math.PI * 0.15; spray.add(neck);
    // spray gun head pointing down into the basin
    const gun = new T.Group(); gun.position.set(0.3, 1.02, 0);
    const grip = new T.Mesh(new T.CylinderGeometry(0.03, 0.035, 0.16, 8), mat('#2b2f33', 0.5)); grip.position.y = 0.02; gun.add(grip);
    const nozzle = new T.Mesh(new T.CylinderGeometry(0.05, 0.04, 0.08, 12), mat('#c7ced3', 0.3, 0.7)); nozzle.position.y = -0.1; gun.add(nozzle);
    spray.add(gun); scene.add(spray);
    // water stream + basin pool
    const water = new T.Mesh(new T.CylinderGeometry(0.022, 0.03, 0.42, 8), new T.MeshStandardMaterial({ color: '#bfeaff', transparent: true, opacity: 0.55 }));
    water.position.set(sinkX - 0.04, COUNTER_Y - 0.16, -0.39); water.visible = false; scene.add(water);
    const sinkWater = new T.Mesh(new T.PlaneGeometry(0.82, 0.62), new T.MeshStandardMaterial({ color: '#8fd8f4', transparent: true, opacity: 0.5, roughness: 0.15, metalness: 0.2 }));
    sinkWater.rotateX(-Math.PI / 2); sinkWater.position.set(sinkX, COUNTER_Y - 0.14, -0.05); sinkWater.visible = false; scene.add(sinkWater);

    // ---- station: commercial grey peg dish rack ----
    const rackGroup = new T.Group(); scene.add(rackGroup);
    const dryRack = makePegRack(0.98, 0.74); dryRack.position.set(STATION.rack, COUNTER_Y + 0.05, -0.08); scene.add(dryRack);

    // ---- station: tall stainless conveyor dishwasher ----
    const washer = new T.Group(); washer.position.set(STATION.washer, 0, 0); scene.add(washer);
    // legs
    for (const lx of [-0.55, 0.55]) for (const lz of [0.3, -0.55]) { const leg = new T.Mesh(new T.CylinderGeometry(0.05, 0.05, 0.2, 8), steelDark()); leg.position.set(lx, 0.1, lz); washer.add(leg); }
    // main body
    const wBody = new T.Mesh(new T.BoxGeometry(1.35, 1.4, 1.0), steel()); wBody.position.set(0, 0.9, -0.12); wBody.castShadow = true; wBody.receiveShadow = true; washer.add(wBody);
    // raised wash hood (the hump)
    const hood = new T.Mesh(new T.BoxGeometry(1.0, 0.5, 0.85), steel()); hood.position.set(0, 1.82, -0.12); hood.castShadow = true; washer.add(hood);
    // entry tunnel opening (dark recess) facing the rack side (+X toward rack)
    const opening = new T.Mesh(new T.BoxGeometry(0.12, 0.5, 0.7), mat('#20272c', 0.9)); opening.position.set(-0.7, 1.15, -0.12); washer.add(opening);
    const opening2 = new T.Mesh(new T.BoxGeometry(0.12, 0.5, 0.7), mat('#20272c', 0.9)); opening2.position.set(0.7, 1.15, -0.12); washer.add(opening2);
    // lifting front hood/door
    const door = new T.Group(); door.position.set(0, 0.9, 0.4); washer.add(door);
    const doorPanel = new T.Mesh(new T.BoxGeometry(1.15, 0.95, 0.07), mat('#dfe6ea', 0.3, 0.7)); door.add(doorPanel);
    const doorInset = new T.Mesh(new T.BoxGeometry(0.9, 0.7, 0.03), steelDark()); doorInset.position.z = 0.04; door.add(doorInset);
    const handle = new T.Mesh(new T.CylinderGeometry(0.03, 0.03, 0.95, 10), mat('#6f7a81', 0.3, 0.7)); handle.rotation.z = Math.PI / 2; handle.position.set(0, 0.55, 0.08); door.add(handle);
    const doorBaseY = 0.9;
    // control panel on top front (angled) with indicators + knobs
    const panel = new T.Mesh(new T.BoxGeometry(1.1, 0.28, 0.1), mat('#e6ebee', 0.4, 0.5));
    panel.position.set(0, 2.02, 0.34); panel.rotation.x = -0.5; washer.add(panel);
    const dotColors = ['#38d66a', '#ffcf3a', '#e94f4f'];
    for (let i = 0; i < 3; i++) { const d = new T.Mesh(new T.SphereGeometry(0.035, 10, 10), new T.MeshStandardMaterial({ color: dotColors[i], emissive: dotColors[i], emissiveIntensity: 0.5 })); d.position.set(-0.42 + i * 0.14, 2.08, 0.42); washer.add(d); }
    for (let i = 0; i < 2; i++) { const k = new T.Mesh(new T.CylinderGeometry(0.05, 0.05, 0.05, 12), mat('#3a4046', 0.5)); k.position.set(0.2 + i * 0.18, 2.02, 0.42); k.rotation.x = -0.5; washer.add(k); }
    // status light (its own emissive orb)
    const light = new T.Mesh(new T.SphereGeometry(0.05, 12, 12), new T.MeshStandardMaterial({ color: '#38d66a', emissive: '#2fbf5a', emissiveIntensity: 0.8 }));
    light.position.set(-0.42, 2.08, 0.44); washer.add(light);
    // plates visible at the machine mouth while loaded
    const washerRack = new T.Group(); washerRack.position.set(0, 1.05, 0.18); washer.add(washerRack); washerRack.visible = false;

    // ---- done shelf (clean stacked plates behind) ----
    const doneGroup = new T.Group(); scene.add(doneGroup);
    const shelf = new T.Mesh(new T.BoxGeometry(1.2, 0.06, 0.5), mat('#c98a5a', 0.7)); shelf.position.set(3.4, 1.5, -1.6); scene.add(shelf);

    // ---- deco: potted plant + hanging mugs ----
    const pot = new T.Mesh(new T.CylinderGeometry(0.22, 0.16, 0.3, 12), mat('#d76a4a', 0.6)); pot.position.set(-3.7, COUNTER_Y + 0.24, -0.1); scene.add(pot);
    for (let i = 0; i < 12; i++) { const leaf = new T.Mesh(new T.ConeGeometry(0.05, 0.5, 6), mat('#3f9b52', 0.7)); leaf.position.set(-3.7 + Math.cos(i) * 0.12, COUNTER_Y + 0.6, -0.1 + Math.sin(i) * 0.12); leaf.rotation.set(Math.sin(i) * 0.4, 0, Math.cos(i) * 0.4); scene.add(leaf); }
    for (let i = 0; i < 4; i++) { const mug = new T.Mesh(new T.CylinderGeometry(0.08, 0.08, 0.14, 12), mat(['#e94f5a', '#4fa8e9', '#f2c14e', '#5ad07a'][i], 0.6)); mug.position.set(3.6 + (i % 2) * 0.22, 1.56, -1.6 - Math.floor(i / 2) * 0.001); scene.add(mug); }

    // ---- plate factory ----
    function makePlate(dirty) {
      const grp = new T.Group();
      const disc = new T.Mesh(new T.CylinderGeometry(0.15, 0.13, 0.028, 22), mat(dirty ? '#cdbf9a' : '#fbfdff', 0.5));
      grp.add(disc);
      const ring = new T.Mesh(new T.TorusGeometry(0.15, 0.012, 8, 24), mat('#f2c14e', 0.3, 0.5)); ring.rotation.x = Math.PI / 2; ring.position.y = 0.012; grp.add(ring);
      if (dirty) { const grime = new T.Mesh(new T.CircleGeometry(0.09, 16), mat('#9c8a5c', 0.8)); grime.rotation.x = -Math.PI / 2; grime.position.y = 0.016; grp.add(grime); grp._grime = grime; }
      grp._disc = disc;
      return grp;
    }

    // grey commercial peg rack: lattice tray + grid of upright pegs
    function makePegRack(w, d) {
      const g = new T.Group();
      const plastic = mat('#b3b8bd', 0.75, 0.02);
      const dark = mat('#8b9197', 0.75);
      const base = new T.Mesh(new T.BoxGeometry(w, 0.05, d), plastic); base.position.y = 0.025; base.receiveShadow = true; g.add(base);
      const wallH = 0.13;
      for (const [x, z, ww, dd] of [[0, d / 2, w, 0.035], [0, -d / 2, w, 0.035], [w / 2, 0, 0.035, d], [-w / 2, 0, 0.035, d]]) {
        const wall = new T.Mesh(new T.BoxGeometry(ww, wallH, dd), plastic); wall.position.set(x, 0.02 + wallH / 2, z); g.add(wall);
      }
      const nx = Math.max(4, Math.round(w / 0.13)), nz = Math.max(3, Math.round(d / 0.14));
      for (let ix = 0; ix < nx; ix++) for (let iz = 0; iz < nz; iz++) {
        const peg = new T.Mesh(new T.CylinderGeometry(0.011, 0.014, 0.17, 6), dark);
        peg.position.set(-w / 2 + 0.09 + ix * (w - 0.18) / (nx - 1), 0.11, -d / 2 + 0.09 + iz * (d - 0.18) / (nz - 1));
        g.add(peg);
      }
      return g;
    }

    // preallocate dirty stack
    const dirtyPlates = [];
    for (let i = 0; i < 24; i++) { const pl = makePlate(true); pl.position.set(STATION.pile, COUNTER_Y + 0.17 + i * 0.03, -0.1); pl.visible = false; dirtyGroup.add(pl); dirtyPlates.push(pl); }
    // rack slots — plates leaning between the pegs
    const rackPlates = [];
    for (let i = 0; i < 8; i++) { const pl = makePlate(false); pl.rotation.x = Math.PI / 2; pl.rotation.z = 0.32; pl.position.set(STATION.rack - 0.36 + i * 0.095, COUNTER_Y + 0.21, -0.08); pl.visible = false; rackGroup.add(pl); rackPlates.push(pl); }
    // peg rack inside the dishwasher + its leaning plates
    const washerPegRack = makePegRack(0.82, 0.6); washerPegRack.position.set(0, -0.06, 0); washerRack.add(washerPegRack);
    const washerPlates = [];
    for (let i = 0; i < 8; i++) { const pl = makePlate(false); pl.rotation.x = Math.PI / 2; pl.rotation.z = 0.32; pl.position.set(-0.3 + i * 0.085, 0.13, 0); pl.visible = false; washerRack.add(pl); washerPlates.push(pl); }
    // done stack
    const donePlates = [];
    for (let i = 0; i < 30; i++) { const pl = makePlate(false); pl.position.set(3.4, 1.56 + i * 0.03, -1.6); pl.visible = false; doneGroup.add(pl); donePlates.push(pl); }

    let doorOpen = 0, doorTarget = 0, lightState = 'idle', wt = 0;

    const api = {
      scene, camera, renderer, STATION, COUNTER_Y,
      addSteward(s) { scene.add(s.group); },
      makePlate,
      setDirty(n) { for (let i = 0; i < dirtyPlates.length; i++) dirtyPlates[i].visible = i < n; },
      setRack(n) { for (let i = 0; i < rackPlates.length; i++) rackPlates[i].visible = i < n; },
      setDone(n) { for (let i = 0; i < donePlates.length; i++) donePlates[i].visible = i < n; },
      setWasherLoad(n) { for (let i = 0; i < washerPlates.length; i++) washerPlates[i].visible = i < n; washerRack.visible = n > 0; },
      openDoor(open) { doorTarget = open ? 1 : 0; },
      setLight(state) { lightState = state; },
      waterOn(on) { water.visible = on; sinkWater.visible = on; },
      resize() { const w = window.innerWidth, h = window.innerHeight; renderer.setSize(w, h, false); camera.aspect = w / h; camera.updateProjectionMatrix(); },
      render() { renderer.render(scene, camera); },
      update(dt, t) {
        doorOpen += (doorTarget - doorOpen) * Math.min(1, dt * 8);
        door.position.y = doorBaseY + doorOpen * 0.92;   // hood lifts to load/unload
        // indicator light color
        if (lightState === 'run') { light.material.color.set('#ff9a3c'); light.material.emissive.set('#ff7a1c'); light.material.emissiveIntensity = 0.6 + Math.sin(t * 8) * 0.4; }
        else if (lightState === 'done') { light.material.color.set('#38d66a'); light.material.emissive.set('#2fbf5a'); light.material.emissiveIntensity = 1.0; }
        else { light.material.color.set('#38d66a'); light.material.emissive.set('#2fbf5a'); light.material.emissiveIntensity = 0.7; }
        if (water.visible) { wt += dt; water.scale.y = 1 + Math.sin(wt * 30) * 0.1; }
      },
    };
    return api;
  }

  global.Galley = global.Galley || {};
  global.Galley.buildScene = build;
  global.Galley.STATION = STATION;

})(window);
