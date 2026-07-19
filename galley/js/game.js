/* ============================================================================
 * Galley Rush — strategic hand-wash logic
 * ----------------------------------------------------------------------------
 * Waiters queue up asking for a clean PLATE, BOWL or GLASS (each with a
 * patience bar). YOU decide what to wash: tap a dish type to queue it at the
 * sink. Only one item washes at a time (the bottleneck), and clean items
 * stack as ready stock. Tap a waiter to hand over a matching clean item.
 * Serve the shift's target before the clock/patience beat you. No auto-pilot —
 * the challenge is choosing the right things to wash, in the right order.
 * ==========================================================================*/
(function (global) {
  'use strict';
  const TYPES = ['plate', 'bowl', 'glass'];
  const WASH_TIME = 1.15;   // seconds to wash one item at the sink
  const QUEUE_CAP = 4;      // washing + queued
  const STOCK_CAP = 5;      // clean stock per type

  function Game() { this.level = 0; this.reset(); }

  Game.prototype.levels = function (i) {
    const target = 12 + i * 4;
    const patience = Math.max(6.5, 14 - i * 1.2);
    const time = Math.round(target * 3.4) + 15;
    const maxOrders = i < 2 ? 3 : 4;
    return { target, patience, time, maxOrders };
  };

  Game.prototype.reset = function () {
    const L = this.levels(this.level);
    this.target = L.target; this.timeLimit = L.time; this.timeLeft = L.time;
    this.basePatience = L.patience; this.maxOrders = L.maxOrders;
    this.hearts = 5; this.served = 0;
    this.cleanStock = { plate: 0, bowl: 0, glass: 0 };
    this.washQueue = [];             // array of types waiting to be washed
    this.washing = null;             // { type, progress }
    this.slots = new Array(4).fill(null); // orders (up to maxOrders active)
    this.spawnT = 0;
    this.phase = 'briefing';         // briefing | playing | won | lost
    this.events = [];
  };

  Game.prototype.start = function () {
    this.phase = 'playing';
    this.spawnOrder(); this.spawnOrder();
    this.spawnT = 1.2;
  };
  Game.prototype.nextLevel = function () { this.level++; this.reset(); };
  Game.prototype.retry = function () { this.reset(); };
  Game.prototype._emit = function (e) { this.events.push(e); };
  Game.prototype._rand = function (n) { return Math.floor(Math.random() * n); };

  Game.prototype.pendingOf = function (type) {
    let n = this.washing && this.washing.type === type ? 1 : 0;
    for (const t of this.washQueue) if (t === type) n++;
    return n;
  };

  // Player chooses to wash a type. Blocked if the queue is full or that type is
  // already fully stocked+queued (so you can't wastefully over-wash).
  Game.prototype.queueWash = function (type) {
    if (this.phase !== 'playing') return false;
    const totalPending = this.washQueue.length + (this.washing ? 1 : 0);
    if (totalPending >= QUEUE_CAP) { this._emit('queueFull'); return false; }
    if (this.cleanStock[type] + this.pendingOf(type) >= STOCK_CAP) { this._emit('stockFull'); return false; }
    this.washQueue.push(type);
    this._emit('queued');
    return true;
  };

  // Hand a clean item to waiter i (must have matching stock).
  Game.prototype.serve = function (i) {
    if (this.phase !== 'playing') return false;
    const o = this.slots[i]; if (!o) return false;
    if (this.cleanStock[o.type] <= 0) { this._emit('noStock'); return false; }
    this.cleanStock[o.type]--; this.slots[i] = null;
    this.served++; this._emit('served');
    if (this.served >= this.target) { this.phase = 'won'; this._emit('won'); }
    return true;
  };

  Game.prototype.spawnOrder = function () {
    const empty = [];
    for (let i = 0; i < this.maxOrders; i++) if (!this.slots[i]) empty.push(i);
    if (!empty.length) return;
    const i = empty[this._rand(empty.length)];
    const type = TYPES[this._rand(TYPES.length)];
    this.slots[i] = { type, patience: this.basePatience, max: this.basePatience, fresh: 0.4 };
    this._emit('newOrder');
  };

  Game.prototype.washFrac = function () { return this.washing ? this.washing.progress : 0; };
  Game.prototype.washType = function () { return this.washing ? this.washing.type : null; };

  Game.prototype.update = function (dt) {
    if (this.phase !== 'playing') return;
    this.timeLeft -= dt;

    // wash bottleneck: one item at a time
    if (!this.washing && this.washQueue.length) { this.washing = { type: this.washQueue.shift(), progress: 0 }; this._emit('washStart'); }
    if (this.washing) {
      this.washing.progress += dt / WASH_TIME;
      if (this.washing.progress >= 1) {
        const ty = this.washing.type;
        if (this.cleanStock[ty] < STOCK_CAP) this.cleanStock[ty]++;
        this.washing = null; this._emit('washed');
      }
    }

    // patience
    for (let i = 0; i < this.maxOrders; i++) {
      const o = this.slots[i]; if (!o) continue;
      if (o.fresh > 0) o.fresh -= dt;
      o.patience -= dt;
      if (o.patience <= 0) {
        this.slots[i] = null; this.hearts--; this._emit('fail');
        if (this.hearts <= 0) { this.phase = 'lost'; this._emit('lost'); return; }
      }
    }

    // spawn
    this.spawnT -= dt;
    const active = this.slots.slice(0, this.maxOrders).filter(Boolean).length;
    if (this.spawnT <= 0 && active < this.maxOrders) { this.spawnOrder(); this.spawnT = 1.6 + Math.random() * 2.0; }

    if (this.timeLeft <= 0) { this.timeLeft = 0; this.phase = 'lost'; this._emit('lost'); }
  };

  Game.prototype.stars = function () { return this.hearts >= 5 ? 3 : (this.hearts >= 3 ? 2 : 1); };

  global.Galley = global.Galley || {};
  global.Galley.Game = Game;
  global.Galley.ORDER_TYPES = TYPES;
  global.Galley.STOCK_CAP = STOCK_CAP;
  global.Galley.QUEUE_CAP = QUEUE_CAP;

})(window);
