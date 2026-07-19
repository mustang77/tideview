/* ============================================================================
 * Galley Rush — game logic
 * ----------------------------------------------------------------------------
 * The steward's shift: wash each dirty dish at the sink, stack it in the rack,
 * then run a full rack through the dishwasher. Clear all the dishes before the
 * shift clock runs out. Time budget scales with the number of dishes.
 * ==========================================================================*/
(function (global) {
  'use strict';

  const SCRUB_TIME = 0.9;   // seconds of scrubbing per dish
  const CYCLE_TIME = 3.2;   // dishwasher cycle
  const PER_DISH = 4.2;     // seconds of shift time granted per dish

  function Game() {
    this.level = 0;
    this.reset();
  }

  Game.prototype.levels = function (i) {
    // dishes grows each shift; rack size steps up; time = dishes * PER_DISH
    const dishes = 10 + i * 4;
    const rack = i < 2 ? 5 : (i < 4 ? 6 : 8);
    return { dishes, rack, time: Math.round(dishes * PER_DISH) };
  };

  Game.prototype.reset = function () {
    const L = this.levels(this.level);
    this.dishes = L.dishes; this.rackSize = L.rack; this.timeLimit = L.time;
    this.timeLeft = L.time;
    this.dirty = L.dishes;        // dishes not yet washed
    this.hand = null;             // null | { stage:'dirty'|'clean', scrub:0 }
    this.rack = 0;                // washed dishes waiting in the rack
    this.washer = { running: false, cycle: 0, load: 0 };
    this.done = 0;                // fully cleaned (through the dishwasher)
    this.phase = 'briefing';      // briefing | playing | won | lost
    this.station = 'idle';        // where the steward is working
    this.stationT = 0;            // time to hold a transient station pose
    this.events = [];             // one-shot cues for the view/audio layer
  };

  Game.prototype.start = function () { this.phase = 'playing'; this.station = 'sink'; };

  Game.prototype.nextLevel = function () { this.level++; this.reset(); };
  Game.prototype.retry = function () { this.reset(); };

  Game.prototype._emit = function (e) { this.events.push(e); };

  // Grab a dirty dish (if hands free) — first press of WASH.
  Game.prototype.grab = function () {
    if (this.phase !== 'playing') return;
    if (this.hand || this.dirty <= 0) return;
    this.hand = { stage: 'dirty', scrub: 0 };
    this.dirty--;
    this.station = 'sink'; this._emit('pickup');
  };

  // Hold-to-scrub. Returns true while actively scrubbing.
  Game.prototype.scrub = function (dt) {
    if (this.phase !== 'playing') return false;
    if (!this.hand) { this.grab(); return !!this.hand; }
    if (this.hand.stage !== 'dirty') return false;
    this.station = 'sink';
    this.hand.scrub += dt / SCRUB_TIME;
    this._emit('scrub');
    if (this.hand.scrub >= 1) { this.hand.stage = 'clean'; this.hand.scrub = 1; this._emit('clean'); }
    return true;
  };

  // Place the washed dish into the rack.
  Game.prototype.toRack = function () {
    if (this.phase !== 'playing') return false;
    if (!this.hand || this.hand.stage !== 'clean') return false;
    if (this.rack >= this.rackSize) return false;
    this.rack++; this.hand = null;
    this.station = 'rack'; this.stationT = 0.5; this._emit('rack');
    return true;
  };

  // Load the rack into the dishwasher and run a cycle.
  Game.prototype.run = function () {
    if (this.phase !== 'playing') return false;
    if (this.washer.running || this.rack <= 0) return false;
    this.washer.running = true; this.washer.cycle = CYCLE_TIME; this.washer.load = this.rack;
    this.rack = 0; this.station = 'washer'; this.stationT = 0.6; this._emit('run');
    return true;
  };

  Game.prototype.canRack = function () { return this.hand && this.hand.stage === 'clean' && this.rack < this.rackSize; };
  Game.prototype.canRun = function () { return !this.washer.running && this.rack > 0; };
  Game.prototype.rackFull = function () { return this.rack >= this.rackSize; };

  Game.prototype.update = function (dt) {
    if (this.phase !== 'playing') return;
    this.timeLeft -= dt;
    if (this.stationT > 0) { this.stationT -= dt; if (this.stationT <= 0 && this.station !== 'washer') this.station = 'sink'; }

    if (this.washer.running) {
      this.washer.cycle -= dt;
      if (this.washer.cycle <= 0) {
        this.done += this.washer.load; this.washer.load = 0; this.washer.running = false;
        this._emit('cycleDone');
        if (this.station === 'washer') this.station = 'sink';
      }
    }

    if (this.done >= this.dishes) { this.phase = 'won'; this._emit('won'); return; }
    if (this.timeLeft <= 0) { this.timeLeft = 0; this.phase = 'lost'; this._emit('lost'); }
  };

  // Stars for a completed shift, by time remaining.
  Game.prototype.stars = function () {
    const frac = this.timeLeft / this.timeLimit;
    return frac > 0.4 ? 3 : (frac > 0.15 ? 2 : 1);
  };

  global.Galley = global.Galley || {};
  global.Galley.Game = Game;
  global.Galley.SCRUB_TIME = SCRUB_TIME;

})(window);
