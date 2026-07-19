/* ============================================================================
 * Grandmaster — AI (negamax + alpha-beta + quiescence, iterative deepening)
 * ----------------------------------------------------------------------------
 * Time-budgeted search so it never freezes the UI. Evaluation is material +
 * piece-square tables. Move ordering (MVV-LVA + promotions) makes alpha-beta
 * cut hard. Difficulty = search time + a blunder chance on easier levels.
 * ==========================================================================*/
(function (global) {
  'use strict';
  const now = () => (global.performance && global.performance.now) ? global.performance.now() : Date.now();
  const VAL = [0, 100, 320, 330, 500, 900, 20000]; // by piece type index
  const MATE = 100000;

  // piece-square tables (white view, a1..h8). Encourage sensible development.
  const PST = {
    1: [0, 0, 0, 0, 0, 0, 0, 0, 5, 10, 10, -20, -20, 10, 10, 5, 5, -5, -10, 0, 0, -10, -5, 5, 0, 0, 0, 20, 20, 0, 0, 0, 5, 5, 10, 25, 25, 10, 5, 5, 10, 10, 20, 30, 30, 20, 10, 10, 50, 50, 50, 50, 50, 50, 50, 50, 0, 0, 0, 0, 0, 0, 0, 0],
    2: [-50, -40, -30, -30, -30, -30, -40, -50, -40, -20, 0, 5, 5, 0, -20, -40, -30, 5, 10, 15, 15, 10, 5, -30, -30, 0, 15, 20, 20, 15, 0, -30, -30, 5, 15, 20, 20, 15, 5, -30, -30, 0, 10, 15, 15, 10, 0, -30, -40, -20, 0, 0, 0, 0, -20, -40, -50, -40, -30, -30, -30, -30, -40, -50],
    3: [-20, -10, -10, -10, -10, -10, -10, -20, -10, 5, 0, 0, 0, 0, 5, -10, -10, 10, 10, 10, 10, 10, 10, -10, -10, 0, 10, 10, 10, 10, 0, -10, -10, 5, 5, 10, 10, 5, 5, -10, -10, 0, 5, 10, 10, 5, 0, -10, -10, 0, 0, 0, 0, 0, 0, -10, -20, -10, -10, -10, -10, -10, -10, -20],
    4: [0, 0, 0, 5, 5, 0, 0, 0, -5, 0, 0, 0, 0, 0, 0, -5, -5, 0, 0, 0, 0, 0, 0, -5, -5, 0, 0, 0, 0, 0, 0, -5, -5, 0, 0, 0, 0, 0, 0, -5, -5, 0, 0, 0, 0, 0, 0, -5, 5, 10, 10, 10, 10, 10, 10, 5, 0, 0, 0, 0, 0, 0, 0, 0],
    5: [-20, -10, -10, -5, -5, -10, -10, -20, -10, 0, 5, 0, 0, 0, 0, -10, -10, 5, 5, 5, 5, 5, 0, -10, 0, 0, 5, 5, 5, 5, 0, -5, -5, 0, 5, 5, 5, 5, 0, -5, -10, 0, 5, 5, 5, 5, 0, -10, -10, 0, 0, 0, 0, 0, 0, -10, -20, -10, -10, -5, -5, -10, -10, -20],
    6: [20, 30, 10, 0, 0, 10, 30, 20, 20, 20, 0, 0, 0, 0, 20, 20, -10, -20, -20, -20, -20, -20, -20, -10, -20, -30, -30, -40, -40, -30, -30, -20, -30, -40, -40, -50, -50, -40, -40, -30, -30, -40, -40, -50, -50, -40, -40, -30, -30, -40, -40, -50, -50, -40, -40, -30, -30, -40, -40, -50, -50, -40, -40, -30],
  };

  // Evaluation from White's perspective (centipawns).
  function evalWhite(b) {
    let s = 0;
    const board = b.b;
    for (let i = 0; i < 64; i++) {
      const pc = board[i]; if (!pc) continue;
      const t = Math.abs(pc);
      if (pc > 0) s += VAL[t] + PST[t][i];
      else s -= VAL[t] + PST[t][63 - i];
    }
    return s;
  }

  function orderMoves(b, moves) {
    const board = b.b;
    for (const m of moves) {
      let sc = 0;
      const victim = m.flag === 2 ? 1 : Math.abs(board[m.to]);
      if (victim) sc = 10 * VAL[victim] - VAL[Math.abs(board[m.from])];
      if (m.flag === 5) sc += VAL[m.promo];
      m._s = sc;
    }
    moves.sort((a, b2) => b2._s - a._s);
    return moves;
  }

  function quiesce(b, alpha, beta) {
    let stand = b.side * evalWhite(b);
    if (stand >= beta) return beta;
    if (stand > alpha) alpha = stand;
    const caps = [];
    for (const m of b.pseudoMoves()) {
      if (m.flag === 2 || m.flag === 5 || b.b[m.to] !== 0) caps.push(m);
    }
    orderMoves(b, caps);
    const side = b.side;
    for (const m of caps) {
      b.make(m);
      if (b.inCheck(side)) { b.unmake(); continue; }
      const v = -quiesce(b, -beta, -alpha);
      b.unmake();
      if (v >= beta) return beta;
      if (v > alpha) alpha = v;
    }
    return alpha;
  }

  function negamax(b, depth, alpha, beta, ply, ctrl) {
    if ((ctrl.nodes++ & 2047) === 0 && now() > ctrl.deadline) { ctrl.stop = true; return 0; }
    if (depth <= 0) return quiesce(b, alpha, beta);
    const moves = b.legalMoves();
    if (moves.length === 0) return b.inCheck(b.side) ? -MATE + ply : 0;
    orderMoves(b, moves);
    let best = -Infinity;
    for (const m of moves) {
      b.make(m);
      const v = -negamax(b, depth - 1, -beta, -alpha, ply + 1, ctrl);
      b.unmake();
      if (ctrl.stop) return 0;
      if (v > best) best = v;
      if (best > alpha) alpha = best;
      if (alpha >= beta) break;
    }
    return best;
  }

  // Choose a move. opts: { timeMs, maxDepth, randomness }
  function bestMove(b, opts) {
    opts = opts || {};
    const timeMs = opts.timeMs || 500, maxDepth = opts.maxDepth || 4, randomness = opts.randomness || 0;
    const rootMoves = b.legalMoves();
    if (rootMoves.length === 0) return null;
    orderMoves(b, rootMoves);
    let bestMove = rootMoves[0], bestScore = 0;
    const ctrl = { nodes: 0, deadline: now() + timeMs, stop: false };

    for (let depth = 1; depth <= maxDepth; depth++) {
      let alpha = -Infinity, beta = Infinity, localBest = null, localScore = -Infinity;
      const scored = [];
      for (const m of rootMoves) {
        b.make(m);
        const v = -negamax(b, depth - 1, -beta, -alpha, 1, ctrl);
        b.unmake();
        if (ctrl.stop) break;
        scored.push({ m, v });
        if (v > localScore) { localScore = v; localBest = m; }
        if (v > alpha) alpha = v;
      }
      if (ctrl.stop && depth > 1) break;         // keep previous depth's result
      if (localBest) { bestMove = localBest; bestScore = localScore; }
      // reorder root by score for the next iteration (better pruning)
      if (scored.length === rootMoves.length) { scored.sort((a, c) => c.v - a.v); for (let i = 0; i < scored.length; i++) rootMoves[i] = scored[i].m; }
      if (Math.abs(bestScore) > MATE - 1000) break; // found forced mate
      if (ctrl.stop) break;
    }

    // blunder chance on easier levels: sometimes pick a random legal move
    if (randomness > 0 && Math.random() < randomness) {
      return rootMoves[Math.floor(Math.random() * rootMoves.length)];
    }
    return bestMove;
  }

  global.Chess = global.Chess || {};
  global.Chess.AI = { bestMove, evalWhite };

})(typeof window !== 'undefined' ? window : global);
