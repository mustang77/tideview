# Grandmaster — 3D Chess

A polished 3D chess game with a real engine and AI. Self-contained, mobile-first,
plays in landscape. Built with Three.js.

## Features
- **Provably-correct rules engine** — full legal move generation with castling,
  en passant, promotion, check/checkmate/stalemate and draw rules. Validated
  against known perft node counts (start, Kiwipete, and edge-case positions).
- **Real AI** — negamax with alpha-beta pruning, quiescence search, move
  ordering (MVV-LVA), and iterative deepening on a time budget (never freezes).
  Three difficulties. Finds tactics and forced mates.
- **3D board & pieces** — wooden board, procedurally-modelled pieces, shadows,
  orbit camera (drag to rotate, pinch/scroll to zoom), smooth move animations.
- **Full UX** — tap to select (accurate 3D piece picking) with legal-move dots,
  last-move + check highlights, captured-piece trays, undo, flip board,
  promotion picker, sound. Play vs Computer (choose White/Black) or 2-player.
- Mobile HUD with safe-area insets and a rotate-to-landscape prompt.

## Run locally
    cd chess
    python3 -m http.server 8000   # open http://localhost:8000

## Files
- `index.html`   — HUD, menus, styling
- `js/engine.js` — rules engine (board, legal moves, make/unmake, perft)
- `js/ai.js`     — negamax + alpha-beta + quiescence + iterative deepening
- `js/board3d.js`— 3D board, pieces, highlights, animation, camera, picking
- `js/audio.js`  — synthesized move/capture/check/win sounds
- `js/main.js`   — input, turn flow, promotion, HUD glue
- `vendor/three.min.js` — Three.js r160
