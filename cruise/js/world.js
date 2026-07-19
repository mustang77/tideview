/* ============================================================================
 * Deck & Horizon — world
 * ----------------------------------------------------------------------------
 * Builds the whole scene: the cruise ship (hull, wood deck, superstructure,
 * funnels, railings, lifeboats, pool, loungers, props), the animated ocean
 * (custom water shader), the sky, and lighting. Also exposes the data the
 * player controller needs: walkable-deck test, obstacle colliders, per-point
 * floor height (so you can walk down into the pool), and interactables.
 * ==========================================================================*/
(function (global) {
  'use strict';
  const T = global.THREE;

  // ---- shared canvas textures --------------------------------------------
  function deckTexture() {
    const s = 512, cv = document.createElement('canvas'); cv.width = cv.height = s;
    const g = cv.getContext('2d');
    g.fillStyle = '#b8895a'; g.fillRect(0, 0, s, s);
    for (let y = 0; y < s; y += 26) {
      const shade = 150 + ((y / 26) % 2) * 18;
      g.fillStyle = `rgb(${shade + 40},${shade - 5},${shade - 60})`;
      g.fillRect(0, y, s, 24);
      g.strokeStyle = 'rgba(60,35,15,0.5)'; g.lineWidth = 2;
      g.beginPath(); g.moveTo(0, y); g.lineTo(s, y); g.stroke();
    }
    // plank end seams
    g.strokeStyle = 'rgba(60,35,15,0.35)';
    for (let x = 0; x < s; x += 128) { g.beginPath(); g.moveTo(x, 0); g.lineTo(x, s); g.stroke(); }
    const tex = new T.CanvasTexture(cv);
    tex.wrapS = tex.wrapT = T.RepeatWrapping;
    tex.anisotropy = 8;
    return tex;
  }
  function hullTexture(base, windows) {
    const w = 512, h = 256, cv = document.createElement('canvas'); cv.width = w; cv.height = h;
    const g = cv.getContext('2d');
    g.fillStyle = base; g.fillRect(0, 0, w, h);
    if (windows) {
      for (let ry = 40; ry < h - 40; ry += 60) {
        for (let x = 24; x < w - 24; x += 44) {
          g.fillStyle = '#10202e'; g.fillRect(x, ry, 30, 34);
          g.fillStyle = 'rgba(150,200,240,0.25)'; g.fillRect(x + 3, ry + 3, 24, 12);
        }
      }
    }
    const tex = new T.CanvasTexture(cv);
    tex.wrapS = tex.wrapT = T.RepeatWrapping;
    return tex;
  }

  // ---- ocean water shader -------------------------------------------------
  function makeOcean() {
    // Segment count kept modest for mobile GPUs (waves still read well).
    const geo = new T.PlaneGeometry(2000, 2000, 120, 120);
    geo.rotateX(-Math.PI / 2);
    const uniforms = {
      uTime: { value: 0 },
      uSunDir: { value: new T.Vector3(0.5, 0.7, 0.3).normalize() },
      uCamPos: { value: new T.Vector3() },
      uDeep: { value: new T.Color('#12466e') },
      uShallow: { value: new T.Color('#2f88b8') },
      uSky: { value: new T.Color('#bfe0f5') },
    };
    const mat = new T.ShaderMaterial({
      uniforms,
      vertexShader: `
        uniform float uTime;
        varying vec3 vWorld; varying vec3 vNormal;
        // three directional gerstner-ish sine waves
        float wave(vec2 p, vec2 d, float w, float sp, float a, out vec2 grad){
          float ph = dot(d,p)*w + uTime*sp;
          grad = d*w*a*cos(ph);
          return a*sin(ph);
        }
        void main(){
          vec3 pos = position;
          vec2 p = pos.xz;
          vec2 g1,g2,g3;
          float h = 0.0;
          h += wave(p, normalize(vec2(1.0,0.3)), 0.06, 0.9, 0.55, g1);
          h += wave(p, normalize(vec2(-0.4,1.0)), 0.10, 1.3, 0.30, g2);
          h += wave(p, normalize(vec2(0.7,-0.6)), 0.20, 1.9, 0.14, g3);
          pos.y += h;
          vec2 grad = g1+g2+g3;
          vNormal = normalize(vec3(-grad.x, 1.0, -grad.y));
          vec4 wp = modelMatrix * vec4(pos,1.0);
          vWorld = wp.xyz;
          gl_Position = projectionMatrix * viewMatrix * wp;
        }`,
      fragmentShader: `
        uniform vec3 uSunDir; uniform vec3 uCamPos;
        uniform vec3 uDeep; uniform vec3 uShallow; uniform vec3 uSky;
        varying vec3 vWorld; varying vec3 vNormal;
        void main(){
          vec3 N = normalize(vNormal);
          vec3 V = normalize(uCamPos - vWorld);
          vec3 L = normalize(uSunDir);
          float fres = pow(1.0 - max(dot(N,V),0.0), 3.0);
          float diff = max(dot(N,L),0.0);
          vec3 R = reflect(-L,N);
          float spec = pow(max(dot(R,V),0.0), 80.0);
          vec3 base = mix(uDeep, uShallow, diff*0.6);
          vec3 col = mix(base, uSky, clamp(fres,0.0,0.7));
          col += vec3(1.0,0.95,0.8) * spec * 1.4;
          // distance fade to horizon sky
          float d = length(uCamPos.xz - vWorld.xz);
          col = mix(col, uSky, clamp((d-300.0)/700.0, 0.0, 0.85));
          gl_FragColor = vec4(col, 1.0);
        }`,
    });
    const mesh = new T.Mesh(geo, mat);
    mesh.position.y = -0.6;
    return { mesh, uniforms };
  }

  function buildWorld(scene, renderer) {
    const colliders = [];   // {type:'box',minX,maxX,minZ,maxZ} | {type:'circle',x,z,r}
    const interactables = [];
    const animated = [];    // {update(dt,t)}

    // ---- sky -------------------------------------------------------------
    scene.background = new T.Color('#8fc4e8');
    scene.fog = new T.Fog('#bfe0f5', 200, 1200);
    const skyGeo = new T.SphereGeometry(1400, 32, 16);
    const skyMat = new T.ShaderMaterial({
      side: T.BackSide,
      uniforms: { top: { value: new T.Color('#2f7fc4') }, bot: { value: new T.Color('#cfe8f7') } },
      vertexShader: `varying float h; void main(){ h = normalize(position).y; gl_Position = projectionMatrix*modelViewMatrix*vec4(position,1.0);} `,
      fragmentShader: `varying float h; uniform vec3 top; uniform vec3 bot; void main(){ gl_FragColor = vec4(mix(bot, top, clamp(h*1.1,0.0,1.0)),1.0);} `,
    });
    scene.add(new T.Mesh(skyGeo, skyMat));

    // sun + fill
    const sunDir = new T.Vector3(0.5, 0.72, 0.35).normalize();
    const sun = new T.DirectionalLight('#fff3d8', 1.35);
    sun.position.copy(sunDir).multiplyScalar(120);
    sun.castShadow = true;
    sun.shadow.mapSize.set(1024, 1024);   // lighter shadow pass for mobile
    const sc = sun.shadow.camera;
    sc.left = -60; sc.right = 60; sc.top = 60; sc.bottom = -60; sc.near = 10; sc.far = 320;
    sun.shadow.bias = -0.0004;
    scene.add(sun);
    scene.add(new T.HemisphereLight('#cfeaff', '#20344a', 0.7));
    scene.add(new T.AmbientLight('#ffffff', 0.25));

    // billboard sun disc
    const sunSprite = new T.Sprite(new T.SpriteMaterial({ color: '#fff6da', transparent: true, opacity: 0.9 }));
    sunSprite.scale.set(60, 60, 1);
    sunSprite.position.copy(sunDir).multiplyScalar(1000);
    scene.add(sunSprite);

    // ---- ocean -----------------------------------------------------------
    const ocean = makeOcean();
    ocean.uniforms.uSunDir.value.copy(sunDir);
    scene.add(ocean.mesh);
    animated.push({ update: (dt, t, cam) => {
      ocean.uniforms.uTime.value = t;
      ocean.uniforms.uCamPos.value.copy(cam.position);
      ocean.mesh.position.x = cam.position.x;   // keep ocean centred on player
      ocean.mesh.position.z = cam.position.z;
    }});

    // ---- ship footprint (top-down outline) ------------------------------
    // pointed bow at +X, square stern at -X
    const FP = [
      [-30, -10], [24, -10], [31, 0], [24, 10], [-30, 10],
    ];
    // inset walkable polygon (keep the player off the rail)
    const WALK = [
      [-29, -9], [23.4, -9], [29.4, 0], [23.4, 9], [-29, 9],
    ];

    const ship = new T.Group();
    scene.add(ship);

    // hull (extrude footprint downward)
    const shape = new T.Shape();
    shape.moveTo(FP[0][0], FP[0][1]);
    for (let i = 1; i < FP.length; i++) shape.lineTo(FP[i][0], FP[i][1]);
    shape.lineTo(FP[0][0], FP[0][1]);
    const hullGeo = new T.ExtrudeGeometry(shape, { depth: 6, bevelEnabled: false });
    hullGeo.rotateX(Math.PI / 2);          // extrude +Z -> +Y, flip so it goes down
    hullGeo.translate(0, 0, 0);
    const hull = new T.Mesh(hullGeo, new T.MeshStandardMaterial({ color: '#1b2b3a', roughness: 0.7, metalness: 0.1 }));
    hull.castShadow = true; hull.receiveShadow = true;
    ship.add(hull);
    // white boot line + red below
    const stripe = new T.Mesh(hullGeo.clone(), new T.MeshStandardMaterial({ color: '#8a1f1f', roughness: 0.8 }));
    stripe.scale.set(1.006, 1, 1.006); stripe.position.y = -1.2;
    ship.add(stripe);

    // deck surface
    const deckShape = new T.Shape();
    deckShape.moveTo(FP[0][0], FP[0][1]);
    for (let i = 1; i < FP.length; i++) deckShape.lineTo(FP[i][0], FP[i][1]);
    const deckGeo = new T.ShapeGeometry(deckShape);
    deckGeo.rotateX(-Math.PI / 2);
    const dtex = deckTexture(); dtex.repeat.set(10, 4);
    const deck = new T.Mesh(deckGeo, new T.MeshStandardMaterial({ map: dtex, color: '#c99', roughness: 0.9 }));
    deck.position.y = 0.02; deck.receiveShadow = true;
    ship.add(deck);

    // ---- superstructure (white blocks amidships) -------------------------
    const white = new T.MeshStandardMaterial({ map: hullTexture('#eef2f5', true), color: '#f4f7fa', roughness: 0.6 });
    const plain = new T.MeshStandardMaterial({ color: '#e8edf1', roughness: 0.6 });
    function block(x0, x1, z0, z1, y0, y1, mat) {
      const m = new T.Mesh(new T.BoxGeometry(x1 - x0, y1 - y0, z1 - z0), mat || white);
      m.position.set((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2);
      m.castShadow = true; m.receiveShadow = true;
      ship.add(m);
      colliders.push({ type: 'box', minX: x0, maxX: x1, minZ: z0, maxZ: z1 });
      return m;
    }
    // main house (leave walkways along the sides at |z|>7)
    block(-24, 2, -7, 7, 0, 5.5);
    block(-20, -2, -6.5, 6.5, 5.5, 9);      // second tier
    block(-14, -6, -4, 4, 9, 11.5, plain);  // bridge/observation
    // bridge windows front
    const bwin = new T.Mesh(new T.BoxGeometry(0.3, 1.4, 7), new T.MeshStandardMaterial({ color: '#16323f', metalness: 0.4, roughness: 0.2 }));
    bwin.position.set(-6.05, 10.2, 0); ship.add(bwin);

    // ---- funnels ---------------------------------------------------------
    function funnel(x) {
      const g = new T.Group();
      const body = new T.Mesh(new T.CylinderGeometry(2.1, 2.4, 7, 24), new T.MeshStandardMaterial({ color: '#c0392b', roughness: 0.5 }));
      body.position.y = 9 + 3.5; body.castShadow = true;
      const cap = new T.Mesh(new T.CylinderGeometry(2.2, 2.2, 1.2, 24), new T.MeshStandardMaterial({ color: '#1c1c1c' }));
      cap.position.y = 9 + 7;
      g.add(body); g.add(cap); g.position.set(x, 0, 0); ship.add(g);
      colliders.push({ type: 'circle', x, z: 0, r: 2.6 });
    }
    funnel(-16); funnel(-9);

    // ---- railings around the deck ---------------------------------------
    const railMat = new T.MeshStandardMaterial({ color: '#d9dde1', metalness: 0.5, roughness: 0.4 });
    function railParams(a, b) {
      const dx = b[0] - a[0], dz = b[1] - a[1];
      const len = Math.hypot(dx, dz);
      const ang = Math.atan2(dz, dx);
      const cx = (a[0] + b[0]) / 2, cz = (a[1] + b[1]) / 2;
      for (const hy of [0.55, 1.05]) {
        const bar = new T.Mesh(new T.BoxGeometry(len, 0.05, 0.05), railMat);
        bar.position.set(cx, hy, cz); bar.rotation.y = -ang; ship.add(bar);
      }
      const n = Math.max(2, Math.round(len / 2));
      for (let i = 0; i <= n; i++) {
        const px = a[0] + dx * i / n, pz = a[1] + dz * i / n;
        const post = new T.Mesh(new T.BoxGeometry(0.06, 1.1, 0.06), railMat);
        post.position.set(px, 0.55, pz); ship.add(post);
      }
    }
    for (let i = 0; i < FP.length; i++) railParams(FP[i], FP[(i + 1) % FP.length]);

    // ---- lifeboats along the sides --------------------------------------
    const boatMat = new T.MeshStandardMaterial({ color: '#e67e22', roughness: 0.5 });
    for (const z of [-7.6, 7.6]) {
      for (let x = -22; x <= -4; x += 6) {
        const b = new T.Mesh(new T.CapsuleGeometry(0.9, 3, 4, 8), boatMat);
        b.rotation.z = Math.PI / 2; b.rotation.y = Math.PI / 2;
        b.position.set(x, 6.2, z); b.scale.set(1, 1, 0.6); b.castShadow = true;
        ship.add(b);
      }
    }

    // ---- swimming pool (walk down into it) ------------------------------
    const POOL = { x0: 8, x1: 16, z0: -4, z1: 4, floor: -1.4, water: -0.15 };
    // pool shell (recessed box, open top)
    const shellMat = new T.MeshStandardMaterial({ color: '#eaf3f8', roughness: 0.5 });
    const poolFloor = new T.Mesh(new T.BoxGeometry(POOL.x1 - POOL.x0, 0.1, POOL.z1 - POOL.z0), new T.MeshStandardMaterial({ color: '#0d6ea0' }));
    poolFloor.position.set((POOL.x0 + POOL.x1) / 2, POOL.floor, (POOL.z0 + POOL.z1) / 2);
    ship.add(poolFloor);
    // walls of the pool basin
    const basinMat = new T.MeshStandardMaterial({ color: '#1488be' });
    const basin = new T.Mesh(new T.BoxGeometry(POOL.x1 - POOL.x0, 1.5, POOL.z1 - POOL.z0), basinMat);
    basin.position.set((POOL.x0 + POOL.x1) / 2, POOL.floor + 0.75, (POOL.z0 + POOL.z1) / 2);
    basin.material.side = T.BackSide; ship.add(basin);
    // pool water surface (translucent)
    const poolWater = new T.Mesh(
      new T.PlaneGeometry(POOL.x1 - POOL.x0 - 0.2, POOL.z1 - POOL.z0 - 0.2),
      new T.MeshStandardMaterial({ color: '#0b86c6', transparent: true, opacity: 0.9, roughness: 0.3, metalness: 0.0 })
    );
    poolWater.rotateX(-Math.PI / 2);
    poolWater.position.set((POOL.x0 + POOL.x1) / 2, POOL.water, (POOL.z0 + POOL.z1) / 2);
    ship.add(poolWater);
    animated.push({ update: (dt, t) => { poolWater.position.y = POOL.water + Math.sin(t * 2) * 0.02; } });
    // tiled rim
    const rim = new T.Mesh(new T.BoxGeometry(POOL.x1 - POOL.x0 + 0.6, 0.12, POOL.z1 - POOL.z0 + 0.6), shellMat);
    rim.position.set((POOL.x0 + POOL.x1) / 2, 0.06, (POOL.z0 + POOL.z1) / 2); ship.add(rim);

    // ---- loungers around the pool ---------------------------------------
    const loungeMat = new T.MeshStandardMaterial({ color: '#f4f6f8', roughness: 0.6 });
    const cushionMat = new T.MeshStandardMaterial({ color: '#3d9be0', roughness: 0.8 });
    function lounger(x, z, rot) {
      const g = new T.Group();
      const seat = new T.Mesh(new T.BoxGeometry(2.0, 0.12, 0.7), cushionMat); seat.position.y = 0.35;
      const back = new T.Mesh(new T.BoxGeometry(0.8, 0.12, 0.7), cushionMat); back.position.set(-0.85, 0.65, 0); back.rotation.z = 0.9;
      const legs = new T.Mesh(new T.BoxGeometry(2.0, 0.35, 0.7), loungeMat); legs.position.y = 0.17;
      g.add(legs); g.add(seat); g.add(back);
      g.position.set(x, 0, z); g.rotation.y = rot; g.traverse(o => o.castShadow = true);
      ship.add(g);
      colliders.push({ type: 'box', minX: x - 1.2, maxX: x + 1.2, minZ: z - 0.5, maxZ: z + 0.5 });
    }
    for (const z of [-6, 6]) for (const x of [6, 10, 14, 18]) lounger(x, z, z < 0 ? 0.2 : -0.2);

    // ---- foremast + flag, bell, telescope (interactables) ---------------
    const mast = new T.Mesh(new T.CylinderGeometry(0.12, 0.16, 9, 12), new T.MeshStandardMaterial({ color: '#cfd3d6', metalness: 0.5 }));
    mast.position.set(21, 4.5, 0); mast.castShadow = true; ship.add(mast);
    const flag = new T.Mesh(new T.PlaneGeometry(2.2, 1.3), new T.MeshStandardMaterial({ color: '#c0392b', side: T.DoubleSide }));
    flag.position.set(22.2, 8.2, 0); ship.add(flag);
    animated.push({ update: (dt, t) => { flag.rotation.y = Math.sin(t * 3) * 0.25; flag.position.z = Math.sin(t * 3) * 0.15; } });

    // ship's bell near the bridge
    const bellGroup = new T.Group();
    const bell = new T.Mesh(new T.CylinderGeometry(0.32, 0.5, 0.7, 16, 1, true), new T.MeshStandardMaterial({ color: '#d4af37', metalness: 0.8, roughness: 0.3, side: T.DoubleSide }));
    bell.position.y = 2.0; bellGroup.add(bell);
    const bracket = new T.Mesh(new T.BoxGeometry(0.1, 1.4, 0.1), railMat); bracket.position.y = 1.7; bellGroup.add(bracket);
    bellGroup.position.set(1.5, 0, 5.5); ship.add(bellGroup);
    let bellSwing = 0;
    animated.push({ update: (dt) => { if (bellSwing > 0) { bellSwing -= dt; bell.rotation.x = Math.sin(bellSwing * 22) * 0.3 * Math.max(0, bellSwing); } } });
    interactables.push({ name: 'bell', x: 1.5, z: 5.5, r: 2.2, prompt: '🔔 Ring the ship\'s bell',
      action: (ctx) => { bellSwing = 1.2; if (ctx.audio) ctx.audio.bell(); ctx.toast('*Ding ding!*'); } });

    // telescope at the bow
    const telG = new T.Group();
    const post = new T.Mesh(new T.CylinderGeometry(0.08, 0.1, 1.2, 12), railMat); post.position.y = 0.6; telG.add(post);
    const scope = new T.Mesh(new T.CylinderGeometry(0.12, 0.16, 1.0, 12), new T.MeshStandardMaterial({ color: '#2b2b2b', metalness: 0.6 }));
    scope.rotation.z = Math.PI / 2; scope.position.set(0.2, 1.25, 0); scope.rotation.y = -0.3; telG.add(scope);
    telG.position.set(26, 0, 0); telG.traverse(o => o.castShadow = true); ship.add(telG);
    interactables.push({ name: 'telescope', x: 26, z: 0, r: 2.2, prompt: '🔭 Look through the telescope', toggle: true,
      action: (ctx) => ctx.toggleZoom() });

    // a shaded bar counter
    block(-2, 2, -6.6, -3, 0, 1.4, new T.MeshStandardMaterial({ color: '#6b4326', roughness: 0.7 }));

    // ---- helpers exposed to the player ----------------------------------
    function pointInPoly(x, z, poly) {
      let inside = false;
      for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) {
        const xi = poly[i][0], zi = poly[i][1], xj = poly[j][0], zj = poly[j][1];
        if (((zi > z) !== (zj > z)) && (x < (xj - xi) * (z - zi) / (zj - zi) + xi)) inside = !inside;
      }
      return inside;
    }
    function insideDeck(x, z) { return pointInPoly(x, z, WALK); }
    function inCollider(x, z, r) {
      for (const c of colliders) {
        if (c.type === 'box') {
          const nx = Math.max(c.minX, Math.min(x, c.maxX));
          const nz = Math.max(c.minZ, Math.min(z, c.maxZ));
          if ((x - nx) * (x - nx) + (z - nz) * (z - nz) < r * r) return true;
        } else if (c.type === 'circle') {
          if ((x - c.x) * (x - c.x) + (z - c.z) * (z - c.z) < (c.r + r) * (c.r + r)) return true;
        }
      }
      return false;
    }
    function walkable(x, z, r) { return insideDeck(x, z) && !inCollider(x, z, r); }
    function floorHeightAt(x, z) {
      if (x > POOL.x0 && x < POOL.x1 && z > POOL.z0 && z < POOL.z1) return POOL.floor;
      return 0;
    }

    return {
      colliders, interactables, animated, sun, ocean, POOL,
      walkable, insideDeck, floorHeightAt,
      waterLevel: POOL.water,
      update(dt, t, cam) { for (const a of animated) a.update(dt, t, cam); },
    };
  }

  global.Cruise = global.Cruise || {};
  global.Cruise.buildWorld = buildWorld;

})(window);
