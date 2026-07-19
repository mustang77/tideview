/* ============================================================================
 * Deck & Horizon — sound (synthesized, no asset files)
 * ==========================================================================*/
(function (global) {
  'use strict';
  function Audio() { this.ctx = null; this.master = null; this.enabled = true; this._amb = null; this._stepT = 0; }

  Audio.prototype.ensure = function () {
    if (this.ctx) { if (this.ctx.state === 'suspended') this.ctx.resume(); return; }
    try {
      const AC = global.AudioContext || global.webkitAudioContext; if (!AC) return;
      this.ctx = new AC();
      this.master = this.ctx.createGain(); this.master.gain.value = 0.85; this.master.connect(this.ctx.destination);
      this._startAmbient();
    } catch (e) { this.ctx = null; }
  };

  Audio.prototype._noiseBuf = function (dur) {
    const n = Math.floor(this.ctx.sampleRate * dur), b = this.ctx.createBuffer(1, n, this.ctx.sampleRate), d = b.getChannelData(0);
    let s = 9999; for (let i = 0; i < n; i++) { s = (s * 1103515245 + 12345) & 0x7fffffff; d[i] = (s / 0x3fffffff) - 1; }
    return b;
  };

  // Continuous ocean wash: looping noise through a lowpass whose cutoff and
  // gain swell slowly like waves.
  Audio.prototype._startAmbient = function () {
    const ctx = this.ctx;
    const src = ctx.createBufferSource(); src.buffer = this._noiseBuf(3); src.loop = true;
    const lp = ctx.createBiquadFilter(); lp.type = 'lowpass'; lp.frequency.value = 600;
    const g = ctx.createGain(); g.gain.value = 0.12;
    src.connect(lp); lp.connect(g); g.connect(this.master); src.start();
    // slow swell LFO
    const lfo = ctx.createOscillator(); lfo.frequency.value = 0.14;
    const lg = ctx.createGain(); lg.gain.value = 0.06;
    lfo.connect(lg); lg.connect(g.gain);
    const lfo2 = ctx.createOscillator(); lfo2.frequency.value = 0.09;
    const lg2 = ctx.createGain(); lg2.gain.value = 240;
    lfo2.connect(lg2); lg2.connect(lp.frequency);
    lfo.start(); lfo2.start();
    this._amb = { g };
  };

  Audio.prototype._ping = function (f, dur, gain, type, slideTo) {
    if (!this.ctx) return; const t = this.ctx.currentTime;
    const o = this.ctx.createOscillator(), g = this.ctx.createGain();
    o.type = type || 'sine'; o.frequency.setValueAtTime(f, t);
    if (slideTo) o.frequency.exponentialRampToValueAtTime(slideTo, t + dur);
    g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(Math.max(0.001, gain), t + 0.01);
    g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    o.connect(g); g.connect(this.master); o.start(t); o.stop(t + dur + 0.02);
  };
  Audio.prototype._burst = function (dur, gain, freq, q, type) {
    if (!this.ctx) return; const t = this.ctx.currentTime;
    const s = this.ctx.createBufferSource(); s.buffer = this._noiseBuf(dur);
    const f = this.ctx.createBiquadFilter(); f.type = type || 'bandpass'; f.frequency.value = freq; f.Q.value = q || 1;
    const g = this.ctx.createGain(); g.gain.setValueAtTime(Math.max(0.001, gain), t); g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    s.connect(f); f.connect(g); g.connect(this.master); s.start(t); s.stop(t + dur + 0.02);
  };

  Audio.prototype.setEnabled = function (on) { this.enabled = on; if (this.master) this.master.gain.value = on ? 0.85 : 0; };

  Audio.prototype.footstep = function () { if (!this.enabled) return; this._burst(0.06, 0.10, 240, 0.8, 'lowpass'); };
  Audio.prototype.bell = function () {
    if (!this.enabled) return;
    this._ping(1050, 1.4, 0.28, 'sine'); this._ping(1580, 1.2, 0.14, 'sine'); this._ping(2100, 0.9, 0.08, 'sine');
    setTimeout(() => { this._ping(1050, 1.2, 0.22, 'sine'); this._ping(1580, 1.0, 0.11, 'sine'); }, 320);
  };
  Audio.prototype.splash = function () { if (!this.enabled) return; this._burst(0.4, 0.3, 900, 0.6, 'lowpass'); this._burst(0.25, 0.2, 2200, 0.5, 'highpass'); };
  Audio.prototype.gull = function () {
    if (!this.enabled) return;
    const t0 = this.ctx ? this.ctx.currentTime : 0;
    for (let i = 0; i < 3; i++) setTimeout(() => this._ping(1200 + i * 60, 0.16, 0.06, 'sawtooth', 900), i * 190);
  };
  Audio.prototype.ui = function () { if (!this.enabled) return; this._ping(660, 0.06, 0.08, 'triangle'); };

  global.Cruise = global.Cruise || {};
  global.Cruise.Audio = Audio;
})(window);
