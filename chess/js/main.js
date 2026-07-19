/* ============================================================================
 * Grandmaster — game flow, input, HUD
 * ==========================================================================*/
(function () {
  'use strict';
  const C = window.Chess;
  const canvas = document.getElementById('gl');
  const view = new C.BoardView(canvas);
  const board = new C.Board();
  const audio = new C.Audio();
  const el = (id) => document.getElementById(id);

  const state = {
    mode: 'ai',            // 'ai' | '2p'
    human: 1,              // human color when vs AI (1 white / -1 black)
    difficulty: 'medium',
    selected: -1,
    targets: [],           // legal moves from selected
    last: [null, null],
    over: false,
    thinking: false,
    pendingPromo: null,    // {from,to,moves}
  };
  const DIFF = { easy: { timeMs: 150, maxDepth: 2, randomness: 0.28 }, medium: { timeMs: 550, maxDepth: 4, randomness: 0.04 }, hard: { timeMs: 1200, maxDepth: 6, randomness: 0 } };
  const GLYPH = { w: { 1: '♙', 2: '♘', 3: '♗', 4: '♖', 5: '♕', 6: '♔' }, b: { 1: '♟', 2: '♞', 3: '♝', 4: '♜', 5: '♛', 6: '♚' } };

  window.addEventListener('resize', () => view.resize());
  window.addEventListener('orientationchange', () => setTimeout(() => view.resize(), 250));

  function newGame() {
    board.reset();
    state.selected = -1; state.targets = []; state.last = [null, null]; state.over = false; state.thinking = false; state.pendingPromo = null;
    view.flip = (state.mode === 'ai' && state.human === -1);
    view.cam.az = view.flip ? -Math.PI / 2 : Math.PI / 2;
    view.setPosition(board.b);
    refreshHighlights(); updateHUD();
    maybeAI();
  }

  function checkSquareIfAny() { return board.inCheck(board.side) ? board.kingSquare(board.side) : null; }
  function refreshHighlights() {
    view.highlight(state.selected >= 0 ? state.selected : null, state.selected >= 0 ? state.targets : null, state.last, checkSquareIfAny());
  }

  function humanToMove() { return !state.over && !state.thinking && !view.animating() && (state.mode === '2p' || board.side === state.human); }

  function legalFrom(sq) {
    return board.legalMoves().filter(m => m.from === sq).map(m => ({ to: m.to, cap: (board.b[m.to] !== 0 || m.flag === 2), move: m }));
  }

  function onPick(sq) {
    if (!humanToMove() || sq < 0) return;
    const pc = board.b[sq];
    const mine = pc !== 0 && (pc > 0 ? 1 : -1) === board.side;
    if (state.selected >= 0) {
      const hits = state.targets.filter(t => t.to === sq);
      if (hits.length) { chooseAndMove(state.selected, sq, hits.map(h => h.move)); return; }
      if (mine) { selectSquare(sq); return; }
      state.selected = -1; state.targets = []; refreshHighlights(); return;
    }
    if (mine) selectSquare(sq);
  }

  function selectSquare(sq) {
    state.selected = sq; state.targets = legalFrom(sq); audio.ensure(); audio.ui(); refreshHighlights();
  }

  function chooseAndMove(from, to, moves) {
    if (moves.length > 1) { // promotion — ask which piece
      state.pendingPromo = { from, to, moves };
      el('promoPick').classList.add('show');
      const side = board.side > 0 ? 'w' : 'b';
      ['5', '4', '3', '2'].forEach(t => { el('promo-' + t).textContent = GLYPH[side][+t]; });
      return;
    }
    applyMove(moves[0]);
  }

  function applyMove(m) {
    const side = board.side, color = side > 0 ? 'w' : 'b';
    let captureSq = null;
    if (m.flag === 2) captureSq = m.to - side * 8;
    else if (board.b[m.to] !== 0) captureSq = m.to;
    const castle = m.flag === 3 ? 'K' : m.flag === 4 ? 'Q' : null;
    const promo = m.flag === 5 ? m.promo : null;
    const wasCapture = captureSq != null;

    board.make(m);
    state.selected = -1; state.targets = []; state.last = [m.from, m.to];
    view.highlight(null, null, state.last, null);
    audio.ensure();
    if (promo) audio.promote(); else if (castle) audio.castle(); else if (wasCapture) audio.capture(); else audio.move();

    view.applyMove(m.from, m.to, color, { captureSq, castle, promo }, () => {
      // after animation completes
      const st = board.status();
      if (st === 'check') audio.check();
      refreshHighlights(); updateHUD();
      if (st === 'checkmate' || st === 'stalemate' || st === 'draw50' || st === 'insufficient') { endGame(st); return; }
      maybeAI();
    });
    updateHUD();
  }

  function maybeAI() {
    if (state.mode !== 'ai' || state.over) return;
    if (board.side === state.human) return;
    state.thinking = true; updateHUD();
    setTimeout(() => {
      const m = C.AI.bestMove(board, DIFF[state.difficulty]);
      state.thinking = false;
      if (!m) { endGame(board.status()); return; }
      applyMove(m);
    }, 220);
  }

  function endGame(st) {
    state.over = true;
    let title = 'Game Over', sub = '';
    const humanWon = () => (state.mode === 'ai') && ((board.side === state.human)); // side to move is the one checkmated
    if (st === 'checkmate') {
      const loser = board.side; // side to move has no moves = loser
      const winner = -loser;
      const wName = winner === 1 ? 'White' : 'Black';
      title = 'Checkmate!'; sub = wName + ' wins.';
      if (state.mode === 'ai') { if (winner === state.human) { audio.win(); title = '🏆 You win!'; } else { audio.lose(); title = 'Checkmate'; sub = 'The computer wins — rematch?'; } }
      else audio.win();
    } else if (st === 'stalemate') { title = 'Stalemate'; sub = "It's a draw."; }
    else if (st === 'draw50') { title = 'Draw'; sub = '50-move rule.'; }
    else if (st === 'insufficient') { title = 'Draw'; sub = 'Insufficient material.'; }
    el('resultTitle').textContent = title; el('resultSub').textContent = sub;
    el('result').classList.add('show'); updateHUD();
  }

  function updateHUD() {
    const side = board.side, chk = board.inCheck(side);
    let turnTxt;
    if (state.over) turnTxt = 'Game over';
    else if (state.thinking) turnTxt = 'Computer is thinking…';
    else turnTxt = (side === 1 ? 'White' : 'Black') + ' to move' + (chk ? ' — Check!' : '');
    el('turn').textContent = turnTxt;
    el('turn').classList.toggle('check', chk && !state.over);
    // captured trays (missing pieces)
    const cnt = { w: {}, b: {} };
    for (let t = 1; t <= 6; t++) { cnt.w[t] = 0; cnt.b[t] = 0; }
    for (let i = 0; i < 64; i++) { const pc = board.b[i]; if (!pc) continue; if (pc > 0) cnt.w[pc]++; else cnt.b[-pc]++; }
    const START = { 1: 8, 2: 2, 3: 2, 4: 2, 5: 1, 6: 1 };
    let capByWhite = '', capByBlack = '';
    for (let t = 5; t >= 1; t--) { for (let k = 0; k < START[t] - cnt.b[t]; k++) capByWhite += GLYPH.b[t]; for (let k = 0; k < START[t] - cnt.w[t]; k++) capByBlack += GLYPH.w[t]; }
    el('capTop').textContent = view.flip ? capByWhite : capByBlack;
    el('capBot').textContent = view.flip ? capByBlack : capByWhite;
  }

  // ---- input: tap to select/move, drag to orbit, pinch/wheel zoom ----
  const pointers = new Map(); let orbitLast = null, pinchLast = null, downPt = null, moved = false;
  canvas.addEventListener('pointerdown', (e) => {
    canvas.setPointerCapture(e.pointerId); pointers.set(e.pointerId, { x: e.clientX, y: e.clientY });
    if (pointers.size === 1) { downPt = { x: e.clientX, y: e.clientY }; moved = false; orbitLast = { x: e.clientX, y: e.clientY }; }
    audio.ensure();
  });
  canvas.addEventListener('pointermove', (e) => {
    if (!pointers.has(e.pointerId)) return; pointers.set(e.pointerId, { x: e.clientX, y: e.clientY });
    if (pointers.size >= 2) {
      const pts = [...pointers.values()]; const dist = Math.hypot(pts[0].x - pts[1].x, pts[0].y - pts[1].y);
      if (pinchLast) { view.cam.dist *= pinchLast / dist; view.cam.dist = Math.max(6, Math.min(18, view.cam.dist)); }
      pinchLast = dist; moved = true; return;
    }
    if (downPt && Math.hypot(e.clientX - downPt.x, e.clientY - downPt.y) > 8) moved = true;
    if (moved && orbitLast) { view.cam.az -= (e.clientX - orbitLast.x) * 0.007; view.cam.el += (e.clientY - orbitLast.y) * 0.007; view.cam.el = Math.max(0.35, Math.min(1.45, view.cam.el)); orbitLast = { x: e.clientX, y: e.clientY }; }
  });
  function endPtr(e) {
    const wasTap = pointers.size === 1 && !moved && downPt;
    pointers.delete(e.pointerId); if (pointers.size < 2) pinchLast = null; if (pointers.size === 0) orbitLast = null;
    if (wasTap) onPick(view.pick(e.clientX, e.clientY));
    downPt = null;
  }
  canvas.addEventListener('pointerup', endPtr); canvas.addEventListener('pointercancel', endPtr);
  canvas.addEventListener('contextmenu', (e) => e.preventDefault());
  canvas.addEventListener('wheel', (e) => { view.cam.dist *= (1 + Math.sign(e.deltaY) * 0.08); view.cam.dist = Math.max(6, Math.min(18, view.cam.dist)); e.preventDefault(); }, { passive: false });

  // ---- buttons ----
  el('newBtn').addEventListener('click', () => { el('menu').classList.add('show'); });
  el('undoBtn').addEventListener('click', () => {
    if (state.over || view.animating()) { if (!state.over) return; }
    if (board.hist.length === 0) return;
    const undoCount = (state.mode === 'ai' && board.hist.length >= 2 && board.side === state.human) ? 2 : 1;
    for (let i = 0; i < undoCount; i++) board.unmake();
    state.over = false; state.thinking = false; state.selected = -1; state.targets = [];
    const h = board.hist[board.hist.length - 1]; state.last = h ? [h.m.from, h.m.to] : [null, null];
    view.anims.length = 0; view.setPosition(board.b); el('result').classList.remove('show'); refreshHighlights(); updateHUD();
  });
  el('flipBtn').addEventListener('click', () => { view.flip = !view.flip; view.cam.az = view.flip ? -Math.PI / 2 : Math.PI / 2; refreshHighlights(); updateHUD(); });
  el('soundBtn').addEventListener('click', (e) => { audio.ensure(); const on = audio.enabled; audio.setEnabled(!on); e.currentTarget.textContent = on ? '🔇' : '🔊'; });

  // promotion picker
  ['5', '4', '3', '2'].forEach(t => el('promo-' + t).addEventListener('click', () => {
    const pp = state.pendingPromo; if (!pp) return; el('promoPick').classList.remove('show');
    const mv = pp.moves.find(m => m.promo === +t); state.pendingPromo = null; if (mv) applyMove(mv);
  }));

  // menu
  let selMode = 'ai', selSide = 1, selDiff = 'medium';
  el('modeSeg').addEventListener('click', (e) => { const b = e.target.closest('button'); if (!b) return; selMode = b.dataset.v; for (const x of e.currentTarget.children) x.classList.toggle('sel', x === b); el('sideField').style.display = el('diffField').style.display = selMode === 'ai' ? '' : 'none'; });
  el('sideSeg').addEventListener('click', (e) => { const b = e.target.closest('button'); if (!b) return; selSide = +b.dataset.v; for (const x of e.currentTarget.children) x.classList.toggle('sel', x === b); });
  el('diffSeg').addEventListener('click', (e) => { const b = e.target.closest('button'); if (!b) return; selDiff = b.dataset.v; for (const x of e.currentTarget.children) x.classList.toggle('sel', x === b); });
  el('startBtn').addEventListener('click', () => { audio.ensure(); state.mode = selMode; state.human = selSide; state.difficulty = selDiff; el('menu').classList.remove('show'); el('result').classList.remove('show'); newGame(); });
  el('againBtn').addEventListener('click', () => { el('result').classList.remove('show'); newGame(); });

  // ---- loop ----
  let last = performance.now();
  function frame(now) { const dt = Math.min(0.05, (now - last) / 1000); last = now; view.update(dt); view.render(); requestAnimationFrame(frame); }
  requestAnimationFrame(frame);
  view.setPosition(board.b); refreshHighlights(); updateHUD();
  window.__chess = { board, view, state };
})();
