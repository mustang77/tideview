/* ============================================================================
 * Break & Run — game rules, turns, AI, input & HUD
 * ----------------------------------------------------------------------------
 * The 8-ball rulebook lives here: racking, break legality, group assignment,
 * fouls, ball-in-hand, and the 8-ball win/loss test (evaluated in pocket
 * order so clearing your group and the 8 on one shot is judged correctly).
 * Also: a shot-searching AI, all pointer/keyboard input, and HUD wiring.
 * ==========================================================================*/
(function (global) {
  'use strict';
  const P = global.Pool;
  const C = P.CONFIG;

  const MAX_SPEED = 6.2;      // cue speed at 100% power
  const BREAK_SPEED = 6.0;

  function groupOf(number) {
    if (number === 0) return 'cue';
    if (number === 8) return 'eight';
    return number <= 7 ? 'solid' : 'stripe';
  }

  function shuffle(a) {
    for (let i = a.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [a[i], a[j]] = [a[j], a[i]];
    }
    return a;
  }

  function Game(scene, sim) {
    this.scene = scene;
    this.sim = sim;
    this.players = [
      { name: 'Player 1', group: null, isAI: false },
      { name: 'Player 2', group: null, isAI: true },
    ];
    this.current = 0;
    this.open = true;
    this.phase = 'menu';        // menu | aiming | placing | shooting | over
    this.ballInHand = false;
    this.isBreakShot = true;
    this.power = 0.75;
    this.spinFollow = 0;
    this.spinSide = 0;
    this.aiDifficulty = 'medium';
    this.preShot = null;
    this._aiThinkTimer = 0;
    this._toastTimer = 0;
    // Shot clock
    this.turnLimit = 30;        // seconds per shot (0 = off)
    this.turnTime = 30;
    this._lastTickSecond = -1;
    this.audio = null;
  }

  // Wire the audio engine into both the game and the physics sim (once).
  Game.prototype.attachAudio = function (audio) {
    this.audio = audio;
    const a = audio;
    this.sim.sound = {
      ball: (v, cue) => a.ball(v, cue),
      rail: (v) => a.rail(v),
      pocket: (isCue) => a.pocket(isCue),
    };
  };

  Game.prototype.startTurnTimer = function () {
    this.turnTime = this.turnLimit;
    this._lastTickSecond = -1;
  };

  // ---------------------------------------------------------------- rack
  Game.prototype.newGame = function (mode, difficulty) {
    this.players[1].isAI = (mode === 'ai');
    this.players[0].name = 'Player 1';
    this.players[1].name = mode === 'ai' ? 'Computer' : 'Player 2';
    this.aiDifficulty = difficulty || 'medium';
    this.players[0].group = null;
    this.players[1].group = null;
    this.current = 0;
    this.open = true;
    this.isBreakShot = true;
    this.ballInHand = false;
    this.phase = 'aiming';

    const balls = [];
    balls.push(P.makeBall('cue', { x: C.HEAD_SPOT_X, z: 0, number: 0, group: 'cue', color: '#fff' }));

    // Build a valid rack: 8 in the centre of row 3, back corners split.
    const spacing = C.R * 2 * 1.002;
    const rowDX = spacing * Math.cos(Math.PI / 6);
    const slots = [];
    for (let row = 0; row < 5; row++) {
      for (let k = 0; k <= row; k++) {
        slots.push({
          row, k,
          x: C.FOOT_SPOT_X + row * rowDX,
          z: (k - row / 2) * spacing,
        });
      }
    }
    // slot indices: row2 middle is index 3+1=4 (0:apex,1,2,3,4,5,...)
    const idxRow2Mid = 4;           // row2 (indices 3,4,5) middle
    const idxBackFirst = 10;        // row4 first (indices 10..14)
    const idxBackLast = 14;         // row4 last
    let nums = shuffle([1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15]);
    const assign = new Array(15).fill(null);
    assign[idxRow2Mid] = 8;
    // guarantee one solid + one stripe in the back corners
    const solids = nums.filter(n => n <= 7);
    const stripes = nums.filter(n => n >= 9);
    assign[idxBackFirst] = solids.pop();
    assign[idxBackLast] = stripes.pop();
    const rest = shuffle(solids.concat(stripes));
    for (let i = 0; i < 15; i++) {
      if (assign[i] === null) assign[i] = rest.pop();
    }
    for (let i = 0; i < 15; i++) {
      const n = assign[i];
      balls.push(P.makeBall('b' + n, {
        x: slots[i].x, z: slots[i].z, number: n, group: groupOf(n),
      }));
    }

    this.sim.balls = balls;
    this.scene.buildBalls(balls);
    this.scene.aimAngle = 0;      // aim toward +x (into the rack)
    this.scene.cam.mode = 'aim';
    this.startTurnTimer();
    this.updateHUD();
    this.toast(this.players[0].name + ' to break', 2200);
    this.maybeAI();
  };

  Game.prototype.player = function () { return this.players[this.current]; };
  Game.prototype.opponent = function () { return this.players[1 - this.current]; };

  Game.prototype.activeOf = function (grp) {
    return this.sim.balls.filter(b => b.active && b.group === grp).length;
  };

  // ---------------------------------------------------------------- shooting
  Game.prototype.canShoot = function () {
    return this.phase === 'aiming' && !this.player().isAI;
  };

  Game.prototype.beginShot = function () {
    if (this.phase !== 'aiming') return;
    // snapshot pre-shot group counts for the 8-ball ruling
    this.preShot = {
      solid: this.activeOf('solid'),
      stripe: this.activeOf('stripe'),
    };
    const ang = this.scene.aimAngle;
    const speed = this.isBreakShot
      ? BREAK_SPEED
      : (0.35 + this.power * (MAX_SPEED - 0.35));
    this.sim.shoot(Math.cos(ang), Math.sin(ang), speed, this.spinFollow, this.spinSide);
    if (this.audio) this.audio.cue(this.isBreakShot ? 1 : this.power);
    this.phase = 'shooting';
    this.scene.freezeAim = false;
    this.scene.updateAim(this.sim, 0, false);
  };

  // Called each frame while balls move; returns when settled & resolves.
  Game.prototype.tick = function (dt) {
    if (this.phase === 'shooting') {
      this.sim.update(dt);
      this.scene.syncBalls(this.sim, dt);
      if (!this.sim.anyMoving()) {
        // let drop animations finish
        this._settleTimer = (this._settleTimer || 0) + dt;
        if (this._settleTimer > 0.5) {
          this._settleTimer = 0;
          this.resolveShot();
        }
      } else {
        this._settleTimer = 0;
      }
    } else {
      this.scene.syncBalls(this.sim, dt);
      if (this.phase === 'aiming') {
        this.scene.updateAim(this.sim, this.power, true);
        if (this.player().isAI) this._aiTick(dt);
      } else {
        this.scene.updateAim(this.sim, 0, false);
      }
    }
    this.scene.updateCamera(this.sim, dt);
    if (this._toastTimer > 0) {
      this._toastTimer -= dt;
      if (this._toastTimer <= 0) this._hideToast();
    }
    this._tickTimer(dt);
  };

  // Shot clock: counts down during a player's aiming / ball-in-hand turn.
  Game.prototype._tickTimer = function (dt) {
    if (!this.turnLimit || this.phase === 'over' || this.phase === 'menu') {
      this.updateTimerUI();
      return;
    }
    if (this.phase !== 'aiming' && this.phase !== 'placing') { this.updateTimerUI(); return; }
    this.turnTime -= dt;
    const secs = Math.ceil(this.turnTime);
    if (secs !== this._lastTickSecond) {
      this._lastTickSecond = secs;
      if (secs <= 5 && secs > 0 && this.audio && !this.player().isAI) this.audio.tick();
    }
    if (this.turnTime <= 0) { this.turnTime = 0; this.onTimeout(); }
    this.updateTimerUI();
  };

  Game.prototype.onTimeout = function () {
    if (this.player().isAI) {
      // Force the computer to take its (already planned) shot immediately.
      if (this._aiPlan) { this.scene.aimAngle = this._aiPlan.angle; this.power = this._aiPlan.power; }
      if (this.phase === 'aiming') this.beginShot();
      return;
    }
    // Human ran out of time: foul, opponent gets ball in hand.
    if (this.audio) this.audio.foul();
    this.toast("Time's up — foul! Ball in hand.", 2800);
    this.current = 1 - this.current;
    this.ballInHand = true;
    this.phase = 'placing';
    this.placeCueDefault();
    this.startTurnTimer();
    this.updateHUD();
    this.maybeAI();
  };

  // ---------------------------------------------------------------- rules
  Game.prototype.resolveShot = function () {
    const ev = this.sim.events || { pocketed: [] };
    const shooter = this.player();
    const pocketed = ev.pocketed;
    const scratch = pocketed.some(p => p.group === 'cue');
    const objPocketed = pocketed.filter(p => p.group !== 'cue');
    const eightDrop = pocketed.find(p => p.group === 'eight');
    let foul = false;
    let reason = '';

    if (this.isBreakShot) {
      const legalBreak = objPocketed.length > 0 || ev.cushionAfterContact;
      if (!ev.contactHappened || !legalBreak) { foul = true; reason = 'Illegal break'; }
      this.isBreakShot = false;
    } else {
      if (!ev.contactHappened) {
        foul = true; reason = 'No ball hit';
      } else {
        const firstBall = this.sim.balls.find(b => b.id === ev.firstContact);
        const fg = firstBall ? firstBall.group : null;
        let legalFirst;
        if (shooter.group) {
          const cleared = this.groupClearedBefore(shooter.group);
          legalFirst = cleared ? (fg === 'eight') : (fg === shooter.group);
          if (!legalFirst) reason = cleared ? 'Must hit the 8 first' : 'Hit the wrong group first';
        } else {
          legalFirst = fg !== 'eight';
          if (!legalFirst) reason = "Can't hit the 8 first on an open table";
        }
        if (!legalFirst) foul = true;
        // No-rail foul: after a legal contact, a ball must be pocketed or reach a rail.
        if (!foul && objPocketed.length === 0 && !ev.cushionAfterContact) {
          foul = true; reason = 'No rail after contact';
        }
      }
    }
    if (scratch && !foul) { foul = true; reason = 'Scratch — cue ball pocketed'; }
    else if (scratch) { reason = reason + ' + scratch'; }

    // ---- 8-ball resolution (order-aware) --------------------------------
    if (eightDrop) {
      // how many of shooter's group remained when the 8 dropped?
      let remaining = this.preShot ? this.preShot[shooter.group] : 1;
      if (!shooter.group) remaining = 1; // open table => 8 is illegal target
      for (const p of pocketed) {
        if (p.group === 'eight') break;
        if (shooter.group && p.group === shooter.group) remaining--;
      }
      const legal8 = shooter.group && remaining <= 0 && !foul && !scratch;
      if (legal8) {
        return this.endGame(this.current, shooter.name + ' sinks the 8 — game!');
      }
      return this.endGame(1 - this.current,
        shooter.name + (scratch ? ' scratched on the 8' :
          (!shooter.group || remaining > 0) ? ' pocketed the 8 too early' : ' fouled on the 8'));
    }

    // ---- open-table group assignment ------------------------------------
    if (this.open && !foul) {
      const firstObj = objPocketed.find(p => p.group === 'solid' || p.group === 'stripe');
      if (firstObj) {
        const g = firstObj.group;
        shooter.group = g;
        this.opponent().group = g === 'solid' ? 'stripe' : 'solid';
        this.open = false;
        this.toast(shooter.name + ' is ' + (g === 'solid' ? 'SOLIDS' : 'STRIPES'), 2400);
      }
    }

    // ---- cue ball respot on scratch -------------------------------------
    if (scratch) {
      const cue = this.sim.cueBall();
      cue.active = true; cue.pocketed = false;
      cue.vx = cue.vz = 0;
      cue.x = C.HEAD_SPOT_X; cue.z = 0;
      const m = this.scene.ballMeshes['cue'];
      if (m) { m.visible = true; m.position.set(cue.x, C.R, cue.z); }
    }

    // ---- whose turn next -------------------------------------------------
    let madeOwn;
    if (this.open) {
      // still open (break made balls but stayed open, or nothing decisive)
      madeOwn = objPocketed.length > 0;
    } else {
      madeOwn = objPocketed.some(p => p.group === shooter.group);
    }

    if (foul) {
      if (this.audio) this.audio.foul();
      this.toast('Foul — ' + reason + '. Ball in hand.', 3000);
      this.current = 1 - this.current;
      this.ballInHand = true;
      this.phase = 'placing';
      this.placeCueDefault();
      this.startTurnTimer();
      this.updateHUD();
      this.maybeAI();
      return;
    }

    if (madeOwn) {
      // shooter continues
      if (objPocketed.length) this.toast(shooter.name + ' continues', 1400);
      this.phase = 'aiming';
    } else {
      this.current = 1 - this.current;
      this.phase = 'aiming';
    }
    this.startTurnTimer();
    this.pointAimAtSensibleTarget();
    this.updateHUD();
    this.maybeAI();
  };

  Game.prototype.groupClearedBefore = function (grp) {
    return this.activeOf(grp) === 0;
  };

  Game.prototype.endGame = function (winnerIdx, msg) {
    this.phase = 'over';
    this.scene.updateAim(this.sim, 0, false);
    this.scene.freezeAim = false;
    this.winner = winnerIdx;
    if (this.audio) this.audio.win();
    const el = document.getElementById('resultText');
    const sub = document.getElementById('resultSub');
    if (el) el.textContent = this.players[winnerIdx].name + ' wins!';
    if (sub) sub.textContent = msg;
    const ov = document.getElementById('result');
    if (ov) ov.classList.add('show');
    this.updateHUD();
  };

  // ---------------------------------------------------------------- ball in hand
  Game.prototype.placeCueDefault = function () {
    const cue = this.sim.cueBall();
    cue.active = true; cue.pocketed = false; cue.vx = cue.vz = 0;
    let x = this.isBreakShot ? C.HEAD_SPOT_X : cue.x;
    // put it somewhere legal (default head spot region)
    if (!this.isValidCuePos(C.HEAD_SPOT_X, 0)) {
      // nudge until valid
      let placed = false;
      for (let dz = 0; dz < C.PLAY_HALF_Z && !placed; dz += C.R) {
        for (const s of [1, -1]) {
          if (this.isValidCuePos(C.HEAD_SPOT_X, s * dz)) { cue.x = C.HEAD_SPOT_X; cue.z = s * dz; placed = true; break; }
        }
      }
    } else { cue.x = C.HEAD_SPOT_X; cue.z = 0; }
    const m = this.scene.ballMeshes['cue'];
    if (m) { m.visible = true; m.position.set(cue.x, C.R, cue.z); }
  };

  Game.prototype.isValidCuePos = function (x, z) {
    if (Math.abs(x) > C.PLAY_HALF_X - C.R) return false;
    if (Math.abs(z) > C.PLAY_HALF_Z - C.R) return false;
    for (const p of C.POCKETS) if (Math.hypot(x - p.x, z - p.z) < p.r + C.R) return false;
    for (const b of this.sim.balls) {
      if (b.group === 'cue' || !b.active) continue;
      if (Math.hypot(x - b.x, z - b.z) < C.R * 2) return false;
    }
    return true;
  };

  Game.prototype.tryPlaceCue = function (x, z) {
    if (!this.isValidCuePos(x, z)) return false;
    const cue = this.sim.cueBall();
    cue.x = x; cue.z = z;
    const m = this.scene.ballMeshes['cue'];
    if (m) m.position.set(x, C.R, z);
    return true;
  };

  Game.prototype.confirmPlace = function () {
    if (this.phase !== 'placing') return;
    this.ballInHand = false;
    this.phase = 'aiming';
    this.startTurnTimer();
    this.pointAimAtSensibleTarget();
    this.updateHUD();
    this.maybeAI();
  };

  // aim toward the nearest legal target so the guide starts somewhere useful
  Game.prototype.pointAimAtSensibleTarget = function () {
    const cue = this.sim.cueBall();
    if (!cue) return;
    const shooter = this.player();
    let targets = this.legalTargets(shooter);
    let best = null, bestD = Infinity;
    for (const b of targets) {
      const d = Math.hypot(b.x - cue.x, b.z - cue.z);
      if (d < bestD) { bestD = d; best = b; }
    }
    if (best) this.scene.aimAngle = Math.atan2(best.z - cue.z, best.x - cue.x);
  };

  Game.prototype.legalTargets = function (shooter) {
    const balls = this.sim.balls.filter(b => b.active && b.group !== 'cue');
    if (!shooter.group) return balls.filter(b => b.group !== 'eight');
    if (this.groupClearedBefore(shooter.group)) return balls.filter(b => b.group === 'eight');
    return balls.filter(b => b.group === shooter.group);
  };

  // ---------------------------------------------------------------- AI
  Game.prototype.maybeAI = function () {
    if (this.phase === 'placing' && this.player().isAI) {
      // AI ball-in-hand: place near a good shot (simple: leave default)
      this.ballInHand = false;
      this.phase = 'aiming';
    }
    if (this.phase === 'aiming' && this.player().isAI) {
      this._aiThinkTimer = 0.7 + Math.random() * 0.5;
      this._aiPlan = null;
    }
  };

  Game.prototype._aiTick = function (dt) {
    if (this._aiThinkTimer > 0) {
      if (!this._aiPlan) this._aiPlan = this.computeAIShot();
      // rotate aim smoothly toward the planned angle for a natural look
      if (this._aiPlan) {
        let da = this._aiPlan.angle - this.scene.aimAngle;
        while (da > Math.PI) da -= Math.PI * 2;
        while (da < -Math.PI) da += Math.PI * 2;
        this.scene.aimAngle += da * Math.min(1, dt * 5);
        this.power = this._aiPlan.power;
        this.spinFollow = 0; this.spinSide = 0;
        this.updatePowerUI();
      }
      this._aiThinkTimer -= dt;
      if (this._aiThinkTimer <= 0 && this._aiPlan) {
        this.scene.aimAngle = this._aiPlan.angle;
        this.beginShot();
      }
    }
  };

  Game.prototype.computeAIShot = function () {
    const cue = this.sim.cueBall();
    const shooter = this.player();
    const targets = this.legalTargets(shooter);
    const noise = { easy: 0.09, medium: 0.035, hard: 0.012 }[this.aiDifficulty] || 0.035;
    let best = null;
    for (const ball of targets) {
      for (const p of C.POCKETS) {
        // ghost ball behind the object ball on the line to the pocket
        const pdx = p.x - ball.x, pdz = p.z - ball.z;
        const pl = Math.hypot(pdx, pdz) || 1;
        const gx = ball.x - (pdx / pl) * C.R * 2;
        const gz = ball.z - (pdz / pl) * C.R * 2;
        const cdx = gx - cue.x, cdz = gz - cue.z;
        const cl = Math.hypot(cdx, cdz) || 1;
        const aimx = cdx / cl, aimz = cdz / cl;
        // cut angle: how straight the object goes to the pocket
        const cut = (aimx * pdx / pl) + (aimz * pdz / pl);
        if (cut < 0.25) continue; // too thin / behind
        // path from cue to ghost must first meet THIS ball
        const hit = this.sim.rayFirstBall(cue.x, cue.z, aimx, aimz, 'cue');
        if (!hit || hit.ball.id !== ball.id) continue;
        // pocket path must be clear of other balls
        if (this.blocked(ball.x, ball.z, p.x, p.z, ball.id)) continue;
        const dist = cl + pl;
        const score = cut * 2.0 - dist * 0.25;
        if (!best || score > best.score) {
          best = { score, angle: Math.atan2(aimz, aimx), cut, dist,
            power: Math.min(1, 0.4 + dist * 0.22) };
        }
      }
    }
    if (best) {
      best.angle += (Math.random() - 0.5) * noise;
      return best;
    }
    // No shot: gentle safety toward nearest legal ball.
    let near = null, nd = Infinity;
    for (const b of targets) {
      const d = Math.hypot(b.x - cue.x, b.z - cue.z);
      if (d < nd) { nd = d; near = b; }
    }
    if (near) {
      return { angle: Math.atan2(near.z - cue.z, near.x - cue.x) + (Math.random() - 0.5) * noise,
        power: 0.4 };
    }
    return { angle: this.scene.aimAngle, power: 0.5 };
  };

  Game.prototype.blocked = function (x0, z0, x1, z1, ignoreId) {
    const dx = x1 - x0, dz = z1 - z0;
    const len = Math.hypot(dx, dz) || 1;
    const ux = dx / len, uz = dz / len;
    for (const b of this.sim.balls) {
      if (!b.active || b.id === ignoreId || b.group === 'cue') continue;
      const ex = b.x - x0, ez = b.z - z0;
      const t = ex * ux + ez * uz;
      if (t < 0 || t > len) continue;
      const perp = Math.abs(ex * uz - ez * ux);
      if (perp < C.R * 1.9) return true;
    }
    return false;
  };

  // ---------------------------------------------------------------- HUD
  Game.prototype.updateHUD = function () {
    for (let i = 0; i < 2; i++) {
      const pl = this.players[i];
      const card = document.getElementById('p' + (i + 1) + 'card');
      const name = document.getElementById('p' + (i + 1) + 'name');
      const grp = document.getElementById('p' + (i + 1) + 'group');
      const cnt = document.getElementById('p' + (i + 1) + 'count');
      if (name) name.textContent = pl.name;
      if (card) card.classList.toggle('active', i === this.current && this.phase !== 'over');
      if (grp) {
        grp.className = 'grp ' + (pl.group || 'open');
        grp.textContent = pl.group ? (pl.group === 'solid' ? 'SOLIDS' : 'STRIPES') : '—';
      }
      if (cnt) {
        if (pl.group) cnt.textContent = this.activeOf(pl.group) + ' left';
        else cnt.textContent = '';
      }
    }
    const hint = document.getElementById('hint');
    if (hint) {
      if (this.phase === 'placing') hint.textContent = 'Ball in hand — drag the cue ball to a legal spot, then click to place';
      else if (this.phase === 'aiming' && this.player().isAI) hint.textContent = this.players[this.current].name + ' is thinking…';
      else if (this.phase === 'aiming') hint.textContent = 'Drag the table to aim · pull the cue back & release to shoot (or use the power slider + SHOOT)';
      else hint.textContent = '';
    }
  };

  Game.prototype.updateTimerUI = function () {
    for (let i = 0; i < 2; i++) {
      const el = document.getElementById('p' + (i + 1) + 'timer');
      if (!el) continue;
      const isActive = i === this.current && (this.phase === 'aiming' || this.phase === 'placing');
      if (!this.turnLimit || !isActive) { el.textContent = ''; el.className = 'ptimer'; continue; }
      const s = Math.max(0, Math.ceil(this.turnTime));
      el.textContent = ':' + (s < 10 ? '0' + s : s);
      el.className = 'ptimer' + (s <= 5 ? ' low' : '');
    }
  };

  Game.prototype.toast = function (msg, ms) {
    const el = document.getElementById('toast');
    if (!el) return;
    el.textContent = msg;
    el.classList.add('show');
    this._toastTimer = (ms || 2000) / 1000;
  };
  Game.prototype._hideToast = function () {
    const el = document.getElementById('toast');
    if (el) el.classList.remove('show');
  };

  Game.prototype.updatePowerUI = function () {
    const fill = document.getElementById('powerFill');
    const val = document.getElementById('powerVal');
    if (fill) fill.style.height = (this.power * 100) + '%';
    if (val) val.textContent = Math.round(this.power * 100);
  };

  global.Pool.Game = Game;
  global.Pool.groupOf = groupOf;

})(window);
