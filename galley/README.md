# Galley Rush — World Cruise Academy (3D)

A bright, Cooking-Madness-style time-management game: you're a galley steward
on a cruise ship. Wash each dirty dish at the sink, stack it in the rack, then
run a full rack through the dishwasher — clear every dish before the shift
clock runs out. The time budget scales with the number of dishes.

Built with Three.js. Self-contained, mobile-first, plays in landscape.

## Loop
- **WASH** (hold): scrub the dish in hand at the sink until it's clean
- **RACK**: stack the clean dish in the drying rack
- **RUN**: load a full rack into the dishwasher and run a cycle → dishes done
- Beat the timer to finish the shift; earn 1–3 stars by time remaining
- Each shift adds more dishes (and a bigger rack)

## Features
- Cartoon cruise-ship galley: teal counter, sunset porthole, glowing
  **WORLD CRUISE ACADEMY** neon sign, potted plants, dishwasher with a cycle light
- A friendly stylized crew member who scrubs, racks, and runs the machine
- Timer + progress HUD, rack indicator, contextual action buttons, pause
- Synthesized sound: scrub, clink, machine hum, ding, win/lose jingles
- Mobile HUD with safe-area insets + rotate-to-landscape prompt; keyboard too
  (Space = wash, R = rack, Enter/F = run)

## Run locally
    cd galley
    python3 -m http.server 8000   # open http://localhost:8000

## Files
- `index.html`  — HUD, overlays, styling
- `js/character.js` — the stylized steward (rigged arms, face)
- `js/scene.js`     — galley environment, stations, neon sign, plate visuals
- `js/game.js`      — shift logic, timer, wash→rack→dishwasher flow, scoring
- `js/audio.js`     — synthesized SFX
- `js/main.js`      — input, HUD glue, view sync, loop
- `vendor/three.min.js` — Three.js r160
