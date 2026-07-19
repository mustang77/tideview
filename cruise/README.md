# Deck & Horizon — Cruise Ship Walk (3D)

A first-person exploration slice: walk the top deck of a cruise ship at sea.
Built with Three.js and a custom water shader — self-contained, mobile-first,
plays in landscape.

## Features
- First-person controller: camera-relative movement, look, jump, run, head-bob
- Walkable deck with collision (superstructure, funnels, loungers, railings)
- Swimming pool you can walk down into (buoyancy + underwater tint)
- Animated ocean (Gerstner-style wave shader), gradient sky, sun, shadows
- Interactions: ring the ship's bell, look through the telescope (zoom)
- Ambient sound (synthesized): ocean wash, gulls, footsteps, bell, splash
- Mobile controls: floating movement joystick (left), drag-to-look (right),
  jump / run / interact buttons; safe-area insets; rotate-to-landscape prompt
- Keyboard/mouse also supported (WASD, drag look, Space, Shift, E)

## Run locally
    cd cruise
    python3 -m http.server 8000   # open http://localhost:8000

## Files
- `index.html` — HUD, controls, styling
- `js/world.js`  — ship, ocean, sky, props, colliders, interactables
- `js/player.js` — first-person movement/collision/swim controller
- `js/audio.js`  — synthesized ambience & SFX
- `js/main.js`   — input, loop, interactions, HUD glue
- `vendor/three.min.js` — Three.js r160

## Note
This is a first playable slice (v1). Natural next steps: interior decks and
stairs, more NPCs/props, day–night cycle, and a third-person camera toggle.
