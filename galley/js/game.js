/* ============================================================================
 * Galley Rush — order-serving logic (wash-to-serve + hearts)
 * ----------------------------------------------------------------------------
 * Waiters/waitresses queue up (3 slots), each asking for a clean PLATE, BOWL
 * or GLASS with a patience bar. Select a waiter, hold WASH to scrub that item,
 * and it's served automatically. Serve the shift's order target to win. If a
 * waiter's patience runs out they leave and you lose a heart — 0 hearts (or the
 * shift clock) ends the shift.
 * ==========================================================================*/
(function (global) {
  'use strict';

  const TYPES = ['plate', 'bowl', 'glass'];
  const SCRUB_TIME = 0.85;   // hold-time to wash one item

  function Game() { this.level = 0; this.reset(); }

  Game.prototype.levels = function (i) {
    const target = 12 + i * 4;
    const patience = Math.max(7, 15 - i);       // seconds a waiter waits
    const time = Math.round(target * 3.2) + 15; // shift clock
    return { target, patience, time };
  };

  Game.prototype.reset = function () {
    const L = this.levels(this.level);
    this.target = L.target; this.timeLimit = L.time; this.timeLeft = L.time;
    this.basePatience = L.patience;
    this.hearts = 5;
    this.served = 0;
    this.slots = [null, null, null];    // each: {type, patience, max, fresh}
    this.current = null;                // {slot, type, scrub}
    this.spawnT = 0;
    this.stationT = 0;
    this.phase = 'briefing';            // briefing | playing | won | lost
    this.station = 'idle';
    this.events = [];
  };

  Game.prototype.start = function () {
    this.phase = 'playing'; this.station = 'sink';
    this.spawnOrder(); this.spawnOrder();   // seed two waiters
    this.spawnT = 1.5;
  };
  Game.prototype.nextLevel = function () { this.level++; this.reset(); };
  Game.prototype.retry = function () { this.reset(); };
  Game.prototype._emit = function (e) { this.events.push(e); };
  Game.prototype._rand = function (n) { return Math.floor(Math.random() * n); };

  Game.prototype.spawnOrder = function () {
    const empty = [];
    for (let i = 0; i < 3; i++) if (!this.slots[i]) empty.push(i);
    if (!empty.length) return;
    const i = empty[this._rand(empty.length)];
    const type = TYPES[this._rand(TYPES.length)];
    this.slots[i] = { type, patience: this.basePatience, max: this.basePatience, fresh: 0.4 };
    this._emit('newOrder');
  };

  // Pick a waiter to serve (grabs that item to wash).
  Game.prototype.select = function (i) {
    if (this.phase !== 'playing') return;
    if (!this.slots[i]) return;
    if (this.current && this.current.slot === i) return;
    this.current = { slot: i, type: this.slots[i].type, scrub: 0 };
    this.station = 'sink'; this._emit('pickup');
  };
  Game.prototype.autoSelect = function () {
    let best = -1, bp = Infinity;
    for (let i = 0; i < 3; i++) if (this.slots[i] && this.slots[i].patience < bp) { bp = this.slots[i].patience; best = i; }
    if (best >= 0) this.select(best);
  };

  // Hold-to-wash the selected order; auto-serves when the item is clean.
  Game.prototype.scrub = function (dt) {
    if (this.phase !== 'playing') return false;
    if (!this.current) { this.autoSelect(); if (!this.current) return false; }
    const o = this.slots[this.current.slot];
    if (!o || o.type !== this.current.type) { this.current = null; return false; }
    this.station = 'sink';
    this.current.scrub += dt / SCRUB_TIME;
    this._emit('scrub');
    if (this.current.scrub >= 1) this._serve(this.current.slot);
    return true;
  };

  Game.prototype._serve = function (i) {
    this.slots[i] = null; this.current = null;
    this.served++; this.station = 'serve'; this.stationT = 0.4;
    this._emit('served');
    if (this.served >= this.target) { this.phase = 'won'; this._emit('won'); }
  };

  Game.prototype.currentType = function () { return this.current ? this.current.type : null; };
  Game.prototype.currentScrub = function () { return this.current ? this.current.scrub : 0; };

  Game.prototype.update = function (dt) {
    if (this.phase !== 'playing') return;
    this.timeLeft -= dt;
    if (this.stationT > 0) { this.stationT -= dt; if (this.stationT <= 0 && this.station === 'serve') this.station = 'sink'; }

    // patience (the order being washed is spared)
    for (let i = 0; i < 3; i++) {
      const o = this.slots[i]; if (!o) continue;
      if (o.fresh > 0) o.fresh -= dt;
      const washingThis = this.current && this.current.slot === i;
      if (!washingThis) {
        o.patience -= dt;
        if (o.patience <= 0) {
          this.slots[i] = null;
          if (this.current && this.current.slot === i) this.current = null;
          this.hearts--; this._emit('fail');
          if (this.hearts <= 0) { this.phase = 'lost'; this._emit('lost'); return; }
        }
      }
    }

    // spawn new waiters over time
    this.spawnT -= dt;
    const occupied = this.slots.filter(Boolean).length;
    if (this.spawnT <= 0 && occupied < 3) { this.spawnOrder(); this.spawnT = 1.8 + Math.random() * 2.2; }

    if (this.timeLeft <= 0) { this.timeLeft = 0; this.phase = 'lost'; this._emit('lost'); }
  };

  Game.prototype.stars = function () {
    const h = this.hearts;
    return h >= 5 ? 3 : (h >= 3 ? 2 : 1);
  };

  global.Galley = global.Galley || {};
  global.Galley.Game = Game;
  global.Galley.ORDER_TYPES = TYPES;

})(window);
