# Break & Run — Professional 3D 8-Ball Pool

A polished, physics-driven 3D pool game built with Three.js and a custom
sub-stepped 2D billiard physics engine.

## Features
- Full 8-ball rules (open table, group assignment, fouls, ball-in-hand, 8-ball win/loss)
- Realistic ball–ball and cushion physics with English (top/back/side spin)
- 3D rendered table, cloth, rails, numbered/striped balls, cue stick, shadows
- Orbit camera, aim guide with ghost-ball & cushion reflection preview
- Power and spin controls
- Play vs AI (3 difficulty levels) or local 2-player

## Run locally
Any static file server works, e.g.:

    cd pool
    python3 -m http.server 8000
    # open http://localhost:8000

## Files
- `index.html`  — layout, HUD, styling
- `js/physics.js`  — deterministic sub-stepped billiard simulation
- `js/table.js`    — table/ball geometry, textures, 3D scene building
- `js/game.js`     — 8-ball rules, turn/foul logic, AI, input, HUD glue
- `vendor/three.min.js` — Three.js r160 (rendering)
