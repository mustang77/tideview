/* ============================================================================
 * Grandmaster — 3D board & pieces
 * ----------------------------------------------------------------------------
 * A wooden board, procedurally-modelled Staunton-ish pieces, an orbit camera,
 * highlights (selection, legal-move dots, last move, check), and smooth move
 * animations. Reads the engine's board array; never contains rules.
 * ==========================================================================*/
(function (global) {
  'use strict';
  const T = global.THREE;
  const mat = (c, r, m) => new T.MeshStandardMaterial({ color: c, roughness: r == null ? 0.55 : r, metalness: m || 0 });
  function place(o, x, y, z) { o.position.set(x, y, z); return o; }

  const TYPE = { P: 1, N: 2, B: 3, R: 4, Q: 5, K: 6 };

  // ---- piece builders (return a Group centred at origin, sitting on y=0) ----
  function pieceGeom(type, material) {
    const g = new T.Group();
    const add = (m, y) => { m.position.y = y; m.castShadow = true; g.add(m); return m; };
    // shared turned base
    const base = new T.Mesh(new T.CylinderGeometry(0.33, 0.38, 0.14, 24), material); add(base, 0.07);
    add(new T.Mesh(new T.CylinderGeometry(0.26, 0.33, 0.06, 24), material), 0.16);
    if (type === TYPE.P) {
      add(new T.Mesh(new T.CylinderGeometry(0.12, 0.2, 0.28, 20), material), 0.34);
      add(new T.Mesh(new T.TorusGeometry(0.15, 0.04, 10, 20), material), 0.5).rotation.x = Math.PI / 2;
      add(new T.Mesh(new T.SphereGeometry(0.19, 20, 16), material), 0.68);
    } else if (type === TYPE.R) {
      add(new T.Mesh(new T.CylinderGeometry(0.22, 0.27, 0.48, 22), material), 0.44);
      add(new T.Mesh(new T.CylinderGeometry(0.28, 0.24, 0.1, 22), material), 0.72);
      for (let i = 0; i < 6; i++) { const a = i / 6 * Math.PI * 2; const c = new T.Mesh(new T.BoxGeometry(0.08, 0.12, 0.08), material); c.position.set(Math.cos(a) * 0.22, 0.82, Math.sin(a) * 0.22); c.castShadow = true; g.add(c); }
    } else if (type === TYPE.N) {
      // knight: leaning neck + snout + ears (abstract horse)
      const neck = new T.Mesh(new T.CylinderGeometry(0.13, 0.2, 0.55, 18), material); neck.position.set(-0.03, 0.5, 0); neck.rotation.z = 0.28; neck.castShadow = true; g.add(neck);
      const head = new T.Mesh(new T.BoxGeometry(0.42, 0.24, 0.24), material); head.position.set(0.06, 0.78, 0); head.rotation.z = -0.18; head.castShadow = true; g.add(head);
      const snout = new T.Mesh(new T.BoxGeometry(0.24, 0.16, 0.2), material); snout.position.set(0.28, 0.72, 0); snout.castShadow = true; g.add(snout);
      for (const dz of [-0.07, 0.07]) { const ear = new T.Mesh(new T.ConeGeometry(0.05, 0.14, 8), material); ear.position.set(-0.05, 0.94, dz); ear.castShadow = true; g.add(ear); }
    } else if (type === TYPE.B) {
      add(new T.Mesh(new T.CylinderGeometry(0.1, 0.26, 0.5, 22), material), 0.44);
      add(new T.Mesh(new T.SphereGeometry(0.16, 20, 16), material), 0.74);
      add(new T.Mesh(new T.SphereGeometry(0.06, 12, 10), material), 0.92);
    } else if (type === TYPE.Q) {
      add(new T.Mesh(new T.CylinderGeometry(0.12, 0.28, 0.62, 24), material), 0.5);
      add(new T.Mesh(new T.CylinderGeometry(0.26, 0.16, 0.08, 24), material), 0.84);
      for (let i = 0; i < 8; i++) { const a = i / 8 * Math.PI * 2; const p = new T.Mesh(new T.SphereGeometry(0.055, 12, 10), material); p.position.set(Math.cos(a) * 0.2, 0.94, Math.sin(a) * 0.2); p.castShadow = true; g.add(p); }
      add(new T.Mesh(new T.SphereGeometry(0.09, 14, 12), material), 0.98);
    } else { // KING
      add(new T.Mesh(new T.CylinderGeometry(0.13, 0.28, 0.66, 24), material), 0.52);
      add(new T.Mesh(new T.CylinderGeometry(0.27, 0.17, 0.08, 24), material), 0.88);
      const v = new T.Mesh(new T.BoxGeometry(0.07, 0.26, 0.07), material); v.position.y = 1.06; v.castShadow = true; g.add(v);
      const h = new T.Mesh(new T.BoxGeometry(0.07, 0.07, 0.2), material); h.position.y = 1.04; h.castShadow = true; g.add(h);
    }
    return g;
  }

  function BoardView(canvas) {
    this.canvas = canvas;
    this.renderer = new T.WebGLRenderer({ canvas, antialias: true });
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    this.renderer.shadowMap.enabled = true; this.renderer.shadowMap.type = T.PCFSoftShadowMap;
    this.renderer.outputColorSpace = T.SRGBColorSpace;
    this.scene = new T.Scene();
    this.scene.background = new T.Color('#12161d');
    this.scene.fog = new T.Fog('#12161d', 14, 30);
    this.camera = new T.PerspectiveCamera(42, 1, 0.1, 100);
    this.cam = { az: Math.PI / 2, el: 1.0, dist: 11.5, target: new T.Vector3(0, 0, 0) };
    this.flip = false;
    this.whiteMat = mat('#efe4cf', 0.42, 0.05);
    this.blackMat = mat('#33343c', 0.45, 0.15);
    this.pieceMeshes = {};   // square -> mesh
    this.anims = [];
    this._buildLights(); this._buildBoard(); this._buildHighlights();
    this.resize();
  }

  BoardView.prototype._buildLights = function () {
    this.scene.add(new T.AmbientLight('#8794a8', 0.6));
    this.scene.add(new T.HemisphereLight('#dfe8ff', '#20242c', 0.5));
    const key = new T.DirectionalLight('#fff2d8', 1.25);
    key.position.set(4, 11, 6); key.castShadow = true;
    key.shadow.mapSize.set(2048, 2048);
    const s = key.shadow.camera; s.left = -8; s.right = 8; s.top = 8; s.bottom = -8; s.near = 1; s.far = 40; key.shadow.bias = -0.0004;
    this.scene.add(key);
    const fill = new T.DirectionalLight('#9fc0ff', 0.4); fill.position.set(-6, 5, -4); this.scene.add(fill);
  };

  BoardView.prototype._buildBoard = function () {
    const g = new T.Group(); this.boardGroup = g; this.scene.add(g);
    // frame
    const frame = new T.Mesh(new T.BoxGeometry(9.4, 0.5, 9.4), mat('#3a2416', 0.5, 0.1));
    frame.position.y = -0.26; frame.receiveShadow = true; g.add(frame);
    const inlay = new T.Mesh(new T.BoxGeometry(8.6, 0.52, 8.6), mat('#5a3a1e', 0.5));
    inlay.position.y = -0.24; g.add(inlay);
    const light = mat('#e9d3a4', 0.5), dark = mat('#8a5a30', 0.5);
    for (let r = 0; r < 8; r++) for (let f = 0; f < 8; f++) {
      const sqm = new T.Mesh(new T.BoxGeometry(1, 0.12, 1), ((f + r) & 1) ? light.clone() : dark.clone());
      sqm.position.set(f - 3.5, 0, -(r - 3.5)); sqm.receiveShadow = true; sqm.userData.sq = r * 8 + f; g.add(sqm);
    }
    // floor
    const floor = new T.Mesh(new T.CircleGeometry(30, 40), mat('#0d1016', 1));
    floor.rotation.x = -Math.PI / 2; floor.position.y = -0.52; floor.receiveShadow = true; this.scene.add(floor);
  };

  BoardView.prototype._buildHighlights = function () {
    this.selMesh = new T.Mesh(new T.BoxGeometry(1, 0.14, 1), new T.MeshBasicMaterial({ color: '#6cff8f', transparent: true, opacity: 0.45 }));
    this.selMesh.visible = false; this.scene.add(this.selMesh);
    this.lastMesh = [0, 1].map(() => { const m = new T.Mesh(new T.BoxGeometry(1, 0.14, 1), new T.MeshBasicMaterial({ color: '#ffd84a', transparent: true, opacity: 0.32 })); m.visible = false; this.scene.add(m); return m; });
    this.checkMesh = new T.Mesh(new T.BoxGeometry(1, 0.15, 1), new T.MeshBasicMaterial({ color: '#ff4d4d', transparent: true, opacity: 0.5 }));
    this.checkMesh.visible = false; this.scene.add(this.checkMesh);
    this.dots = [];
    for (let i = 0; i < 32; i++) {
      const ring = new T.Mesh(new T.CylinderGeometry(0.17, 0.17, 0.06, 20), new T.MeshBasicMaterial({ color: '#3ad6ff', transparent: true, opacity: 0.85 }));
      ring.visible = false; this.scene.add(ring); this.dots.push(ring);
    }
  };

  BoardView.prototype.worldOf = function (sqi) {
    // fixed world mapping; orientation is handled purely by the camera azimuth
    const f = sqi & 7, r = sqi >> 3;
    return new T.Vector3(f - 3.5, 0.06, -(r - 3.5));
  };

  BoardView.prototype.setPosition = function (board) {
    for (const k in this.pieceMeshes) this.boardGroup.remove(this.pieceMeshes[k]);
    this.pieceMeshes = {};
    for (let i = 0; i < 64; i++) {
      const pc = board[i]; if (!pc) continue;
      this._spawn(i, Math.abs(pc), pc > 0 ? 'w' : 'b');
    }
  };

  BoardView.prototype._spawn = function (sqi, type, color) {
    const g = pieceGeom(type, color === 'w' ? this.whiteMat : this.blackMat);
    const w = this.worldOf(sqi); g.position.copy(w); g.userData = { type, color, sq: sqi };
    this.boardGroup.add(g); this.pieceMeshes[sqi] = g; return g;
  };

  // Animate a move; opts: {captureSq, castle:'K'|'Q', promo:type}. done() after.
  BoardView.prototype.applyMove = function (from, to, color, opts, done) {
    opts = opts || {};
    const mesh = this.pieceMeshes[from];
    if (opts.captureSq != null && this.pieceMeshes[opts.captureSq]) {
      const cap = this.pieceMeshes[opts.captureSq]; delete this.pieceMeshes[opts.captureSq];
      this.anims.push({ mesh: cap, t: 0, dur: 0.22, capture: true });
    }
    if (mesh) {
      delete this.pieceMeshes[from];
      this.pieceMeshes[to] = mesh; mesh.userData.sq = to;
      this.anims.push({ mesh, from: mesh.position.clone(), to: this.worldOf(to), t: 0, dur: 0.26, promo: opts.promo, color, done });
    } else if (done) done();
    // castling rook
    if (opts.castle) {
      const map = this.flip ? null : 0;
      let rf, rt;
      if (color === 'w') { if (opts.castle === 'K') { rf = 7; rt = 5; } else { rf = 0; rt = 3; } }
      else { if (opts.castle === 'K') { rf = 63; rt = 61; } else { rf = 56; rt = 59; } }
      const rook = this.pieceMeshes[rf];
      if (rook) { delete this.pieceMeshes[rf]; this.pieceMeshes[rt] = rook; rook.userData.sq = rt; this.anims.push({ mesh: rook, from: rook.position.clone(), to: this.worldOf(rt), t: 0, dur: 0.26 }); }
    }
  };

  BoardView.prototype.highlight = function (sel, targets, last, checkSq) {
    if (sel != null) { this.selMesh.visible = true; const w = this.worldOf(sel); this.selMesh.position.set(w.x, 0.02, w.z); }
    else this.selMesh.visible = false;
    for (let i = 0; i < this.dots.length; i++) {
      if (targets && i < targets.length) { const w = this.worldOf(targets[i].to); this.dots[i].position.set(w.x, 0.08, w.z); this.dots[i].visible = true; this.dots[i]._cap = targets[i].cap; this.dots[i].material.color.set(targets[i].cap ? '#ff7a4d' : '#3ad6ff'); }
      else this.dots[i].visible = false;
    }
    for (let i = 0; i < 2; i++) { if (last && last[i] != null) { const w = this.worldOf(last[i]); this.lastMesh[i].position.set(w.x, 0.015, w.z); this.lastMesh[i].visible = true; } else this.lastMesh[i].visible = false; }
    if (checkSq != null) { const w = this.worldOf(checkSq); this.checkMesh.position.set(w.x, 0.02, w.z); this.checkMesh.visible = true; } else this.checkMesh.visible = false;
  };

  BoardView.prototype.pick = function (clientX, clientY) {
    const rect = this.canvas.getBoundingClientRect();
    const ndc = new T.Vector2(((clientX - rect.left) / rect.width) * 2 - 1, -((clientY - rect.top) / rect.height) * 2 + 1);
    const ray = new T.Raycaster(); ray.setFromCamera(ndc, this.camera);
    // Raycast the actual pieces + squares (so tapping a tall far piece selects
    // its own square, not a nearer one under the cursor).
    const hits = ray.intersectObjects(this.boardGroup.children, true);
    for (const h of hits) {
      let o = h.object;
      while (o && o.userData.sq === undefined && o !== this.boardGroup) o = o.parent;
      if (o && o.userData.sq !== undefined) return o.userData.sq;
    }
    return -1;
  };

  BoardView.prototype.updateCamera = function (dt) {
    const el = Math.max(0.35, Math.min(1.45, this.cam.el)), d = this.cam.dist;
    const cx = Math.cos(this.cam.az) * Math.cos(el) * d, cy = Math.sin(el) * d, cz = Math.sin(this.cam.az) * Math.cos(el) * d;
    this.camera.position.lerp(new T.Vector3(cx, cy, cz), Math.min(1, dt * 10));
    this.camera.lookAt(this.cam.target);
  };

  BoardView.prototype.update = function (dt) {
    for (let i = this.anims.length - 1; i >= 0; i--) {
      const a = this.anims[i]; a.t += dt / a.dur;
      if (a.capture) { const s = Math.max(0, 1 - a.t); a.mesh.scale.setScalar(s); a.mesh.position.y = 0.06 + a.t * 0.4; if (a.t >= 1) { this.boardGroup.remove(a.mesh); this.anims.splice(i, 1); } continue; }
      const k = a.t >= 1 ? 1 : (a.t < 0.5 ? 2 * a.t * a.t : 1 - Math.pow(-2 * a.t + 2, 2) / 2);
      a.mesh.position.lerpVectors(a.from, a.to, k);
      a.mesh.position.y = 0.06 + Math.sin(Math.min(1, a.t) * Math.PI) * 0.5; // little hop
      if (a.t >= 1) {
        a.mesh.position.copy(a.to);
        if (a.promo) { const c = a.mesh.userData.color; this.boardGroup.remove(a.mesh); const ns = a.mesh.userData.sq; const m = pieceGeom(a.promo, c === 'w' ? this.whiteMat : this.blackMat); m.position.copy(a.to); m.userData = { type: a.promo, color: c, sq: ns }; this.boardGroup.add(m); this.pieceMeshes[ns] = m; }
        const cb = a.done; this.anims.splice(i, 1); if (cb) cb();
      }
    }
    this.updateCamera(dt);
  };

  BoardView.prototype.animating = function () { return this.anims.length > 0; };
  BoardView.prototype.resize = function () { const w = window.innerWidth, h = window.innerHeight; this.renderer.setSize(w, h, false); this.camera.aspect = w / h; this.camera.updateProjectionMatrix(); };
  BoardView.prototype.render = function () { this.renderer.render(this.scene, this.camera); };

  global.Chess = global.Chess || {};
  global.Chess.BoardView = BoardView;

})(window);
