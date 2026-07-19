/* ============================================================================
 * Break & Run — sound
 * ----------------------------------------------------------------------------
 * Every effect is synthesized with the Web Audio API — no audio files — so it
 * works inside a sandboxed page with no network access. The physics layer
 * calls ball()/rail()/pocket(); the game calls cue() and win(). The context is
 * created lazily and resumed on the first user gesture (autoplay policy).
 * ==========================================================================*/
(function (global) {
  'use strict';

  function Audio() {
    this.ctx = null;
    this.master = null;
    this.enabled = true;
    this._recent = [];   // timestamps to throttle rapid ball clicks
  }

  Audio.prototype.ensure = function () {
    if (this.ctx) { if (this.ctx.state === 'suspended') this.ctx.resume(); return; }
    try {
      const AC = global.AudioContext || global.webkitAudioContext;
      if (!AC) return;
      this.ctx = new AC();
      this.master = this.ctx.createGain();
      this.master.gain.value = 0.9;
      this.master.connect(this.ctx.destination);
    } catch (e) { this.ctx = null; }
  };

  Audio.prototype._noiseBuffer = function (dur) {
    const n = Math.floor(this.ctx.sampleRate * dur);
    const buf = this.ctx.createBuffer(1, n, this.ctx.sampleRate);
    const d = buf.getChannelData(0);
    let seed = 22222;
    for (let i = 0; i < n; i++) { seed = (seed * 1103515245 + 12345) & 0x7fffffff; d[i] = (seed / 0x3fffffff) - 1; }
    return buf;
  };

  // A short pitched blip (sine/triangle) with an exponential decay.
  Audio.prototype._ping = function (freq, dur, gain, type, slideTo) {
    if (!this.ctx) return;
    const t = this.ctx.currentTime;
    const o = this.ctx.createOscillator();
    const g = this.ctx.createGain();
    o.type = type || 'triangle';
    o.frequency.setValueAtTime(freq, t);
    if (slideTo) o.frequency.exponentialRampToValueAtTime(slideTo, t + dur);
    g.gain.setValueAtTime(0.0001, t);
    g.gain.exponentialRampToValueAtTime(Math.max(0.001, gain), t + 0.004);
    g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    o.connect(g); g.connect(this.master);
    o.start(t); o.stop(t + dur + 0.02);
  };

  // A filtered noise burst (the "clack"/"thud" transient).
  Audio.prototype._burst = function (dur, gain, filterFreq, q) {
    if (!this.ctx) return;
    const t = this.ctx.currentTime;
    const src = this.ctx.createBufferSource();
    src.buffer = this._noiseBuffer(dur);
    const f = this.ctx.createBiquadFilter();
    f.type = 'bandpass'; f.frequency.value = filterFreq; f.Q.value = q || 1;
    const g = this.ctx.createGain();
    g.gain.setValueAtTime(Math.max(0.001, gain), t);
    g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    src.connect(f); f.connect(g); g.connect(this.master);
    src.start(t); src.stop(t + dur + 0.02);
  };

  // ---- public effects -----------------------------------------------------
  Audio.prototype.ball = function (v, cueInvolved) {
    if (!this.enabled || !this.ctx || v < 0.12) return;
    // throttle: no more than ~6 clicks per 55ms (a break makes many at once)
    const now = this.ctx.currentTime;
    this._recent = this._recent.filter(t => now - t < 0.055);
    if (this._recent.length > 6) return;
    this._recent.push(now);
    const vol = Math.min(0.5, 0.06 + v * 0.14);
    const f = 1500 + Math.min(1600, v * 900) + (cueInvolved ? 300 : 0);
    this._burst(0.03, vol, f, 1.2);
    this._ping(f * 1.3, 0.035, vol * 0.5, 'triangle');
  };

  Audio.prototype.rail = function (v) {
    if (!this.enabled || !this.ctx || v < 0.18) return;
    const vol = Math.min(0.35, 0.05 + v * 0.1);
    this._burst(0.05, vol, 320, 0.8);
    this._ping(180 + v * 60, 0.06, vol * 0.6, 'sine');
  };

  Audio.prototype.pocket = function (isCue) {
    if (!this.enabled || !this.ctx) return;
    // soft "plunk" descending into the pocket
    this._ping(520, 0.18, 0.22, 'sine', 150);
    this._burst(0.12, 0.14, 240, 0.7);
    if (!isCue) setTimeout(() => this._burst(0.06, 0.1, 160, 0.6), 70);
  };

  Audio.prototype.cue = function (power) {
    if (!this.enabled || !this.ctx) return;
    const vol = 0.12 + power * 0.24;
    this._burst(0.035, vol, 900 + power * 500, 1.0);
    this._ping(140 + power * 60, 0.05, vol * 0.7, 'sine', 90);
  };

  Audio.prototype.win = function () {
    if (!this.enabled || !this.ctx) return;
    const notes = [523, 659, 784, 1047];
    notes.forEach((n, i) => setTimeout(() => this._ping(n, 0.28, 0.22, 'triangle'), i * 110));
  };

  Audio.prototype.tick = function () { // low tick when the shot clock is running out
    if (!this.enabled || !this.ctx) return;
    this._ping(880, 0.05, 0.09, 'square');
  };

  Audio.prototype.foul = function () {
    if (!this.enabled || !this.ctx) return;
    this._ping(300, 0.18, 0.16, 'sawtooth', 150);
    this._ping(220, 0.22, 0.14, 'sawtooth', 120);
  };

  global.Pool = global.Pool || {};
  global.Pool.Audio = Audio;

})(window);
