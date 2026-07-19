/* ============================================================================
 * Galley Rush — the steward (stylized cartoon crew, Cooking-Madness style)
 * ----------------------------------------------------------------------------
 * A friendly, big-headed cartoon crew member in galley whites + apron, facing
 * the camera behind the counter. Arms are rigged (shoulder + elbow pivots) so
 * the game can play scrub / rack / run animations. Exposes a hand anchor the
 * game parents the in-hand plate to.
 * ==========================================================================*/
(function (global) {
  'use strict';
  const T = global.THREE;

  function mat(color, rough, metal) {
    return new T.MeshStandardMaterial({ color, roughness: rough == null ? 0.7 : rough, metalness: metal || 0 });
  }

  function buildSteward(opts) {
    opts = opts || {};
    const skin = opts.skin || '#e8b48c';
    const shirt = '#f6f8fa';
    const apron = opts.apron || '#18a0a8';
    const trouser = '#2b3a52';
    const hair = opts.hair || '#3a2418';
    const cap = opts.cap || '#ffffff';

    const g = new T.Group();
    const parts = {};

    // ---- legs (short, cartoon) ----
    const legMat = mat(trouser, 0.8);
    const shoeMat = mat('#20242b', 0.6);
    for (const sx of [-1, 1]) {
      const leg = new T.Mesh(new T.CylinderGeometry(0.1, 0.11, 0.5, 12), legMat);
      leg.position.set(sx * 0.13, 0.32, 0); leg.castShadow = true; g.add(leg);
      const shoe = new T.Mesh(new T.BoxGeometry(0.16, 0.1, 0.28), shoeMat);
      shoe.position.set(sx * 0.13, 0.05, 0.05); shoe.castShadow = true; g.add(shoe);
    }

    // ---- torso + apron ----
    const torso = new T.Mesh(new T.CapsuleGeometry(0.26, 0.34, 6, 14), mat(shirt, 0.75));
    torso.position.y = 0.86; torso.scale.set(1, 1, 0.8); torso.castShadow = true; g.add(torso);
    parts.torso = torso;
    const apronMesh = new T.Mesh(new T.BoxGeometry(0.42, 0.5, 0.06), mat(apron, 0.8));
    apronMesh.position.set(0, 0.82, 0.19); g.add(apronMesh);
    // apron neck strap
    const strap = new T.Mesh(new T.TorusGeometry(0.16, 0.02, 8, 20, Math.PI), mat(apron, 0.8));
    strap.position.set(0, 1.02, 0.16); strap.rotation.x = Math.PI; g.add(strap);
    // collar
    const collar = new T.Mesh(new T.CylinderGeometry(0.16, 0.18, 0.1, 14), mat(shirt, 0.7));
    collar.position.y = 1.06; g.add(collar);

    // ---- head (big, friendly) ----
    const head = new T.Group(); head.position.y = 1.28; g.add(head); parts.head = head;
    const skull = new T.Mesh(new T.SphereGeometry(0.26, 24, 20), mat(skin, 0.6));
    skull.scale.set(1, 1.05, 0.98); skull.castShadow = true; head.add(skull);
    // ears
    for (const sx of [-1, 1]) { const ear = new T.Mesh(new T.SphereGeometry(0.05, 10, 8), mat(skin, 0.6)); ear.position.set(sx * 0.25, -0.02, 0); head.add(ear); }
    // hair + galley cap
    const hairMesh = new T.Mesh(new T.SphereGeometry(0.265, 20, 16, 0, Math.PI * 2, 0, Math.PI * 0.55), mat(hair, 0.8));
    hairMesh.position.y = 0.02; head.add(hairMesh);
    const capMesh = new T.Mesh(new T.CylinderGeometry(0.2, 0.22, 0.12, 18), mat(cap, 0.7));
    capMesh.position.y = 0.24; head.add(capMesh);
    const capTop = new T.Mesh(new T.SphereGeometry(0.2, 16, 10, 0, Math.PI * 2, 0, Math.PI / 2), mat(cap, 0.7));
    capTop.position.y = 0.3; head.add(capTop);

    // face (on +Z)
    const eyeWhite = mat('#ffffff', 0.4);
    const pupilMat = mat('#20140c', 0.3);
    for (const sx of [-1, 1]) {
      const ew = new T.Mesh(new T.SphereGeometry(0.055, 14, 12), eyeWhite);
      ew.position.set(sx * 0.1, 0.02, 0.225); ew.scale.set(1, 1.2, 0.6); head.add(ew);
      const pu = new T.Mesh(new T.SphereGeometry(0.03, 12, 10), pupilMat);
      pu.position.set(sx * 0.1, 0.01, 0.265); head.add(pu);
      const brow = new T.Mesh(new T.BoxGeometry(0.09, 0.02, 0.02), mat(hair, 0.8));
      brow.position.set(sx * 0.1, 0.11, 0.25); brow.rotation.z = sx * 0.15; head.add(brow);
    }
    // smile
    const smile = new T.Mesh(new T.TorusGeometry(0.08, 0.017, 8, 16, Math.PI), mat('#a83a2a', 0.5));
    smile.position.set(0, -0.09, 0.235); smile.rotation.x = Math.PI * 0.06; smile.rotation.z = Math.PI; head.add(smile);
    // nose
    const nose = new T.Mesh(new T.SphereGeometry(0.035, 10, 8), mat(skin, 0.6));
    nose.position.set(0, -0.02, 0.27); head.add(nose);

    // ---- arms (shoulder + elbow pivots), reaching forward toward counter ----
    function arm(sx) {
      const shoulder = new T.Group();
      shoulder.position.set(sx * 0.3, 1.0, 0);
      const upper = new T.Mesh(new T.CapsuleGeometry(0.075, 0.2, 5, 10), mat(shirt, 0.75));
      upper.position.y = -0.13; shoulder.add(upper);
      const elbow = new T.Group(); elbow.position.y = -0.26; shoulder.add(elbow);
      const fore = new T.Mesh(new T.CapsuleGeometry(0.06, 0.18, 5, 10), mat(skin, 0.6)); // rolled sleeves
      fore.position.y = -0.12; elbow.add(fore);
      const hand = new T.Mesh(new T.SphereGeometry(0.075, 12, 10), mat(skin, 0.6));
      hand.position.y = -0.24; elbow.add(hand);
      const anchor = new T.Group(); anchor.position.y = -0.28; elbow.add(anchor);
      g.add(shoulder);
      return { shoulder, elbow, anchor };
    }
    const armL = arm(-1), armR = arm(1);
    parts.armL = armL; parts.armR = armR;
    parts.handAnchor = armR.anchor; // plate lives in the right hand

    // rest pose (arms down along the body)
    function setRot(o, x, z) { o.rotation.x = x; o.rotation.z = z || 0; }
    setRot(armL.shoulder, 0.15, 0.25); setRot(armL.elbow, 0.2);
    setRot(armR.shoulder, 0.15, -0.25); setRot(armR.elbow, 0.2);

    // ---- animation state machine ----
    const cur = { lsx: 0.15, lsz: 0.25, lel: 0.2, rsx: 0.15, rsz: -0.25, rel: 0.2, bob: 0, headY: 0 };
    const steward = { group: g, parts, _t: 0 };

    steward.setState = function (state, dt) {
      this._t += dt;
      const t = this._t;
      // pose targets per state (shoulder x lifts arms forward; elbow bends)
      let tgt;
      if (state === 'scrub') {
        const s = Math.sin(t * 12) * 0.28;
        tgt = { lsx: -1.15, lsz: 0.15, lel: 1.0 + s, rsx: -1.15, rsz: -0.15, rel: 1.0 - s, bob: 0.02, headY: -0.12 };
      } else if (state === 'rack') {
        tgt = { lsx: 0.15, lsz: 0.25, lel: 0.2, rsx: -1.25, rsz: -0.05, rel: 0.5, bob: 0, headY: -0.05 };
      } else if (state === 'run') {
        const s = Math.sin(t * 6) * 0.15;
        tgt = { lsx: 0.15, lsz: 0.25, lel: 0.2, rsx: -1.4 + s, rsz: -0.1, rel: 0.35, bob: 0, headY: -0.05 };
      } else if (state === 'carry') {
        tgt = { lsx: 0.15, lsz: 0.25, lel: 0.2, rsx: -1.0, rsz: -0.15, rel: 1.3, bob: 0, headY: -0.05 };
      } else { // idle
        const b = Math.sin(t * 2) * 0.03;
        tgt = { lsx: 0.15 + b, lsz: 0.25, lel: 0.2, rsx: 0.15 - b, rsz: -0.25, rel: 0.2, bob: b * 0.3, headY: Math.sin(t * 1.3) * 0.06 };
      }
      const k = Math.min(1, dt * 10);
      for (const key in tgt) cur[key] += (tgt[key] - cur[key]) * k;
      setRot(armL.shoulder, cur.lsx, cur.lsz); armL.elbow.rotation.x = cur.lel;
      setRot(armR.shoulder, cur.rsx, cur.rsz); armR.elbow.rotation.x = cur.rel;
      g.position.y = cur.bob;
      head.rotation.y = cur.headY;
    };

    return steward;
  }

  global.Galley = global.Galley || {};
  global.Galley.buildSteward = buildSteward;

})(window);
