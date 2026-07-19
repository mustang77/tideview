/* ============================================================================
 * Galley Rush — sound (synthesized)
 * ==========================================================================*/
(function (global) {
  'use strict';
  function Audio() { this.ctx = null; this.master = null; this.enabled = true; this._hum = null; }
  Audio.prototype.ensure = function () {
    if (this.ctx) { if (this.ctx.state === 'suspended') this.ctx.resume(); return; }
    try { const AC = global.AudioContext || global.webkitAudioContext; if (!AC) return;
      this.ctx = new AC(); this.master = this.ctx.createGain(); this.master.gain.value = 0.8; this.master.connect(this.ctx.destination);
    } catch (e) { this.ctx = null; }
  };
  Audio.prototype._noise = function (d) { const n = Math.floor(this.ctx.sampleRate * d), b = this.ctx.createBuffer(1, n, this.ctx.sampleRate), a = b.getChannelData(0); let s = 7; for (let i = 0; i < n; i++) { s = (s * 1103515245 + 12345) & 0x7fffffff; a[i] = (s / 0x3fffffff) - 1; } return b; };
  Audio.prototype._ping = function (f, d, g, type, slide) { if (!this.ctx) return; const t = this.ctx.currentTime, o = this.ctx.createOscillator(), gg = this.ctx.createGain(); o.type = type || 'sine'; o.frequency.setValueAtTime(f, t); if (slide) o.frequency.exponentialRampToValueAtTime(slide, t + d); gg.gain.setValueAtTime(0.0001, t); gg.gain.exponentialRampToValueAtTime(Math.max(0.001, g), t + 0.008); gg.gain.exponentialRampToValueAtTime(0.0001, t + d); o.connect(gg); gg.connect(this.master); o.start(t); o.stop(t + d + 0.02); };
  Audio.prototype._burst = function (d, g, f, q, type) { if (!this.ctx) return; const t = this.ctx.currentTime, s = this.ctx.createBufferSource(); s.buffer = this._noise(d); const fl = this.ctx.createBiquadFilter(); fl.type = type || 'bandpass'; fl.frequency.value = f; fl.Q.value = q || 1; const gg = this.ctx.createGain(); gg.gain.setValueAtTime(Math.max(0.001, g), t); gg.gain.exponentialRampToValueAtTime(0.0001, t + d); s.connect(fl); fl.connect(gg); gg.connect(this.master); s.start(t); s.stop(t + d + 0.02); };

  Audio.prototype.setEnabled = function (on) { this.enabled = on; if (this.master) this.master.gain.value = on ? 0.8 : 0; };
  Audio.prototype.scrub = function () { if (this.enabled) this._burst(0.09, 0.09, 2600, 0.6, 'highpass'); };
  Audio.prototype.pickup = function () { if (this.enabled) this._ping(420, 0.08, 0.08, 'triangle', 620); };
  Audio.prototype.clink = function () { if (this.enabled) { this._ping(1600, 0.12, 0.12, 'sine'); this._ping(2300, 0.09, 0.06, 'sine'); } };
  Audio.prototype.ding = function () { if (this.enabled) { this._ping(880, 0.18, 0.16, 'sine'); this._ping(1320, 0.22, 0.12, 'sine'); } };
  Audio.prototype.startHum = function () {
    if (!this.enabled || !this.ctx || this._hum) return;
    const o = this.ctx.createOscillator(), g = this.ctx.createGain(); o.type = 'sawtooth'; o.frequency.value = 90;
    const lp = this.ctx.createBiquadFilter(); lp.type = 'lowpass'; lp.frequency.value = 300; g.gain.value = 0.06;
    o.connect(lp); lp.connect(g); g.connect(this.master); o.start(); this._hum = { o, g };
  };
  Audio.prototype.stopHum = function () { if (this._hum) { try { this._hum.o.stop(); } catch (e) {} this._hum = null; } };
  Audio.prototype.win = function () { if (!this.enabled) return; [523, 659, 784, 1047].forEach((n, i) => setTimeout(() => this._ping(n, 0.3, 0.2, 'triangle'), i * 120)); };
  Audio.prototype.lose = function () { if (!this.enabled) return; [440, 349, 262].forEach((n, i) => setTimeout(() => this._ping(n, 0.35, 0.18, 'sawtooth'), i * 160)); };
  Audio.prototype.tick = function () { if (this.enabled) this._ping(1000, 0.05, 0.08, 'square'); };
  Audio.prototype.ui = function () { if (this.enabled) this._ping(660, 0.05, 0.07, 'triangle'); };

  global.Galley = global.Galley || {};
  global.Galley.Audio = Audio;
})(window);
