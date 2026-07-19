/* ============================================================================
 * Break & Run — 3D scene
 * ----------------------------------------------------------------------------
 * Everything you see: the table, cloth, rails, drop pockets, numbered balls,
 * cue stick, the aim guide, lights and shadows, and a camera rig that flips
 * between an over-the-cue "aim" view and a free orbit. Reads ball state from
 * the physics Simulation each frame and paints it.
 * ==========================================================================*/
(function (global) {
  'use strict';
  const C = global.Pool.CONFIG;
  const T = global.THREE;

  // --- Standard pool ball colours -------------------------------------------
  const BALL_COLORS = {
    1: '#f6c500', 2: '#0b45a6', 3: '#c81d11', 4: '#4b2a83',
    5: '#e56717', 6: '#0a7c3f', 7: '#7a1f1f', 8: '#111111',
    9: '#f6c500', 10: '#0b45a6', 11: '#c81d11', 12: '#4b2a83',
    13: '#e56717', 14: '#0a7c3f', 15: '#7a1f1f',
  };

  // Draw a wrappable ball texture on a canvas (2:1). Solids are fully
  // coloured with two numbered white discs; stripes are white with a coloured
  // equatorial band.
  function ballTexture(number, striped) {
    const W = 512, H = 256;
    const cv = document.createElement('canvas');
    cv.width = W; cv.height = H;
    const g = cv.getContext('2d');
    const color = number === 0 ? '#f7f5ef' : BALL_COLORS[number];

    if (number === 0) {
      g.fillStyle = '#f7f5ef';
      g.fillRect(0, 0, W, H);
      // subtle logo dot
      g.fillStyle = '#d23b3b';
      g.beginPath(); g.arc(W * 0.5, H * 0.5, 10, 0, Math.PI * 2); g.fill();
      const tex = new T.CanvasTexture(cv);
      tex.anisotropy = 8;
      return tex;
    }

    if (striped) {
      g.fillStyle = '#f7f5ef';
      g.fillRect(0, 0, W, H);
      g.fillStyle = color;
      g.fillRect(0, H * 0.30, W, H * 0.40); // equatorial band
    } else {
      g.fillStyle = color;
      g.fillRect(0, 0, W, H);
    }

    // Two numbered white discs on opposite sides (u = 0.25 and 0.75)
    for (const u of [0.25, 0.75]) {
      const cx = u * W, cy = H * 0.5;
      g.fillStyle = '#f7f5ef';
      g.beginPath(); g.arc(cx, cy, 46, 0, Math.PI * 2); g.fill();
      g.fillStyle = '#111';
      g.font = 'bold 54px Arial';
      g.textAlign = 'center';
      g.textBaseline = 'middle';
      g.fillText(String(number), cx, cy + 3);
    }
    const tex = new T.CanvasTexture(cv);
    tex.anisotropy = 8;
    return tex;
  }

  function clothTexture() {
    const S = 512;
    const cv = document.createElement('canvas');
    cv.width = S; cv.height = S;
    const g = cv.getContext('2d');
    g.fillStyle = '#0f7a46';
    g.fillRect(0, 0, S, S);
    // fine felt noise
    const img = g.getImageData(0, 0, S, S);
    const d = img.data;
    for (let i = 0; i < d.length; i += 4) {
      const n = (Math.sin(i * 12.9898) * 43758.5453) % 1;
      const v = (n - Math.floor(n)) * 18 - 9;
      d[i] = Math.max(0, Math.min(255, d[i] + v));
      d[i + 1] = Math.max(0, Math.min(255, d[i + 1] + v));
      d[i + 2] = Math.max(0, Math.min(255, d[i + 2] + v));
    }
    g.putImageData(img, 0, 0);
    const tex = new T.CanvasTexture(cv);
    tex.wrapS = tex.wrapT = T.RepeatWrapping;
    tex.repeat.set(6, 3);
    return tex;
  }

  function PoolScene(canvas) {
    this.canvas = canvas;
    this.renderer = new T.WebGLRenderer({ canvas, antialias: true });
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    this.renderer.shadowMap.enabled = true;
    this.renderer.shadowMap.type = T.PCFSoftShadowMap;
    this.renderer.outputColorSpace = T.SRGBColorSpace;

    this.scene = new T.Scene();
    this.scene.background = new T.Color('#0a0d12');
    this.scene.fog = new T.Fog('#0a0d12', 4, 12);

    this.camera = new T.PerspectiveCamera(45, 1, 0.05, 100);

    // Camera rig
    this.cam = {
      target: new T.Vector3(0, 0, 0),
      dist: 1.9,
      az: Math.PI,     // azimuth
      el: 0.62,        // elevation (radians above table)
      mode: 'aim',     // 'aim' | 'free'
    };
    this.aimAngle = 0; // direction (radians in XZ) the cue ball will travel

    this.ballMeshes = {};   // id -> mesh
    this._buildLights();
    this._buildTable();
    this._buildCue();
    this._buildAimGuide();
    this.resize();
  }

  PoolScene.prototype._buildLights = function () {
    this.scene.add(new T.AmbientLight('#8090a0', 0.55));
    const hemi = new T.HemisphereLight('#dfe8ff', '#20180f', 0.5);
    this.scene.add(hemi);

    const key = new T.DirectionalLight('#fff4e0', 1.15);
    key.position.set(0.8, 2.6, 0.9);
    key.castShadow = true;
    key.shadow.mapSize.set(2048, 2048);
    key.shadow.camera.left = -1.6;
    key.shadow.camera.right = 1.6;
    key.shadow.camera.top = 1.0;
    key.shadow.camera.bottom = -1.0;
    key.shadow.camera.near = 0.5;
    key.shadow.camera.far = 6;
    key.shadow.bias = -0.0005;
    this.scene.add(key);

    // Two warm hall lamps hanging over the cloth
    for (const x of [-0.6, 0.6]) {
      const lamp = new T.PointLight('#ffe9c0', 0.5, 5, 2);
      lamp.position.set(x, 1.5, 0);
      this.scene.add(lamp);
      const shade = new T.Mesh(
        new T.ConeGeometry(0.16, 0.16, 24, 1, true),
        new T.MeshStandardMaterial({ color: '#1c2530', side: T.DoubleSide, metalness: 0.6, roughness: 0.4 })
      );
      shade.position.set(x, 1.62, 0);
      this.scene.add(shade);
    }
  };

  PoolScene.prototype._buildTable = function () {
    const hx = C.PLAY_HALF_X, hz = C.PLAY_HALF_Z, r = C.R;
    const railW = 0.09;          // wood rail width
    const railH = 0.055;         // rail height above cloth
    const surfaceY = 0;          // cloth top plane at y=0; balls sit at y=r
    const group = new T.Group();

    // Wooden frame (outer apron) — sits BELOW the cloth so only its edges show.
    const woodMat = new T.MeshStandardMaterial({ color: '#5a2f16', roughness: 0.5, metalness: 0.15 });
    const outerX = hx + railW, outerZ = hz + railW;
    const frameH = 0.12;
    const frame = new T.Mesh(
      new T.BoxGeometry(outerX * 2 + 0.09, frameH, outerZ * 2 + 0.09),
      woodMat
    );
    frame.position.y = surfaceY - 0.075;   // top at -0.015, just under the cloth
    frame.receiveShadow = true;
    frame.castShadow = true;
    group.add(frame);

    // Cloth playing surface (green felt) — topmost surface in the play area.
    const cloth = new T.Mesh(
      new T.BoxGeometry(hx * 2 + railW * 2, 0.05, hz * 2 + railW * 2),
      new T.MeshStandardMaterial({ map: clothTexture(), color: '#1aa15e', roughness: 0.98, metalness: 0 })
    );
    cloth.position.y = surfaceY - 0.025;   // top at y = 0
    cloth.receiveShadow = true;
    group.add(cloth);

    // Rail caps (wood) on top of the four sides, split around pockets.
    const capMat = new T.MeshStandardMaterial({ color: '#6b3a1c', roughness: 0.45, metalness: 0.2 });
    const capH = 0.045, capTop = surfaceY + railH;
    const pocketGap = C.POCKET_CORNER_R * 1.6;
    // Long rails (run along X at ±(hz+railW/2)), split by the side pocket.
    const segLenX = hx - pocketGap; // each half from center-ish to corner
    function longRail(sideZ) {
      for (const sx of [-1, 1]) {
        const seg = new T.Mesh(new T.BoxGeometry(segLenX, capH, railW), capMat);
        seg.position.set(sx * (pocketGap + segLenX / 2) / 1, capTop, sideZ * (hz + railW / 2));
        seg.position.x = sx * (hx + pocketGap) / 2;
        seg.castShadow = true; seg.receiveShadow = true;
        group.add(seg);
      }
    }
    longRail(1); longRail(-1);
    // Short rails (run along Z at ±(hx+railW/2))
    const segLenZ = hz * 2 - pocketGap * 1.2;
    for (const sx of [-1, 1]) {
      const seg = new T.Mesh(new T.BoxGeometry(railW, capH, segLenZ), capMat);
      seg.position.set(sx * (hx + railW / 2), capTop, 0);
      seg.castShadow = true; seg.receiveShadow = true;
      group.add(seg);
    }

    // Cushions (green rubber bumpers) inside the rails, with pocket gaps.
    const cushMat = new T.MeshStandardMaterial({ color: '#0c7a44', roughness: 0.85 });
    const cushH = 0.032, cushT = 0.028, cushY = surfaceY + cushH / 2 + 0.004;
    // long cushions along X
    for (const sz of [-1, 1]) {
      for (const sx of [-1, 1]) {
        const len = hx - pocketGap;
        const c = new T.Mesh(new T.BoxGeometry(len, cushH, cushT), cushMat);
        c.position.set(sx * (hx + pocketGap) / 2 - sx * 0, cushY, sz * (hz - cushT / 2));
        c.position.x = sx * (pocketGap / 2 + len / 2);
        c.castShadow = true; c.receiveShadow = true;
        group.add(c);
      }
    }
    // short cushions along Z
    for (const sx of [-1, 1]) {
      const len = hz * 2 - pocketGap * 1.2;
      const c = new T.Mesh(new T.BoxGeometry(cushT, cushH, len), cushMat);
      c.position.set(sx * (hx - cushT / 2), cushY, 0);
      c.castShadow = true; c.receiveShadow = true;
      group.add(c);
    }

    // Pockets — dark cylinders + leather-ish ring.
    for (const p of C.POCKETS) {
      const hole = new T.Mesh(
        new T.CylinderGeometry(p.r * 1.05, p.r * 0.9, 0.12, 24),
        new T.MeshStandardMaterial({ color: '#050505', roughness: 1 })
      );
      hole.position.set(p.x, surfaceY - 0.05, p.z);
      group.add(hole);
      const ring = new T.Mesh(
        new T.TorusGeometry(p.r * 1.05, 0.014, 12, 28),
        new T.MeshStandardMaterial({ color: '#1a1207', roughness: 0.6, metalness: 0.3 })
      );
      ring.rotation.x = Math.PI / 2;
      ring.position.set(p.x, surfaceY + 0.006, p.z);
      group.add(ring);
    }

    // Diamonds (sights) along the rails — a classy touch.
    const dMat = new T.MeshStandardMaterial({ color: '#f4ead2', roughness: 0.4, metalness: 0.3 });
    function diamond(x, z) {
      const d = new T.Mesh(new T.SphereGeometry(0.008, 10, 10), dMat);
      d.position.set(x, capTop + 0.001, z);
      d.scale.y = 0.5;
      group.add(d);
    }
    for (let i = 1; i <= 3; i++) {
      const x = -hx + (2 * hx) * (i / 4);
      diamond(x, hz + railW / 2); diamond(x, -(hz + railW / 2));
    }
    for (let i = 1; i <= 3; i++) {
      const z = -hz + (2 * hz) * (i / 4);
      if (i === 2) continue;
      diamond(hx + railW / 2, z); diamond(-(hx + railW / 2), z);
    }

    // Floor & dark room
    const floor = new T.Mesh(
      new T.CircleGeometry(9, 48),
      new T.MeshStandardMaterial({ color: '#0c0f14', roughness: 1 })
    );
    floor.rotation.x = -Math.PI / 2;
    floor.position.y = -0.62;
    floor.receiveShadow = true;
    this.scene.add(floor);

    // Legs
    const legMat = new T.MeshStandardMaterial({ color: '#3a1e0e', roughness: 0.6 });
    for (const sx of [-1, 1]) for (const sz of [-1, 1]) {
      const leg = new T.Mesh(new T.CylinderGeometry(0.05, 0.06, 0.6, 12), legMat);
      leg.position.set(sx * (hx - 0.12), -0.33, sz * (hz - 0.1));
      leg.castShadow = true;
      group.add(leg);
    }

    group.position.y = 0;
    this.scene.add(group);
    this.tableGroup = group;
    this.surfaceY = surfaceY;
  };

  PoolScene.prototype.buildBalls = function (balls) {
    // remove old
    for (const id in this.ballMeshes) {
      this.tableGroup.remove(this.ballMeshes[id]);
    }
    this.ballMeshes = {};
    const r = C.R;
    for (const b of balls) {
      const tex = ballTexture(b.group === 'cue' ? 0 : b.number, b.striped);
      const mat = new T.MeshStandardMaterial({
        map: tex, roughness: 0.18, metalness: 0.05,
        envMapIntensity: 0.6,
      });
      const mesh = new T.Mesh(new T.SphereGeometry(r, 40, 32), mat);
      mesh.castShadow = true;
      mesh.receiveShadow = true;
      mesh.position.set(b.x, r, b.z);
      // random start orientation
      mesh.rotation.set(b.number * 1.3, b.number * 0.7, b.number * 2.1);
      this.tableGroup.add(mesh);
      this.ballMeshes[b.id] = mesh;
      b._quat = mesh.quaternion.clone();
    }
  };

  PoolScene.prototype._buildCue = function () {
    const len = 1.45, r0 = 0.006, r1 = 0.014;
    const geo = new T.CylinderGeometry(r0, r1, len, 20);
    geo.translate(0, len / 2, 0); // base at origin, tip toward -y after rotate
    const mat = new T.MeshStandardMaterial({ color: '#c99a55', roughness: 0.35, metalness: 0.1 });
    const wrap = new T.MeshStandardMaterial({ color: '#1c1c22', roughness: 0.5 });
    const cue = new T.Mesh(geo, mat);
    // dark grip near butt
    const grip = new T.Mesh(new T.CylinderGeometry(r1 * 0.98, r1, 0.35, 20), wrap);
    grip.position.y = len - 0.2;
    cue.add(grip);
    // white ferrule + blue tip
    const tip = new T.Mesh(new T.CylinderGeometry(r0, r0, 0.02, 16),
      new T.MeshStandardMaterial({ color: '#2a6fb0' }));
    tip.position.y = -0.01;
    cue.add(tip);
    cue.castShadow = true;
    this.cue = cue;
    this.cueLen = len;
    this.scene.add(cue);
  };

  PoolScene.prototype._buildAimGuide = function () {
    const mkLine = (color, w) => {
      const mat = new T.LineBasicMaterial({ color, transparent: true, opacity: 0.9 });
      const geo = new T.BufferGeometry().setFromPoints([new T.Vector3(), new T.Vector3()]);
      const line = new T.Line(geo, mat);
      line.renderOrder = 5;
      this.scene.add(line);
      return line;
    };
    this.aimLine = mkLine('#eafff4', 2);
    this.reflectLine = mkLine('#8fd3ff', 1);
    this.objectLine = mkLine('#ffd27f', 1);
    // ghost ball
    this.ghost = new T.Mesh(
      new T.SphereGeometry(C.R, 24, 18),
      new T.MeshBasicMaterial({ color: '#ffffff', transparent: true, opacity: 0.28, wireframe: false })
    );
    this.ghost.visible = false;
    this.scene.add(this.ghost);
  };

  // Update aim guide + cue stick given the sim state. pullback in 0..1.
  PoolScene.prototype.updateAim = function (sim, pullback, showGuide) {
    const cue = sim.cueBall();
    if (!cue || !cue.active) {
      this.cue.visible = false;
      this.aimLine.visible = this.reflectLine.visible = this.objectLine.visible = false;
      this.ghost.visible = false;
      return;
    }
    const ax = Math.cos(this.aimAngle), az = Math.sin(this.aimAngle);
    const r = C.R;
    const ox = cue.x, oz = cue.z;

    // cue stick behind the ball, opposite aim, pulled back by power
    if (showGuide) {
      this.cue.visible = true;
      const gap = 0.02 + pullback * 0.28;
      const bx = ox - ax * (r + gap);
      const bz = oz - az * (r + gap);
      this.cue.position.set(bx, r, bz);
      // orient cylinder (its +y axis) to point from tip(at ball) up along -aim
      const dir = new T.Vector3(-ax, 0.18, -az).normalize();
      const up = new T.Vector3(0, 1, 0);
      const q = new T.Quaternion().setFromUnitVectors(up, dir);
      this.cue.quaternion.copy(q);
    } else {
      this.cue.visible = false;
    }

    if (!showGuide) {
      this.aimLine.visible = this.reflectLine.visible = this.objectLine.visible = false;
      this.ghost.visible = false;
      return;
    }

    // Ray forward to first ball / cushion
    const hit = sim.rayFirstBall(ox, oz, ax, az, cue.id);
    let endX, endZ;
    if (hit) {
      endX = ox + ax * hit.t;
      endZ = oz + az * hit.t;
      // ghost ball centre at contact
      this.ghost.visible = true;
      this.ghost.position.set(endX, r, endZ);
      // object ball resulting direction = from ghost centre to object centre
      const dxo = hit.ball.x - endX, dzo = hit.ball.z - endZ;
      const ol = Math.hypot(dxo, dzo) || 1;
      this._setLine(this.objectLine, hit.ball.x, hit.ball.z,
        hit.ball.x + dxo / ol * 0.35, hit.ball.z + dzo / ol * 0.35);
      this.objectLine.visible = true;
      this.reflectLine.visible = false;
    } else {
      // reflect off nearest cushion
      const refl = this._cushionHit(ox, oz, ax, az);
      endX = refl.x; endZ = refl.z;
      this.ghost.visible = false;
      this._setLine(this.reflectLine, refl.x, refl.z,
        refl.x + refl.rx * 0.4, refl.z + refl.rz * 0.4);
      this.reflectLine.visible = true;
      this.objectLine.visible = false;
    }
    this._setLine(this.aimLine, ox, oz, endX, endZ);
    this.aimLine.visible = true;
  };

  PoolScene.prototype._setLine = function (line, x0, z0, x1, z1) {
    const y = C.R + 0.001;
    const pos = line.geometry.attributes.position;
    pos.setXYZ(0, x0, y, z0);
    pos.setXYZ(1, x1, y, z1);
    pos.needsUpdate = true;
  };

  // find where ray from (ox,oz) dir(ax,az) meets play boundary; return
  // contact + reflected dir.
  PoolScene.prototype._cushionHit = function (ox, oz, ax, az) {
    const hx = C.PLAY_HALF_X - C.R, hz = C.PLAY_HALF_Z - C.R;
    let tBest = Infinity, nx = 0, nz = 0;
    if (ax > 1e-6) { const t = (hx - ox) / ax; if (t < tBest) { tBest = t; nx = -1; nz = 0; } }
    if (ax < -1e-6) { const t = (-hx - ox) / ax; if (t < tBest) { tBest = t; nx = 1; nz = 0; } }
    if (az > 1e-6) { const t = (hz - oz) / az; if (t < tBest) { tBest = t; nx = 0; nz = -1; } }
    if (az < -1e-6) { const t = (-hz - oz) / az; if (t < tBest) { tBest = t; nx = 0; nz = 1; } }
    const cx = ox + ax * tBest, cz = oz + az * tBest;
    // reflect dir about normal
    const dot = ax * nx + az * nz;
    const rx = ax - 2 * dot * nx, rz = az - 2 * dot * nz;
    return { x: cx, z: cz, rx, rz };
  };

  // Advance ball meshes (position + rolling) toward sim state.
  PoolScene.prototype.syncBalls = function (sim, dt) {
    for (const b of sim.balls) {
      const m = this.ballMeshes[b.id];
      if (!m) continue;
      if (b.pocketed) {
        // drop animation into the pocket
        if (m.visible) {
          m.position.x += (b.sinkX - m.position.x) * Math.min(1, dt * 8);
          m.position.z += (b.sinkZ - m.position.z) * Math.min(1, dt * 8);
          m.position.y -= dt * 0.6;
          if (m.position.y < -0.12) m.visible = false;
        }
        continue;
      }
      m.position.set(b.x, C.R, b.z);
      const sp = Math.hypot(b.vx, b.vz);
      if (sp > 1e-5) {
        const axis = new T.Vector3(b.vz, 0, -b.vx).normalize();
        const ang = (sp * dt) / C.R;
        const q = new T.Quaternion().setFromAxisAngle(axis, ang);
        m.quaternion.premultiply(q);
      }
    }
  };

  // ------------------------------------------------------------- camera rig
  PoolScene.prototype.updateCamera = function (sim, dt) {
    const tgt = this.cam.target;
    // Aim mode is a STABLE, near-top-down view of the whole table — it does
    // not swing around as you aim (that made aiming disorienting). You rotate
    // the cue by dragging; the camera stays put. Free mode orbits freely.
    if (this.cam.mode === 'aim') {
      tgt.lerp(new T.Vector3(0, 0, 0), Math.min(1, dt * 6));
    }
    const el = Math.max(0.08, Math.min(1.5, this.cam.el));
    const d = this.cam.dist;
    const cx = tgt.x + Math.cos(this.cam.az) * Math.cos(el) * d;
    const cy = tgt.y + Math.sin(el) * d;
    const cz = tgt.z + Math.sin(this.cam.az) * Math.cos(el) * d;
    this.camera.position.lerp(new T.Vector3(cx, cy, cz), Math.min(1, dt * 8));
    this.camera.lookAt(tgt);
  };

  // The default aiming view: a STATIC, near-top-down look at the whole table
  // (like the app-store 8-ball games). Being nearly overhead means the screen
  // maps almost 1:1 to the cloth, so pointing the cue where you want is easy.
  PoolScene.prototype.setAimView = function () {
    this.cam.mode = 'aim';
    this.cam.az = -Math.PI / 2;   // long axis runs across the screen
    this.cam.el = 1.47;           // ~84°: essentially top-down, tiny bit of depth
    this.cam.dist = this._fitDist();
  };

  PoolScene.prototype._fitDist = function () {
    // Pull back just enough to frame the whole table for the current aspect.
    // Near-overhead, the binding constraint is the short axis fitting vertically.
    const aspect = this.camera.aspect || 1.8;
    if (aspect >= 2.2) return 1.78;
    if (aspect >= 2.0) return 1.9;
    if (aspect >= 1.6) return 2.15;
    if (aspect >= 1.2) return 2.7;
    return 3.6;                    // portrait-ish (should be rotated anyway)
  };

  PoolScene.prototype.setOverhead = function () {
    this.cam.mode = 'aim';
    this.setAimView();
  };

  PoolScene.prototype.resize = function () {
    const w = window.innerWidth || this.canvas.clientWidth;
    const h = window.innerHeight || this.canvas.clientHeight;
    this.renderer.setSize(w, h, false);
    this.camera.aspect = w / h;
    this.camera.updateProjectionMatrix();
  };

  PoolScene.prototype.render = function () {
    this.renderer.render(this.scene, this.camera);
  };

  // Project a world point to CSS pixel coordinates (for the cue-drag gesture).
  PoolScene.prototype.worldToScreen = function (x, y, z) {
    const v = new T.Vector3(x, y, z).project(this.camera);
    const rect = this.canvas.getBoundingClientRect();
    return {
      x: (v.x * 0.5 + 0.5) * rect.width + rect.left,
      y: (-v.y * 0.5 + 0.5) * rect.height + rect.top,
      behind: v.z > 1,
    };
  };

  // Convert a screen point to a point on the cloth plane (y = R).
  PoolScene.prototype.screenToTable = function (clientX, clientY) {
    const rect = this.canvas.getBoundingClientRect();
    const ndc = new T.Vector2(
      ((clientX - rect.left) / rect.width) * 2 - 1,
      -((clientY - rect.top) / rect.height) * 2 + 1
    );
    const ray = new T.Raycaster();
    ray.setFromCamera(ndc, this.camera);
    const plane = new T.Plane(new T.Vector3(0, 1, 0), -C.R);
    const pt = new T.Vector3();
    ray.ray.intersectPlane(plane, pt);
    return pt;
  };

  global.Pool.PoolScene = PoolScene;
  global.Pool.BALL_COLORS = BALL_COLORS;

})(window);
