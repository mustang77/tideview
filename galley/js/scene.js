/* ============================================================================
 * Galley Rush — scene (hand-wash galley station: no crew, no machine)
 * ----------------------------------------------------------------------------
 * A realistic stainless dish pit: three dirty-dish stacks (plates / bowls /
 * glasses), a deep sink with a pre-rinse spray where the current item is
 * washed, and a drying peg rack that fills with clean, ready-to-serve items.
 * The player is the steward (first-person implied) — no avatar. Exposes the
 * setters the game calls to reflect state.
 * ==========================================================================*/
(function (global) {
  'use strict';
  const T = global.THREE;
  const mat = (c, r, m) => new T.MeshStandardMaterial({ color: c, roughness: r == null ? 0.7 : r, metalness: m || 0 });
  // place helper — mutate position/rotation (they are read-only refs in three)
  function mk(o, x, y, z, rx, ry, rz) { o.position.set(x, y, z); if (rx !== undefined) o.rotation.set(rx, ry, rz); return o; }

  const STATION = { plate: -2.7, bowl: -2.1, glass: -1.5, sink: 0.0, clean: 2.0 };
  const COUNTER_Y = 1.0;
  const ITEM_ICON = { plate: '🍽️', bowl: '🥣', glass: '🥛' };

  function backdropTexture() {
    const w = 1024, h = 512, cv = document.createElement('canvas'); cv.width = w; cv.height = h;
    const g = cv.getContext('2d');
    const sky = g.createLinearGradient(0, 0, 0, h);
    sky.addColorStop(0, '#ff9d5c'); sky.addColorStop(0.4, '#ffb98a'); sky.addColorStop(0.62, '#ffd9b0'); sky.addColorStop(0.68, '#8fd0e6'); sky.addColorStop(1, '#3a95c4');
    g.fillStyle = sky; g.fillRect(0, 0, w, h);
    g.fillStyle = 'rgba(255,247,220,0.95)'; g.beginPath(); g.arc(w * 0.5, h * 0.5, 60, 0, Math.PI * 2); g.fill();
    g.fillStyle = 'rgba(255,240,200,0.35)'; g.beginPath(); g.arc(w * 0.5, h * 0.5, 100, 0, Math.PI * 2); g.fill();
    g.fillStyle = '#2f88b8'; g.fillRect(0, h * 0.68, w, h * 0.32);
    g.fillStyle = 'rgba(255,220,170,0.5)'; g.fillRect(w * 0.42, h * 0.68, w * 0.16, h * 0.32);
    g.fillStyle = '#c98a6a'; g.beginPath(); g.moveTo(0, h * 0.68); g.lineTo(w * 0.2, h * 0.55); g.lineTo(w * 0.4, h * 0.68); g.fill();
    g.beginPath(); g.moveTo(w * 0.6, h * 0.68); g.lineTo(w * 0.8, h * 0.52); g.lineTo(w, h * 0.68); g.fill();
    return new T.CanvasTexture(cv);
  }

  function build(canvas) {
    const renderer = new T.WebGLRenderer({ canvas, antialias: true });
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 1.75));
    renderer.shadowMap.enabled = true; renderer.shadowMap.type = T.PCFSoftShadowMap;
    renderer.outputColorSpace = T.SRGBColorSpace;

    const scene = new T.Scene();
    scene.background = new T.Color('#ffd9b0');
    const camera = new T.PerspectiveCamera(48, 1, 0.1, 100);
    camera.position.set(0, 2.35, 4.5);
    camera.lookAt(0, 1.02, -0.1);

    scene.add(new T.AmbientLight('#fff2e0', 0.8));
    scene.add(new T.HemisphereLight('#ffe9d0', '#6a5540', 0.6));
    const key = new T.DirectionalLight('#ffdca8', 1.35);
    key.position.set(-3, 6, 5); key.castShadow = true; key.shadow.mapSize.set(1024, 1024);
    const sc = key.shadow.camera; sc.left = -6; sc.right = 6; sc.top = 6; sc.bottom = -6; sc.near = 1; sc.far = 30; key.shadow.bias = -0.0004;
    scene.add(key);
    const rim = new T.DirectionalLight('#bfe6ff', 0.45); rim.position.set(4, 4, -4); scene.add(rim);

    const floor = mk(new T.Mesh(new T.PlaneGeometry(24, 24), mat('#d3bd9f', 0.95)), 0, 0, 0, -Math.PI / 2, 0, 0);
    floor.receiveShadow = true; scene.add(floor);

    const wall = mk(new T.Mesh(new T.BoxGeometry(24, 8, 0.3), mat('#f3ead8', 0.9)), 0, 4, -2.2); wall.receiveShadow = true; scene.add(wall);
    scene.add(mk(new T.Mesh(new T.PlaneGeometry(9, 3.4), new T.MeshBasicMaterial({ map: backdropTexture() })), 0, 2.7, -2.03));
    scene.add(mk(new T.Mesh(new T.BoxGeometry(9.5, 3.9, 0.16), mat('#e8b06a', 0.5, 0.2)), 0, 2.7, -2.12));
    for (const x of [-3, 0, 3]) scene.add(mk(new T.Mesh(new T.BoxGeometry(0.12, 3.4, 0.12), mat('#e8b06a', 0.5, 0.2)), x, 2.7, -2.0));

    // neon sign
    (function () {
      const w = 1024, h = 230, cv = document.createElement('canvas'); cv.width = w; cv.height = h; const g = cv.getContext('2d');
      g.fillStyle = '#0b0b14'; g.fillRect(0, 0, w, h); g.textAlign = 'center'; g.textBaseline = 'middle';
      g.font = '900 118px Arial Black, Arial, sans-serif';
      g.shadowColor = '#22e6ff'; g.shadowBlur = 34; g.fillStyle = '#8ff8ff'; g.fillText('WORLD CRUISE', w / 2, 70);
      g.shadowColor = '#ff49b0'; g.shadowBlur = 30; g.font = '900 96px Arial Black, Arial, sans-serif'; g.fillStyle = '#ffb3e0'; g.fillText('ACADEMY', w / 2, 170);
      g.shadowBlur = 0; g.fillStyle = '#eafffe'; g.font = '900 118px Arial Black, Arial, sans-serif'; g.fillText('WORLD CRUISE', w / 2, 70);
      g.fillStyle = '#ffe6f5'; g.font = '900 96px Arial Black, Arial, sans-serif'; g.fillText('ACADEMY', w / 2, 170);
      const tex = new T.CanvasTexture(cv); const Y = 2.66;
      scene.add(mk(new T.Mesh(new T.BoxGeometry(4.4, 0.86, 0.14), mat('#0c0c16', 0.5, 0.3)), 0, Y, -1.5));
      scene.add(mk(new T.Mesh(new T.PlaneGeometry(4.2, 0.74), new T.MeshBasicMaterial({ map: tex })), 0, Y, -1.42));
      const fb = (x, y, w2, h2, c) => scene.add(mk(new T.Mesh(new T.BoxGeometry(w2, h2, 0.05), new T.MeshBasicMaterial({ color: c })), x, y, -1.4));
      fb(0, Y + 0.44, 4.4, 0.06, '#22e6ff'); fb(0, Y - 0.44, 4.4, 0.06, '#ff49b0'); fb(-2.2, Y, 0.06, 0.9, '#22e6ff'); fb(2.2, Y, 0.06, 0.9, '#ff49b0');
      const glow = new T.PointLight('#39d6ff', 0.5, 6, 2); glow.position.set(0, Y, -1.0); scene.add(glow);
    })();

    // ---- stainless counter ----
    const steel = () => mat('#c7d0d6', 0.34, 0.72);
    const steelDark = () => mat('#9aa4ab', 0.42, 0.6);
    const cTop = mk(new T.Mesh(new T.BoxGeometry(8.4, 0.1, 1.15), steel()), 0, COUNTER_Y, -0.1); cTop.receiveShadow = true; cTop.castShadow = true; scene.add(cTop);
    scene.add(mk(new T.Mesh(new T.BoxGeometry(8.4, 0.22, 0.06), steel()), 0, COUNTER_Y + 0.1, -0.66));
    scene.add(mk(new T.Mesh(new T.BoxGeometry(8.4, 0.14, 1.02), steelDark()), 0, COUNTER_Y - 0.12, -0.12));
    scene.add(mk(new T.Mesh(new T.BoxGeometry(8.2, 0.05, 0.9), steelDark()), 0, 0.28, -0.12));
    for (const lx of [-4.0, -1.3, 1.3, 4.0]) for (const lz of [0.28, -0.5]) scene.add(mk(new T.Mesh(new T.CylinderGeometry(0.045, 0.045, COUNTER_Y - 0.05, 10), steelDark()), lx, (COUNTER_Y - 0.05) / 2, lz));

    // ---- item factories ----
    function makePlate(dirty) {
      const grp = new T.Group();
      const disc = new T.Mesh(new T.CylinderGeometry(0.15, 0.13, 0.028, 22), mat(dirty ? '#cdbf9a' : '#fbfdff', 0.5)); grp.add(disc);
      const ring = mk(new T.Mesh(new T.TorusGeometry(0.15, 0.012, 8, 24), mat('#f2c14e', 0.3, 0.5)), 0, 0.012, 0, Math.PI / 2, 0, 0); grp.add(ring);
      if (dirty) { const gr = mk(new T.Mesh(new T.CircleGeometry(0.09, 16), mat('#9c8a5c', 0.8)), 0, 0.016, 0, -Math.PI / 2, 0, 0); grp.add(gr); }
      grp._disc = disc; grp.userData.kind = 'plate'; return grp;
    }
    function makeBowl(dirty) {
      const g = new T.Group();
      const b = mk(new T.Mesh(new T.SphereGeometry(0.1, 18, 10, 0, Math.PI * 2, Math.PI / 2, Math.PI / 2), mat(dirty ? '#cdbf9a' : '#fbfdff', 0.5)), 0, 0.1, 0); g.add(b);
      const rim = mk(new T.Mesh(new T.TorusGeometry(0.1, 0.009, 8, 20), mat('#e08a3a', 0.4)), 0, 0.1, 0, Math.PI / 2, 0, 0); g.add(rim);
      g._disc = b; g.userData.kind = 'bowl'; return g;
    }
    function makeGlass(dirty) {
      const g = new T.Group();
      const body = mk(new T.Mesh(new T.CylinderGeometry(0.05, 0.042, 0.17, 16), new T.MeshStandardMaterial({ color: dirty ? '#c9c6b4' : '#dff3ff', transparent: true, opacity: dirty ? 0.78 : 0.5, roughness: dirty ? 0.5 : 0.08, metalness: 0.1 })), 0, 0.085, 0); g.add(body);
      const rim = mk(new T.Mesh(new T.TorusGeometry(0.05, 0.006, 8, 18), new T.MeshStandardMaterial({ color: '#bfe6ff', transparent: true, opacity: 0.7 })), 0, 0.17, 0, Math.PI / 2, 0, 0); g.add(rim);
      g._disc = body; g.userData.kind = 'glass'; return g;
    }
    function makeItem(type, dirty) { return type === 'bowl' ? makeBowl(dirty) : type === 'glass' ? makeGlass(dirty) : makePlate(dirty); }

    function makePegRack(w, d) {
      const g = new T.Group();
      const plastic = mat('#b3b8bd', 0.75, 0.02), dark = mat('#8b9197', 0.75);
      g.add(mk(new T.Mesh(new T.BoxGeometry(w, 0.05, d), plastic), 0, 0.025, 0));
      const wallH = 0.13;
      for (const [x, z, ww, dd] of [[0, d / 2, w, 0.035], [0, -d / 2, w, 0.035], [w / 2, 0, 0.035, d], [-w / 2, 0, 0.035, d]]) g.add(mk(new T.Mesh(new T.BoxGeometry(ww, wallH, dd), plastic), x, 0.02 + wallH / 2, z));
      const nx = Math.max(4, Math.round(w / 0.13)), nz = Math.max(3, Math.round(d / 0.14));
      for (let ix = 0; ix < nx; ix++) for (let iz = 0; iz < nz; iz++) g.add(mk(new T.Mesh(new T.CylinderGeometry(0.011, 0.014, 0.17, 6), dark), -w / 2 + 0.09 + ix * (w - 0.18) / (nx - 1), 0.11, -d / 2 + 0.09 + iz * (d - 0.18) / (nz - 1)));
      return g;
    }

    // ---- three dirty stacks ----
    function dirtyStack(x, type) {
      scene.add(mk(new T.Mesh(new T.BoxGeometry(0.5, 0.05, 0.6), steelDark()), x, COUNTER_Y + 0.05, 0.02));
      for (let i = 0; i < 5; i++) {
        const it = makeItem(type, true); it.scale.set(0.82, 0.82, 0.82);
        if (type === 'plate') it.position.set(x, COUNTER_Y + 0.09 + i * 0.03, 0.02);
        else if (type === 'bowl') { it.rotation.x = Math.PI; it.position.set(x, COUNTER_Y + 0.28 - i * 0.045, 0.02); }
        else it.position.set(x - 0.14 + (i % 3) * 0.14, COUNTER_Y + 0.09, 0.02 + (i < 3 ? 0 : 0.16));
        scene.add(it);
      }
    }
    dirtyStack(STATION.plate, 'plate'); dirtyStack(STATION.bowl, 'bowl'); dirtyStack(STATION.glass, 'glass');

    // ---- sink + pre-rinse spray ----
    const sinkX = STATION.sink;
    scene.add(mk(new T.Mesh(new T.BoxGeometry(1.0, 0.4, 0.8), steel()), sinkX, COUNTER_Y - 0.06, -0.05));
    const basinIn = mk(new T.Mesh(new T.BoxGeometry(0.86, 0.36, 0.66), steelDark()), sinkX, COUNTER_Y - 0.02, -0.05); basinIn.material.side = T.BackSide; scene.add(basinIn);
    const spray = new T.Group(); spray.position.set(sinkX - 0.34, COUNTER_Y, -0.34);
    spray.add(mk(new T.Mesh(new T.CylinderGeometry(0.028, 0.03, 0.42, 10), mat('#e2e8ec', 0.25, 0.85)), 0, 0.21, 0));
    const coilMat = mat('#cfd6db', 0.3, 0.8);
    for (let i = 0; i < 14; i++) spray.add(mk(new T.Mesh(new T.TorusGeometry(0.055, 0.012, 6, 16), coilMat), 0, 0.5 + i * 0.045, 0, Math.PI / 2, 0, 0));
    spray.add(mk(new T.Mesh(new T.TorusGeometry(0.16, 0.02, 8, 20, Math.PI * 0.9), mat('#e2e8ec', 0.25, 0.85)), 0.15, 1.14, 0, 0, 0, -Math.PI * 0.15));
    const gun = new T.Group(); gun.position.set(0.3, 1.02, 0);
    gun.add(mk(new T.Mesh(new T.CylinderGeometry(0.03, 0.035, 0.16, 8), mat('#2b2f33', 0.5)), 0, 0.02, 0));
    gun.add(mk(new T.Mesh(new T.CylinderGeometry(0.05, 0.04, 0.08, 12), mat('#c7ced3', 0.3, 0.7)), 0, -0.1, 0));
    spray.add(gun); scene.add(spray);
    const water = mk(new T.Mesh(new T.CylinderGeometry(0.022, 0.03, 0.42, 8), new T.MeshStandardMaterial({ color: '#bfeaff', transparent: true, opacity: 0.55 })), sinkX - 0.04, COUNTER_Y - 0.16, -0.39); water.visible = false; scene.add(water);
    const sinkWater = mk(new T.Mesh(new T.PlaneGeometry(0.82, 0.62), new T.MeshStandardMaterial({ color: '#8fd8f4', transparent: true, opacity: 0.5, roughness: 0.15, metalness: 0.2 })), sinkX, COUNTER_Y - 0.14, -0.05, -Math.PI / 2, 0, 0); sinkWater.visible = false; scene.add(sinkWater);
    let washItem = null, washType = null;
    function setWashItem(type) {
      if (washItem) { scene.remove(washItem); washItem = null; }
      washType = type || null;
      if (!type) return;
      washItem = makeItem(type, true); washItem.position.set(sinkX, COUNTER_Y + 0.14, -0.05); scene.add(washItem);
    }

    // ---- clean drying rack ----
    scene.add(mk(makePegRack(0.98, 0.74), STATION.clean, COUNTER_Y + 0.05, -0.06));
    const cleanSlots = [];
    const cleanPattern = ['plate', 'glass', 'bowl', 'plate', 'bowl', 'glass', 'plate', 'bowl'];
    for (let i = 0; i < 8; i++) {
      const it = makeItem(cleanPattern[i], false);
      if (cleanPattern[i] === 'plate') { it.rotation.x = Math.PI / 2; it.rotation.z = 0.32; it.position.set(STATION.clean - 0.34 + i * 0.095, COUNTER_Y + 0.2, -0.06); }
      else if (cleanPattern[i] === 'bowl') { it.rotation.x = Math.PI; it.position.set(STATION.clean - 0.34 + i * 0.095, COUNTER_Y + 0.28, -0.06); }
      else it.position.set(STATION.clean - 0.34 + i * 0.095, COUNTER_Y + 0.11, -0.06);
      it.visible = false; scene.add(it); cleanSlots.push(it);
    }

    // plant
    scene.add(mk(new T.Mesh(new T.CylinderGeometry(0.22, 0.16, 0.3, 12), mat('#d76a4a', 0.6)), -3.8, COUNTER_Y + 0.24, -0.1));
    for (let i = 0; i < 12; i++) scene.add(mk(new T.Mesh(new T.ConeGeometry(0.05, 0.5, 6), mat('#3f9b52', 0.7)), -3.8 + Math.cos(i) * 0.12, COUNTER_Y + 0.6, -0.1 + Math.sin(i) * 0.12, Math.sin(i) * 0.4, 0, Math.cos(i) * 0.4));

    let wt = 0, washFrac = 0;
    return {
      scene, camera, renderer, STATION, COUNTER_Y, ITEM_ICON, makeItem,
      setWashing(type, frac) { if (type !== washType) setWashItem(type); washFrac = frac || 0; this.waterOn(!!type); },
      setCleanStock(total) { for (let i = 0; i < cleanSlots.length; i++) cleanSlots[i].visible = i < total; },
      waterOn(on) { water.visible = on; sinkWater.visible = on; },
      resize() { const w = window.innerWidth, h = window.innerHeight; renderer.setSize(w, h, false); camera.aspect = w / h; camera.updateProjectionMatrix(); },
      render() { renderer.render(scene, camera); },
      update(dt) {
        wt += dt;
        if (water.visible) water.scale.y = 1 + Math.sin(wt * 30) * 0.12;
        if (washItem) { washItem.rotation.y += dt * 3; washItem.position.y = COUNTER_Y + 0.14 + Math.sin(wt * 12) * 0.015; if (washItem._disc) { const c = 0.8 + washFrac * 0.19; washItem._disc.material.color.setRGB(c, 0.76 + washFrac * 0.23, 0.6 + washFrac * 0.39); } }
      },
    };
  }

  global.Galley = global.Galley || {};
  global.Galley.buildScene = build;
  global.Galley.STATION = STATION;
  global.Galley.ITEM_ICON = ITEM_ICON;

})(window);
