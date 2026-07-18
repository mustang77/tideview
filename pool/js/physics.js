/* ============================================================================
 * Break & Run — Billiard physics
 * ----------------------------------------------------------------------------
 * A deterministic, sub-stepped 2D simulation. Balls live on the table plane
 * (x = long axis, z = short axis; y is "up" only for rendering). Everything a
 * real pool game needs — friction, ball/ball & ball/cushion restitution,
 * pocket capture, and enough spin (English) to feel alive — lives here.
 * Rendering and rules never touch these numbers directly; they read state.
 * ==========================================================================*/
(function (global) {
  'use strict';

  // ---- Dimensions (metre-ish scene units, real 7ft-table proportions) ------
  const R = 0.0286;            // ball radius
  const PLAY_HALF_X = 1.12;    // half play-field length (long rails at ±X)
  const PLAY_HALF_Z = 0.56;    // half play-field width  (short? see below)
  // NB: long rails run along X (top/bottom in Z), short rails at ±X.

  const CONFIG = {
    R,
    BALL_MASS: 0.17,
    PLAY_HALF_X,
    PLAY_HALF_Z,
    HEAD_SPOT_X: -0.56,        // cue break spot
    FOOT_SPOT_X: 0.56,         // rack apex
    // Friction: cloth rolling resistance (per second, velocity-proportional)
    ROLL_FRICTION: 0.82,
    // Extra drag so very slow balls settle promptly
    STOP_SPEED: 0.006,
    // Restitution
    BALL_RESTITUTION: 0.94,
    CUSHION_RESTITUTION: 0.80,
    CUSHION_FRICTION: 0.92,    // tangential damping on cushion hits
    // Spin
    SPIN_TRANSFER: 0.55,       // how strongly follow/draw pushes cue after hit
    SIDE_SPIN_CUSHION: 0.35,   // side english kick off cushions
    // Pockets
    POCKET_CORNER_R: 0.062,
    POCKET_SIDE_R: 0.058,
    // Substep target (seconds). Real dt is split into steps <= this.
    MAX_SUBSTEP: 1 / 480,
  };

  // Pocket centres. Corners sit just outside the play field diagonally; side
  // pockets sit at the middle of the long rails (±Z faces).
  const POCKETS = [
    { x: -PLAY_HALF_X, z: -PLAY_HALF_Z, r: CONFIG.POCKET_CORNER_R },
    { x:  PLAY_HALF_X, z: -PLAY_HALF_Z, r: CONFIG.POCKET_CORNER_R },
    { x: -PLAY_HALF_X, z:  PLAY_HALF_Z, r: CONFIG.POCKET_CORNER_R },
    { x:  PLAY_HALF_X, z:  PLAY_HALF_Z, r: CONFIG.POCKET_CORNER_R },
    { x: 0,            z: -PLAY_HALF_Z, r: CONFIG.POCKET_SIDE_R },
    { x: 0,            z:  PLAY_HALF_Z, r: CONFIG.POCKET_SIDE_R },
  ];
  CONFIG.POCKETS = POCKETS;

  // How close to the rail line a pocket's "mouth" opens, so balls near a
  // pocket aren't bounced back by the cushion before they can drop.
  const MOUTH = CONFIG.POCKET_CORNER_R * 0.86;

  function makeBall(id, opts) {
    return {
      id,
      x: opts.x, z: opts.z,
      vx: 0, vz: 0,
      radius: R,
      mass: CONFIG.BALL_MASS,
      active: true,        // still on the table
      pocketed: false,
      number: opts.number,
      group: opts.group,   // 'cue' | 'solid' | 'stripe' | 'eight'
      color: opts.color,
      striped: opts.group === 'stripe',
      // spin the cue carries into its first object-ball contact this shot
      spinFollow: 0,       // + follow / - draw
      spinSide: 0,         // + right / - left english
      usedSpin: false,
    };
  }

  function speed(b) { return Math.hypot(b.vx, b.vz); }

  // ------------------------------------------------------------------ engine
  function Simulation() {
    this.balls = [];
    this.events = null;
    this.reset();
  }

  Simulation.prototype.reset = function () {
    this.balls = [];
  };

  Simulation.prototype.anyMoving = function () {
    for (const b of this.balls) {
      if (b.active && speed(b) > CONFIG.STOP_SPEED) return true;
    }
    return false;
  };

  Simulation.prototype.cueBall = function () {
    return this.balls.find(b => b.group === 'cue');
  };

  // Begin a shot: give the cue ball velocity + stash spin for this shot.
  Simulation.prototype.shoot = function (dirX, dirZ, power, spinFollow, spinSide) {
    const cue = this.cueBall();
    if (!cue || !cue.active) return;
    const len = Math.hypot(dirX, dirZ) || 1;
    dirX /= len; dirZ /= len;
    const v = power; // caller passes final speed
    cue.vx = dirX * v;
    cue.vz = dirZ * v;
    cue.spinFollow = spinFollow || 0;
    cue.spinSide = spinSide || 0;
    cue.usedSpin = false;
    // Fresh event log for the rules layer to inspect once motion ends.
    this.events = {
      firstContact: null,     // id of first ball the cue touched
      cushionAfterContact: false,
      cushionBeforeContact: true, // set false if a ball is hit before any rail
      contactHappened: false,
      pocketed: [],           // { id, group, number } in the order they dropped
    };
  };

  // Advance the whole simulation by real-time dt, sub-stepping for stability.
  Simulation.prototype.update = function (dt) {
    let remaining = Math.min(dt, 0.1); // clamp huge frames (tab switch etc.)
    while (remaining > 1e-6) {
      const h = Math.min(CONFIG.MAX_SUBSTEP, remaining);
      this._substep(h);
      remaining -= h;
    }
  };

  Simulation.prototype._substep = function (h) {
    const balls = this.balls;

    // 1. Integrate + friction
    for (const b of balls) {
      if (!b.active) continue;
      const s = speed(b);
      if (s > 0) {
        // velocity-proportional + small constant deceleration (cloth)
        const decel = CONFIG.ROLL_FRICTION * h;
        const factor = Math.max(0, 1 - decel);
        b.vx *= factor;
        b.vz *= factor;
        const s2 = speed(b);
        const constDrag = 0.05 * h;
        if (s2 <= constDrag || s2 < CONFIG.STOP_SPEED) {
          b.vx = 0; b.vz = 0;
        } else {
          const nf = (s2 - constDrag) / s2;
          b.vx *= nf; b.vz *= nf;
        }
      }
      b.x += b.vx * h;
      b.z += b.vz * h;
    }

    // 2. Ball–ball collisions
    for (let i = 0; i < balls.length; i++) {
      const a = balls[i];
      if (!a.active) continue;
      for (let j = i + 1; j < balls.length; j++) {
        const b = balls[j];
        if (!b.active) continue;
        this._collidePair(a, b);
      }
    }

    // 3. Cushions
    for (const b of balls) {
      if (!b.active) continue;
      this._collideCushion(b);
    }

    // 4. Pockets
    for (const b of balls) {
      if (!b.active) continue;
      this._checkPocket(b);
    }
  };

  Simulation.prototype._collidePair = function (a, b) {
    const dx = b.x - a.x;
    const dz = b.z - a.z;
    const distSq = dx * dx + dz * dz;
    const minDist = a.radius + b.radius;
    if (distSq >= minDist * minDist || distSq === 0) return;

    const dist = Math.sqrt(distSq);
    const nx = dx / dist, nz = dz / dist;

    // Separate the overlap so balls never sink into each other.
    const overlap = minDist - dist;
    a.x -= nx * overlap * 0.5;
    a.z -= nz * overlap * 0.5;
    b.x += nx * overlap * 0.5;
    b.z += nz * overlap * 0.5;

    // Relative velocity along the normal
    const rvx = b.vx - a.vx;
    const rvz = b.vz - a.vz;
    const relN = rvx * nx + rvz * nz;
    if (relN > 0) return; // already separating

    const e = CONFIG.BALL_RESTITUTION;
    const imp = -(1 + e) * relN / 2; // equal masses
    const ix = imp * nx, iz = imp * nz;
    a.vx -= ix; a.vz -= iz;
    b.vx += ix; b.vz += iz;

    // Event / spin handling — only the cue vs an object ball matters for rules.
    const cueInvolved = a.group === 'cue' || b.group === 'cue';
    if (cueInvolved && this.events) {
      const cue = a.group === 'cue' ? a : b;
      const obj = a.group === 'cue' ? b : a;
      if (!this.events.contactHappened) {
        this.events.contactHappened = true;
        this.events.firstContact = obj.id;
        this.events.cushionBeforeContact = false;
      }
      // Follow / draw: push the cue along its incoming line after a hit.
      if (!cue.usedSpin && cue.spinFollow !== 0) {
        const inLen = Math.hypot(cue.vx, cue.vz);
        // direction the cue was heading (approx: opposite of normal for
        // a near-full hit; use pre-existing velocity dir when available)
        let dirx = nx, dirz = nz;
        const push = cue.spinFollow * CONFIG.SPIN_TRANSFER *
          (Math.abs(relN)) ;
        cue.vx += dirx * push;
        cue.vz += dirz * push;
        cue.usedSpin = true;
      }
    }
  };

  Simulation.prototype._collideCushion = function (b) {
    const r = b.radius;
    let hit = false;
    let nearPocket = false;

    // If the ball is over a pocket mouth, let it pass (so it can drop).
    for (const p of CONFIG.POCKETS) {
      if (Math.hypot(b.x - p.x, b.z - p.z) < p.r + r * 0.5) { nearPocket = true; break; }
    }
    // Also open the mouth region along the rails near each pocket.
    const nearMouthX = (Math.abs(b.z) > CONFIG.PLAY_HALF_Z - 0.001) &&
      (Math.abs(Math.abs(b.x) - CONFIG.PLAY_HALF_X) < MOUTH || Math.abs(b.x) < MOUTH);
    const nearMouthZ = (Math.abs(b.x) > CONFIG.PLAY_HALF_X - 0.001) &&
      (Math.abs(Math.abs(b.z) - CONFIG.PLAY_HALF_Z) < MOUTH);

    // X rails (short rails at ±PLAY_HALF_X)
    if (!nearPocket && !nearMouthZ) {
      if (b.x + r > CONFIG.PLAY_HALF_X && b.vx > 0) {
        b.x = CONFIG.PLAY_HALF_X - r;
        b.vx = -b.vx * CONFIG.CUSHION_RESTITUTION;
        b.vz *= CONFIG.CUSHION_FRICTION;
        b.vz += b.spinSide * CONFIG.SIDE_SPIN_CUSHION * Math.abs(b.vx);
        hit = true;
      } else if (b.x - r < -CONFIG.PLAY_HALF_X && b.vx < 0) {
        b.x = -CONFIG.PLAY_HALF_X + r;
        b.vx = -b.vx * CONFIG.CUSHION_RESTITUTION;
        b.vz *= CONFIG.CUSHION_FRICTION;
        b.vz -= b.spinSide * CONFIG.SIDE_SPIN_CUSHION * Math.abs(b.vx);
        hit = true;
      }
    }
    // Z rails (long rails at ±PLAY_HALF_Z)
    if (!nearPocket && !nearMouthX) {
      if (b.z + r > CONFIG.PLAY_HALF_Z && b.vz > 0) {
        b.z = CONFIG.PLAY_HALF_Z - r;
        b.vz = -b.vz * CONFIG.CUSHION_RESTITUTION;
        b.vx *= CONFIG.CUSHION_FRICTION;
        b.vx -= b.spinSide * CONFIG.SIDE_SPIN_CUSHION * Math.abs(b.vz);
        hit = true;
      } else if (b.z - r < -CONFIG.PLAY_HALF_Z && b.vz < 0) {
        b.z = -CONFIG.PLAY_HALF_Z + r;
        b.vz = -b.vz * CONFIG.CUSHION_RESTITUTION;
        b.vx *= CONFIG.CUSHION_FRICTION;
        b.vx += b.spinSide * CONFIG.SIDE_SPIN_CUSHION * Math.abs(b.vz);
        hit = true;
      }
    }

    if (hit && this.events) {
      if (this.events.contactHappened) this.events.cushionAfterContact = true;
    }
  };

  Simulation.prototype._checkPocket = function (b) {
    for (const p of CONFIG.POCKETS) {
      if (Math.hypot(b.x - p.x, b.z - p.z) < p.r) {
        b.active = false;
        b.pocketed = true;
        b.vx = 0; b.vz = 0;
        // Sink target for the drop animation (renderer reads this).
        b.sinkX = p.x; b.sinkZ = p.z;
        if (this.events) {
          this.events.pocketed.push({ id: b.id, group: b.group, number: b.number });
        }
        return;
      }
    }
  };

  // Cheap line/ball intersection used by aiming preview + AI.
  // Returns nearest hit ball along ray (ox,oz)+(dx,dz), ignoring `ignoreId`.
  Simulation.prototype.rayFirstBall = function (ox, oz, dx, dz, ignoreId) {
    const len = Math.hypot(dx, dz) || 1;
    dx /= len; dz /= len;
    let best = null, bestT = Infinity;
    const rr = CONFIG.R * 2;
    for (const b of this.balls) {
      if (!b.active || b.id === ignoreId) continue;
      const ex = b.x - ox, ez = b.z - oz;
      const t = ex * dx + ez * dz;
      if (t < 0) continue;
      const px = ox + dx * t, pz = oz + dz * t;
      const perp = Math.hypot(b.x - px, b.z - pz);
      if (perp <= rr) {
        // back up to the true contact point
        const back = Math.sqrt(Math.max(0, rr * rr - perp * perp));
        const tt = t - back;
        if (tt < bestT) { bestT = tt; best = b; }
      }
    }
    return best ? { ball: best, t: bestT } : null;
  };

  global.Pool = global.Pool || {};
  global.Pool.CONFIG = CONFIG;
  global.Pool.Simulation = Simulation;
  global.Pool.makeBall = makeBall;
  global.Pool.speed = speed;

})(window);
