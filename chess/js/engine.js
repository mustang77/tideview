/* ============================================================================
 * Grandmaster — chess rules engine
 * ----------------------------------------------------------------------------
 * Full legal move generation with castling, en passant, promotion, check /
 * checkmate / stalemate and the common draw rules. Mutable board with
 * make/unmake for speed (used by the AI and by perft self-tests). Validated
 * against known perft node counts.
 *
 * Encoding: board is Int8Array(64), index = rank*8 + file (a1 = 0, h1 = 7,
 * a8 = 56). White pieces +1..+6 (P N B R Q K), black -1..-6, empty 0.
 * side: +1 white to move, -1 black.  castle bits: 1 WK, 2 WQ, 4 BK, 8 BQ.
 * ==========================================================================*/
(function (global) {
  'use strict';

  const P = 1, N = 2, B = 3, R = 4, Q = 5, K = 6;
  const KN_D = [[1, 2], [2, 1], [2, -1], [1, -2], [-1, -2], [-2, -1], [-2, 1], [-1, 2]];
  const K_D = [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [1, -1], [-1, 1], [-1, -1]];
  const B_D = [[1, 1], [1, -1], [-1, 1], [-1, -1]];
  const R_D = [[1, 0], [-1, 0], [0, 1], [0, -1]];

  const file = (sq) => sq & 7, rank = (sq) => sq >> 3, sq = (f, r) => r * 8 + f;
  const onBoard = (f, r) => f >= 0 && f < 8 && r >= 0 && r < 8;

  function Board() {
    this.b = new Int8Array(64);
    this.side = 1;
    this.castle = 15;
    this.ep = -1;
    this.half = 0;
    this.full = 1;
    this.hist = [];      // undo stack
    this.reset();
  }

  Board.prototype.reset = function () { this.fromFEN('rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1'); };

  Board.prototype.fromFEN = function (fen) {
    const parts = fen.trim().split(/\s+/);
    this.b.fill(0);
    const map = { p: -P, n: -N, b: -B, r: -R, q: -Q, k: -K, P, N, B, R, Q, K };
    let r = 7, f = 0;
    for (const ch of parts[0]) {
      if (ch === '/') { r--; f = 0; }
      else if (ch >= '1' && ch <= '8') f += +ch;
      else { this.b[sq(f, r)] = map[ch]; f++; }
    }
    this.side = parts[1] === 'w' ? 1 : -1;
    this.castle = 0;
    if (parts[2].includes('K')) this.castle |= 1;
    if (parts[2].includes('Q')) this.castle |= 2;
    if (parts[2].includes('k')) this.castle |= 4;
    if (parts[2].includes('q')) this.castle |= 8;
    this.ep = (parts[3] && parts[3] !== '-') ? (parts[3].charCodeAt(0) - 97) + (+parts[3][1] - 1) * 8 : -1;
    this.half = parts[4] ? +parts[4] : 0;
    this.full = parts[5] ? +parts[5] : 1;
    this.hist = [];
  };

  Board.prototype.kingSquare = function (color) {
    const kc = K * color;
    for (let i = 0; i < 64; i++) if (this.b[i] === kc) return i;
    return -1;
  };

  // Is square `s` attacked by pieces of color `by` (+1 white / -1 black)?
  Board.prototype.attacked = function (s, by) {
    const b = this.b, f = file(s), r = rank(s);
    // pawns: a `by` pawn sits one rank toward its own side
    const pr = r - by;
    if (pr >= 0 && pr < 8) {
      if (f - 1 >= 0 && b[sq(f - 1, pr)] === P * by) return true;
      if (f + 1 < 8 && b[sq(f + 1, pr)] === P * by) return true;
    }
    // knights
    for (const [df, dr] of KN_D) { const nf = f + df, nr = r + dr; if (onBoard(nf, nr) && b[sq(nf, nr)] === N * by) return true; }
    // king
    for (const [df, dr] of K_D) { const nf = f + df, nr = r + dr; if (onBoard(nf, nr) && b[sq(nf, nr)] === K * by) return true; }
    // bishop / queen diagonals
    for (const [df, dr] of B_D) {
      let nf = f + df, nr = r + dr;
      while (onBoard(nf, nr)) { const pc = b[sq(nf, nr)]; if (pc) { if (pc === B * by || pc === Q * by) return true; break; } nf += df; nr += dr; }
    }
    // rook / queen lines
    for (const [df, dr] of R_D) {
      let nf = f + df, nr = r + dr;
      while (onBoard(nf, nr)) { const pc = b[sq(nf, nr)]; if (pc) { if (pc === R * by || pc === Q * by) return true; break; } nf += df; nr += dr; }
    }
    return false;
  };

  Board.prototype.inCheck = function (color) { return this.attacked(this.kingSquare(color), -color); };

  // Pseudo-legal moves for the side to move.
  Board.prototype.pseudoMoves = function () {
    const b = this.b, side = this.side, out = [];
    const add = (from, to, flag, promo) => out.push({ from, to, flag: flag || 0, promo: promo || 0 });
    for (let s = 0; s < 64; s++) {
      const pc = b[s]; if (pc === 0 || (pc > 0 ? 1 : -1) !== side) continue;
      const t = Math.abs(pc), f = file(s), r = rank(s);
      if (t === P) {
        const dir = side, startRank = side === 1 ? 1 : 6, lastRank = side === 1 ? 7 : 0;
        const r1 = r + dir;
        if (r1 >= 0 && r1 < 8 && b[sq(f, r1)] === 0) {
          if (r1 === lastRank) { for (const pr of [Q, R, B, N]) add(s, sq(f, r1), 5, pr); }
          else {
            add(s, sq(f, r1), 0);
            if (r === startRank && b[sq(f, r + 2 * dir)] === 0) add(s, sq(f, r + 2 * dir), 1);
          }
        }
        for (const df of [-1, 1]) {
          const nf = f + df; if (nf < 0 || nf > 7) continue;
          const to = sq(nf, r1); if (r1 < 0 || r1 > 7) continue;
          const tp = b[to];
          if (tp !== 0 && (tp > 0 ? 1 : -1) === -side) {
            if (r1 === lastRank) { for (const pr of [Q, R, B, N]) add(s, to, 5, pr); }
            else add(s, to, 0);
          } else if (to === this.ep) add(s, to, 2);
        }
      } else if (t === N) {
        for (const [df, dr] of KN_D) { const nf = f + df, nr = r + dr; if (!onBoard(nf, nr)) continue; const to = sq(nf, nr), tp = b[to]; if (tp === 0 || (tp > 0 ? 1 : -1) === -side) add(s, to, 0); }
      } else if (t === K) {
        for (const [df, dr] of K_D) { const nf = f + df, nr = r + dr; if (!onBoard(nf, nr)) continue; const to = sq(nf, nr), tp = b[to]; if (tp === 0 || (tp > 0 ? 1 : -1) === -side) add(s, to, 0); }
        // castling
        if (side === 1 && s === 4) {
          if ((this.castle & 1) && b[5] === 0 && b[6] === 0 && !this.attacked(4, -1) && !this.attacked(5, -1) && !this.attacked(6, -1)) add(4, 6, 3);
          if ((this.castle & 2) && b[3] === 0 && b[2] === 0 && b[1] === 0 && !this.attacked(4, -1) && !this.attacked(3, -1) && !this.attacked(2, -1)) add(4, 2, 4);
        } else if (side === -1 && s === 60) {
          if ((this.castle & 4) && b[61] === 0 && b[62] === 0 && !this.attacked(60, 1) && !this.attacked(61, 1) && !this.attacked(62, 1)) add(60, 62, 3);
          if ((this.castle & 8) && b[59] === 0 && b[58] === 0 && b[57] === 0 && !this.attacked(60, 1) && !this.attacked(59, 1) && !this.attacked(58, 1)) add(60, 58, 4);
        }
      } else {
        const dirs = t === B ? B_D : t === R ? R_D : K_D;
        for (const [df, dr] of dirs) {
          let nf = f + df, nr = r + dr;
          while (onBoard(nf, nr)) { const to = sq(nf, nr), tp = b[to]; if (tp === 0) add(s, to, 0); else { if ((tp > 0 ? 1 : -1) === -side) add(s, to, 0); break; } nf += df; nr += dr; }
        }
      }
    }
    return out;
  };

  Board.prototype.make = function (m) {
    const b = this.b, side = this.side;
    const u = { m, cap: 0, capSq: -1, castle: this.castle, ep: this.ep, half: this.half };
    const piece = b[m.from];
    b[m.from] = 0;
    // en passant capture
    if (m.flag === 2) { const capSq = m.to - side * 8; u.cap = b[capSq]; u.capSq = capSq; b[capSq] = 0; }
    else if (b[m.to] !== 0) { u.cap = b[m.to]; u.capSq = m.to; }
    // place piece (promotion)
    b[m.to] = m.flag === 5 ? m.promo * side : piece;
    // castling rook move
    if (m.flag === 3) { if (side === 1) { b[7] = 0; b[5] = R; } else { b[63] = 0; b[61] = -R; } }
    else if (m.flag === 4) { if (side === 1) { b[0] = 0; b[3] = R; } else { b[56] = 0; b[59] = -R; } }
    // castle rights
    if (Math.abs(piece) === K) this.castle &= side === 1 ? ~3 : ~12;
    if (m.from === 0 || m.to === 0) this.castle &= ~2;
    if (m.from === 7 || m.to === 7) this.castle &= ~1;
    if (m.from === 56 || m.to === 56) this.castle &= ~8;
    if (m.from === 63 || m.to === 63) this.castle &= ~4;
    // ep target
    this.ep = m.flag === 1 ? (m.from + side * 8) : -1;
    // clocks
    if (Math.abs(piece) === P || u.cap !== 0) this.half = 0; else this.half++;
    if (side === -1) this.full++;
    this.side = -side;
    this.hist.push(u);
  };

  Board.prototype.unmake = function () {
    const u = this.hist.pop(); if (!u) return;
    const b = this.b, m = u.m;
    this.side = -this.side; const side = this.side;
    const moved = m.flag === 5 ? P * side : b[m.to];
    b[m.from] = m.flag === 5 ? P * side : b[m.to];
    b[m.to] = 0;
    if (u.capSq >= 0) b[u.capSq] = u.cap;
    if (m.flag === 3) { if (side === 1) { b[7] = R; b[5] = 0; } else { b[63] = -R; b[61] = 0; } }
    else if (m.flag === 4) { if (side === 1) { b[0] = R; b[3] = 0; } else { b[56] = -R; b[59] = 0; } }
    this.castle = u.castle; this.ep = u.ep; this.half = u.half;
    if (side === -1) this.full--;
  };

  // Legal moves = pseudo-legal filtered so the mover isn't left in check.
  Board.prototype.legalMoves = function () {
    const side = this.side, out = [];
    for (const m of this.pseudoMoves()) {
      this.make(m);
      if (!this.inCheck(side)) out.push(m);
      this.unmake();
    }
    return out;
  };

  Board.prototype.status = function () {
    const moves = this.legalMoves();
    const chk = this.inCheck(this.side);
    if (moves.length === 0) return chk ? 'checkmate' : 'stalemate';
    if (this.half >= 100) return 'draw50';
    if (this.insufficient()) return 'insufficient';
    return chk ? 'check' : 'ongoing';
  };

  Board.prototype.insufficient = function () {
    let n = 0, minors = 0, other = false;
    for (let i = 0; i < 64; i++) { const t = Math.abs(this.b[i]); if (!t) continue; n++; if (t === B || t === N) minors++; else if (t !== K) other = true; }
    if (other) return false;
    return n <= 3 && minors <= 1; // K vs K, K+minor vs K
  };

  Board.prototype.perft = function (depth) {
    if (depth === 0) return 1;
    let nodes = 0;
    const side = this.side;
    for (const m of this.pseudoMoves()) {
      this.make(m);
      if (!this.inCheck(side)) nodes += this.perft(depth - 1);
      this.unmake();
    }
    return nodes;
  };

  global.Chess = global.Chess || {};
  global.Chess.Board = Board;
  global.Chess.SQ = { file, rank, sq };
  global.Chess.PIECE = { P, N, B, R, Q, K };

})(typeof window !== 'undefined' ? window : global);
