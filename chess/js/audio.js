/* Grandmaster — sound (synthesized) */
(function (global) {
  'use strict';
  function Audio() { this.ctx = null; this.master = null; this.enabled = true; }
  Audio.prototype.ensure = function () {
    if (this.ctx) { if (this.ctx.state === 'suspended') this.ctx.resume(); return; }
    try { const AC = global.AudioContext || global.webkitAudioContext; if (!AC) return; this.ctx = new AC(); this.master = this.ctx.createGain(); this.master.gain.value = 0.85; this.master.connect(this.ctx.destination); } catch (e) { this.ctx = null; }
  };
  Audio.prototype._noise = function (d) { const n = Math.floor(this.ctx.sampleRate * d), b = this.ctx.createBuffer(1, n, this.ctx.sampleRate), a = b.getChannelData(0); let s = 3; for (let i = 0; i < n; i++) { s = (s * 1103515245 + 12345) & 0x7fffffff; a[i] = (s / 0x3fffffff) - 1; } return b; };
  Audio.prototype._ping = function (f, d, g, type, slide) { if (!this.ctx) return; const t = this.ctx.currentTime, o = this.ctx.createOscillator(), gg = this.ctx.createGain(); o.type = type || 'sine'; o.frequency.setValueAtTime(f, t); if (slide) o.frequency.exponentialRampToValueAtTime(slide, t + d); gg.gain.setValueAtTime(0.0001, t); gg.gain.exponentialRampToValueAtTime(Math.max(0.001, g), t + 0.006); gg.gain.exponentialRampToValueAtTime(0.0001, t + d); o.connect(gg); gg.connect(this.master); o.start(t); o.stop(t + d + 0.02); };
  Audio.prototype._thock = function (d, g, f) { if (!this.ctx) return; const t = this.ctx.currentTime, s = this.ctx.createBufferSource(); s.buffer = this._noise(d); const fl = this.ctx.createBiquadFilter(); fl.type = 'lowpass'; fl.frequency.value = f || 500; const gg = this.ctx.createGain(); gg.gain.setValueAtTime(g, t); gg.gain.exponentialRampToValueAtTime(0.0001, t + d); s.connect(fl); fl.connect(gg); gg.connect(this.master); s.start(t); s.stop(t + d + 0.02); };
  Audio.prototype.setEnabled = function (on) { this.enabled = on; if (this.master) this.master.gain.value = on ? 0.85 : 0; };
  Audio.prototype.move = function () { if (this.enabled) { this._thock(0.08, 0.25, 700); this._ping(240, 0.05, 0.05, 'sine'); } };
  Audio.prototype.capture = function () { if (this.enabled) { this._thock(0.12, 0.35, 900); this._ping(180, 0.09, 0.09, 'triangle', 120); } };
  Audio.prototype.castle = function () { if (this.enabled) { this._thock(0.09, 0.25, 600); setTimeout(() => this._thock(0.09, 0.22, 600), 90); } };
  Audio.prototype.check = function () { if (this.enabled) { this._ping(880, 0.14, 0.12, 'square'); this._ping(1320, 0.16, 0.07, 'square'); } };
  Audio.prototype.promote = function () { if (this.enabled) [660, 880, 1100].forEach((n, i) => setTimeout(() => this._ping(n, 0.14, 0.1, 'triangle'), i * 70)); };
  Audio.prototype.win = function () { if (this.enabled) [523, 659, 784, 1047].forEach((n, i) => setTimeout(() => this._ping(n, 0.3, 0.18, 'triangle'), i * 120)); };
  Audio.prototype.lose = function () { if (this.enabled) [440, 349, 262].forEach((n, i) => setTimeout(() => this._ping(n, 0.34, 0.16, 'sawtooth'), i * 150)); };
  Audio.prototype.ui = function () { if (this.enabled) this._ping(600, 0.05, 0.06, 'triangle'); };
  global.Chess = global.Chess || {}; global.Chess.Audio = Audio;
})(window);
