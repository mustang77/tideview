/* ============================================================================
 * Deck & Horizon — first-person player controller
 * ----------------------------------------------------------------------------
 * Walks the deck: yaw/pitch look, camera-relative movement, circle-vs-collider
 * sliding, gravity + jump, and buoyancy when you step down into the pool.
 * ==========================================================================*/
(function (global) {
  'use strict';
  const T = global.THREE;

  function Player(camera) {
    this.cam = camera;
    this.x = 19; this.z = 2.5;        // spawn on the foredeck, clear of the mast
    this.y = 1.6;
    this.vy = 0;
    this.yaw = Math.PI / 2;           // face -X, looking down the ship
    this.pitch = -0.05;
    this.radius = 0.4;
    this.eyeHeight = 1.62;
    this.lookSens = 0.0026;
    this.grounded = true;
    this.swimming = false;
    this.underwater = false;
    this.jumpQueued = false;
    this.bob = 0;
  }

  Player.prototype.jump = function () { this.jumpQueued = true; };

  Player.prototype.update = function (dt, world, input) {
    // --- look ---
    this.yaw -= input.lookDX * this.lookSens;
    this.pitch -= input.lookDY * this.lookSens;
    this.pitch = Math.max(-1.3, Math.min(1.3, this.pitch));
    input.lookDX = 0; input.lookDY = 0;

    const fwdX = -Math.sin(this.yaw), fwdZ = -Math.cos(this.yaw);
    const rightX = Math.cos(this.yaw), rightZ = -Math.sin(this.yaw);

    // --- horizontal movement (camera-relative) with wall sliding ---
    let mx = fwdX * input.moveY + rightX * input.moveX;
    let mz = fwdZ * input.moveY + rightZ * input.moveX;
    const ml = Math.hypot(mx, mz);
    const inPoolNow = world.floorHeightAt(this.x, this.z) < -0.5;
    const speed = inPoolNow ? 2.6 : (input.run ? 7.2 : 4.6);
    let moving = false;
    if (ml > 0.001) {
      mx /= ml; mz /= ml;
      const step = speed * dt * Math.min(1, ml);
      const nx = this.x + mx * step;
      if (world.walkable(nx, this.z, this.radius)) this.x = nx;
      const nz = this.z + mz * step;
      if (world.walkable(this.x, nz, this.radius)) this.z = nz;
      moving = true;
    }

    // --- vertical: gravity/jump on deck, buoyancy in the pool ---
    const floor = world.floorHeightAt(this.x, this.z);
    if (floor < -0.5) {
      const target = world.waterLevel + 0.32;
      this.y += (target - this.y) * Math.min(1, dt * 4);
      this.vy = 0; this.grounded = true; this.swimming = true;
    } else {
      this.swimming = false;
      const groundY = floor + this.eyeHeight;
      if (this.jumpQueued && this.grounded) { this.vy = 5.4; this.grounded = false; }
      this.vy -= 15 * dt;
      this.y += this.vy * dt;
      if (this.y <= groundY) { this.y = groundY; this.vy = 0; this.grounded = true; }
      else this.grounded = false;
    }
    this.jumpQueued = false;

    // subtle head bob while walking on deck
    if (moving && this.grounded && !this.swimming) this.bob += dt * speed * 1.6;
    const bobY = (moving && this.grounded && !this.swimming) ? Math.sin(this.bob) * 0.035 : 0;

    // --- camera ---
    this.cam.position.set(this.x, this.y + bobY, this.z);
    const cp = Math.cos(this.pitch);
    this.cam.lookAt(
      this.x + cp * fwdX,
      this.y + bobY + Math.sin(this.pitch),
      this.z + cp * fwdZ
    );
    this.underwater = this.y < world.waterLevel - 0.02;
    return { moving, speed };
  };

  global.Cruise = global.Cruise || {};
  global.Cruise.Player = Player;

})(window);
