import "dart:math";

import "package:flutter/material.dart";
import "package:flutter/scheduler.dart";
import "package:flutter/services.dart";

import "controller.dart";
import "game_home.dart";
import "models.dart";
import "painters.dart";
import "sound.dart";
import "storage.dart";

/// One floating "+N" popup over the dining area.
class _Popup {
  final String text;
  final Color color;
  final double x; // 0..1 across the dining area
  final double born; // controller.elapsed when spawned
  _Popup(this.text, this.color, this.x, this.born);
}

class KitchenScreen extends StatefulWidget {
  final LevelDef level;
  final GameStorage storage;
  const KitchenScreen({super.key, required this.level, required this.storage});

  @override
  State<KitchenScreen> createState() => _KitchenScreenState();
}

class _KitchenScreenState extends State<KitchenScreen>
    with SingleTickerProviderStateMixin {
  late KitchenController game;
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  final List<_Popup> _popups = [];
  String _hint = "";
  double _hintUntil = 0;
  bool _recorded = false;

  VenueDef get venue => widget.level.venue;

  @override
  void initState() {
    super.initState();
    game = KitchenController(widget.level);
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    game.dispose();
    super.dispose();
  }

  void _haptic(void Function() f) {
    if (widget.storage.hapticsOn) f();
  }

  void _onTick(Duration now) {
    final dt = (now - _last).inMicroseconds / 1e6;
    _last = now;
    if (dt <= 0 || dt > 0.5) return;
    game.tick(dt);

    for (final e in game.drainEvents()) {
      switch (e.kind) {
        case "coin":
          _popups.add(_Popup(
            e.message,
            const Color(0xFFF7D046),
            0.10 + 0.22 * max(0, e.customerIndex),
            game.elapsed,
          ));
          Sfx.instance.coin();
          _haptic(HapticFeedback.lightImpact);
        case "serve":
          Sfx.instance.serve();
        case "angry":
          _popups.add(_Popup(
            widget.level.endless ? "-1 life!" : "Customer lost!",
            kBad,
            0.10 + 0.22 * max(0, e.customerIndex),
            game.elapsed,
          ));
          Sfx.instance.angry();
          _haptic(HapticFeedback.heavyImpact);
        case "burnt":
          _showHint(e.message);
          Sfx.instance.burnt();
          _haptic(HapticFeedback.mediumImpact);
        case "ready":
          Sfx.instance.ding();
        case "trash":
          Sfx.instance.trash();
        case "hint":
          _showHint(e.message);
        case "over":
          if (game.phase == GamePhase.won) {
            Sfx.instance.win();
          } else {
            Sfx.instance.lose();
          }
      }
    }
    _popups.removeWhere((p) => game.elapsed - p.born > 1.4);

    if (game.isOver && !_recorded) {
      _recorded = true;
      widget.storage.recordResult(
        venue: venue.id,
        levelId: widget.level.id,
        stars: game.stars,
        coins: game.coins,
        served: game.servedCustomers,
        endless: widget.level.endless,
      );
    }
    if (mounted) setState(() {});
  }

  void _showHint(String message) {
    _hint = message;
    _hintUntil = game.elapsed + 2.4;
  }

  void _restart() {
    Sfx.instance.tap();
    setState(() {
      game.dispose();
      game = KitchenController(widget.level);
      _popups.clear();
      _recorded = false;
      _hint = "";
    });
  }

  // ------------------------------------------------------------------ UI

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: venue.kitchenBottom,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _hud(),
                Expanded(flex: 10, child: _diningArea()),
                _passShelf(),
                Expanded(flex: 12, child: _kitchen()),
              ],
            ),
            if (_hint.isNotEmpty && game.elapsed < _hintUntil) _hintBanner(),
            if (game.phase == GamePhase.intro) _introOverlay(),
            if (game.phase == GamePhase.paused) _pauseOverlay(),
            if (game.isOver) _resultsOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _hud() {
    final endless = widget.level.endless;
    final goal = widget.level.starCoins;
    final frac = endless
        ? 1.0
        : (goal.isEmpty ? 0.0 : (game.coins / goal[2]).clamp(0.0, 1.0));
    return Container(
      color: Color.lerp(venue.kitchenBottom, Colors.black, 0.3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _roundButton(Icons.pause_rounded, () {
            Sfx.instance.tap();
            game.pause();
          }),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.monetization_on_rounded,
                        color: Color(0xFFF7D046), size: 18),
                    const SizedBox(width: 4),
                    Text(
                      "${game.coins}",
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16),
                    ),
                    const Spacer(),
                    if (endless)
                      ...List.generate(KitchenController.endlessLives, (i) {
                        return Icon(
                          i < game.livesLeft
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          size: 19,
                          color: i < game.livesLeft ? kBad : Colors.white24,
                        );
                      })
                    else
                      ...List.generate(3, (i) {
                        return Icon(
                          Icons.star_rounded,
                          size: 20,
                          color: goal.isNotEmpty && game.coins >= goal[i]
                              ? venue.accent
                              : Colors.white24,
                        );
                      }),
                  ],
                ),
                const SizedBox(height: 4),
                Stack(
                  children: [
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: frac,
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            Color.lerp(venue.accent, Colors.black, 0.25)!,
                            venue.accent,
                          ]),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                endless
                    ? "Endless · ${venue.name}"
                    : "Level ${widget.level.id} · ${venue.name}",
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
              Text(
                endless
                    ? "${game.servedCustomers} served"
                    : "${game.spawned - game.servedCustomers - game.lostCustomers}"
                        " here · ${widget.level.customers - game.spawned} coming",
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _roundButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white.withValues(alpha: 0.1),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }

  // -------------------------------------------------------------- dining

  Widget _diningArea() {
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      final slotW = w / 4.4;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(painter: DiningBackdropPainter(venue)),
          ),
          // Counter along the bottom.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: box.maxHeight * 0.22,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [venue.counterTop, venue.counterBottom],
                ),
              ),
            ),
          ),
          // Counter edge highlight.
          Positioned(
            left: 0,
            right: 0,
            bottom: box.maxHeight * 0.22 - 3,
            height: 3,
            child: Container(color: Colors.white.withValues(alpha: 0.25)),
          ),
          for (var i = 0; i < game.customers.length; i++)
            _customerWidget(i, box, slotW),
          for (final p in _popups) _popupWidget(p, box),
        ],
      );
    });
  }

  Widget _customerWidget(int i, BoxConstraints box, double slotW) {
    final c = game.customers[i];
    final slotX = 8 + i * (slotW + 6);
    double x;
    switch (c.phase) {
      case CustomerPhase.walkingIn:
        x = _lerp(box.maxWidth, slotX, Curves.easeOut.transform(c.walk));
      case CustomerPhase.waiting:
        x = slotX;
      case CustomerPhase.leavingHappy:
      case CustomerPhase.leavingAngry:
        x = _lerp(slotX, box.maxWidth + slotW,
            Curves.easeIn.transform(c.walk));
    }
    final bodyH = box.maxHeight * 0.54;
    final bubbleH = box.maxHeight * 0.34;
    final leaving = c.phase == CustomerPhase.leavingHappy ||
        c.phase == CustomerPhase.leavingAngry;
    final bounce = c.phase == CustomerPhase.leavingHappy
        ? -6 * (sin(c.walk * pi * 4)).abs()
        : 0.0;

    return Positioned(
      left: x,
      bottom: box.maxHeight * 0.05 - bounce,
      width: slotW,
      height: bodyH + bubbleH + 8,
      child: Column(
        children: [
          if (!leaving && c.phase == CustomerPhase.waiting)
            _orderBubble(c, slotW, bubbleH)
          else
            SizedBox(height: bubbleH),
          const SizedBox(height: 2),
          Expanded(
            child: CustomPaint(
              painter: CustomerPainter(c.seed, c.mood),
              size: Size(slotW, bodyH),
            ),
          ),
        ],
      ),
    );
  }

  Widget _orderBubble(Customer c, double slotW, double h) {
    return Container(
      height: h,
      padding: const EdgeInsets.fromLTRB(5, 4, 5, 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < c.items.length; i++)
                  Expanded(child: _orderItemIcon(c.items[i], c.served[i])),
              ],
            ),
          ),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 5,
              child: Stack(
                children: [
                  Container(color: Colors.black12),
                  FractionallySizedBox(
                    widthFactor: c.patienceFrac,
                    child: Container(
                      color: Color.lerp(
                          kBad, kGood, c.patienceFrac),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _orderItemIcon(OrderItem item, bool served) {
    final painter = switch (item.type) {
      ItemType.main => mainDishPainter(venue, item.stack, finished: true),
      ItemType.side => SidePainter(venue.id, CookState.done),
      ItemType.drink => DrinkPainter(venue.id),
    };
    return Opacity(
      opacity: served ? 0.25 : 1,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Padding(
            padding: const EdgeInsets.all(1),
            child: CustomPaint(painter: painter),
          ),
          if (served)
            const Center(
                child: Icon(Icons.check_circle, color: kGood, size: 16)),
        ],
      ),
    );
  }

  Widget _popupWidget(_Popup p, BoxConstraints box) {
    final age = ((game.elapsed - p.born) / 1.4).clamp(0.0, 1.0);
    return Positioned(
      left: box.maxWidth * p.x,
      top: box.maxHeight * 0.25 - age * 34,
      child: Opacity(
        opacity: 1 - age * age,
        child: Text(
          p.text,
          style: TextStyle(
            color: p.color,
            fontSize: 17,
            fontWeight: FontWeight.w900,
            shadows: const [Shadow(color: Colors.black54, blurRadius: 3)],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- pass

  Widget _passShelf() {
    return Container(
      height: 78,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(venue.counterBottom, Colors.black, 0.15)!,
            Color.lerp(venue.counterBottom, Colors.black, 0.35)!,
          ],
        ),
      ),
      child: Row(
        children: [
          const RotatedBox(
            quarterTurns: 3,
            child: Text("SERVE",
                style: TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2)),
          ),
          const SizedBox(width: 6),
          for (var i = 0; i < KitchenController.maxReady; i++) ...[
            Expanded(child: _readySlot(i)),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _readySlot(int i) {
    final has = i < game.ready.length;
    return GestureDetector(
      onTap: has
          ? () {
              _haptic(HapticFeedback.selectionClick);
              game.serveReady(i);
            }
          : null,
      onLongPress: has ? () => game.trashReady(i) : null,
      child: Container(
        decoration: BoxDecoration(
          color: has
              ? const Color(0xFFF6EBD9)
              : Colors.black.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: has ? venue.accent : Colors.white10,
              width: has ? 2 : 1),
        ),
        padding: const EdgeInsets.all(3),
        child: has
            ? CustomPaint(
                painter: switch (game.ready[i].type) {
                  ItemType.main =>
                    mainDishPainter(venue, game.ready[i].stack, finished: true),
                  ItemType.side => SidePainter(venue.id, CookState.done),
                  ItemType.drink => DrinkPainter(venue.id),
                },
                child: const SizedBox.expand(),
              )
            : null,
      ),
    );
  }

  // ------------------------------------------------------------- kitchen

  Widget _kitchen() {
    final level = widget.level;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [venue.kitchenTop, venue.kitchenBottom],
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 5, child: _processorStation()),
                if (level.sides) ...[
                  const SizedBox(width: 8),
                  Expanded(flex: 2, child: _sideStation()),
                ],
                if (level.drinks) ...[
                  const SizedBox(width: 8),
                  Expanded(flex: 2, child: _drinkStation()),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 5, child: _assemblyStation()),
                const SizedBox(width: 8),
                Expanded(flex: 7, child: _trays()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _panel(String label, Widget child) {
    return Container(
      decoration: BoxDecoration(
        color: venue.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: venue.panelBorder, width: 1.5),
      ),
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5)),
          const SizedBox(height: 2),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _processorStation() {
    final isBurger = venue.flow == VenueFlow.cookThenAssemble;
    return _panel(
      venue.processorLabel,
      Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isBurger) ...[
            Expanded(
              child: _tapTile(
                onTap: () {
                  if (game.tapRawTray()) Sfx.instance.sizzle();
                },
                color: const Color(0xFFE8B4A0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: CustomPaint(
                        painter: const PattyPainter(CookState.cooking, 0),
                        child: const SizedBox.expand(),
                      ),
                    ),
                    const Text("RAW",
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF7A4030))),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          for (var i = 0; i < game.processors.length; i++) ...[
            Expanded(child: _processorSlot(i)),
            if (i < game.processors.length - 1) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }

  Widget _processorSlot(int i) {
    final p = game.processors[i];
    final progress = switch (p.state) {
      CookState.cooking => p.t / venue.processTime,
      CookState.done => venue.processBurnWindow > 0
          ? p.t / venue.processBurnWindow
          : 1.0,
      _ => 0.0,
    };
    final barColor = switch (p.state) {
      CookState.cooking => venue.accent,
      CookState.done => kGood,
      CookState.burnt => kBad,
      CookState.empty => Colors.transparent,
    };
    final CustomPainter painter = switch (venue.flow) {
      VenueFlow.cookThenAssemble => PattyPainter(
          p.state,
          p.state == CookState.cooking ? (p.t / venue.processTime) : 1),
      VenueFlow.assembleThenCook => PizzaPainter(p.stack,
          state: p.state,
          progress:
              p.state == CookState.cooking ? p.t / venue.processTime : 1),
      VenueFlow.assembleThenRoll => p.state == CookState.cooking
          ? SushiRollingPainter(p.t / venue.processTime)
          : (p.state == CookState.done
              ? SushiPlatePainter(p.stack)
              : const SushiAssemblyPainter([])),
    };
    return _tapTile(
      onTap: () {
        _haptic(HapticFeedback.selectionClick);
        final before = p.state;
        if (game.tapProcessor(i) &&
            before == CookState.empty &&
            venue.flow == VenueFlow.assembleThenCook) {
          Sfx.instance.sizzle();
        }
      },
      color: venue.flow == VenueFlow.assembleThenRoll
          ? const Color(0xFF31465A)
          : const Color(0xFF2B2B2B),
      glow: p.state == CookState.done,
      child: Column(
        children: [
          Expanded(
            child: CustomPaint(
              painter: painter,
              child: const SizedBox.expand(),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: SizedBox(
              height: 4,
              child: Stack(children: [
                Container(color: Colors.white10),
                FractionallySizedBox(
                    widthFactor: progress.clamp(0.0, 1.0),
                    child: Container(color: barColor)),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sideStation() {
    final s = game.side;
    final progress = switch (s.state) {
      CookState.cooking => s.t / venue.sideCookTime,
      CookState.done =>
        venue.sideBurnWindow > 0 ? s.t / venue.sideBurnWindow : 1.0,
      _ => 0.0,
    };
    return _panel(
      venue.sideStationLabel,
      _tapTile(
        onTap: () {
          _haptic(HapticFeedback.selectionClick);
          final before = s.state;
          if (game.tapSide() && before == CookState.empty) {
            Sfx.instance.sizzle();
          }
        },
        color: const Color(0xFF37474F),
        glow: s.state == CookState.done,
        child: Column(
          children: [
            Expanded(
              child: CustomPaint(
                painter: SidePainter(
                    venue.id,
                    s.state == CookState.empty ? CookState.done : s.state,
                    progress:
                        s.state == CookState.cooking ? progress : 1),
                child: const SizedBox.expand(),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: SizedBox(
                height: 4,
                child: Stack(children: [
                  Container(color: Colors.white10),
                  FractionallySizedBox(
                    widthFactor: progress.clamp(0.0, 1.0),
                    child: Container(
                        color: s.state == CookState.done
                            ? kGood
                            : venue.accent),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drinkStation() {
    final d = game.drink;
    final fill = switch (d.state) {
      CookState.cooking => d.t / venue.drinkFillTime,
      CookState.done => 1.0,
      _ => 0.0,
    };
    return _panel(
      venue.drinkLabel,
      _tapTile(
        onTap: () {
          _haptic(HapticFeedback.selectionClick);
          game.tapDrink();
        },
        color: const Color(0xFF31465A),
        glow: d.state == CookState.done,
        child: CustomPaint(
          painter: DrinkPainter(venue.id, fill: fill),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }

  Widget _assemblyStation() {
    return _panel(
      "ASSEMBLY",
      Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < game.assemblies.length; i++) ...[
            Expanded(child: _assemblySlot(i)),
            if (i < game.assemblies.length - 1) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }

  Widget _assemblySlot(int i) {
    final a = game.assemblies[i];
    final selected = game.selectedAssembly == i && a.started;
    return GestureDetector(
      onTap: () {
        _haptic(HapticFeedback.selectionClick);
        game.selectAssembly(i);
      },
      onLongPress: a.started ? () => game.trashAssembly(i) : null,
      child: Container(
        decoration: BoxDecoration(
          color: venue.flow == VenueFlow.assembleThenRoll
              ? const Color(0xFF3B5560)
              : const Color(0xFFF6EBD9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? venue.accent : Colors.black26,
            width: selected ? 2.5 : 1,
          ),
        ),
        padding: const EdgeInsets.all(4),
        child: a.started
            ? Stack(
                children: [
                  CustomPaint(
                    painter: mainDishPainter(venue, List.of(a.stack),
                        state: CookState.empty),
                    child: const SizedBox.expand(),
                  ),
                  const Positioned(
                    right: 0,
                    top: 0,
                    child: Icon(Icons.delete_outline,
                        size: 13, color: Colors.black38),
                  ),
                ],
              )
            : Center(
                child: Text(
                    venue.flow == VenueFlow.assembleThenRoll ? "mat" : "plate",
                    style: TextStyle(
                        color: venue.flow == VenueFlow.assembleThenRoll
                            ? Colors.white24
                            : Colors.black26,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ),
      ),
    );
  }

  Widget _trays() {
    final level = widget.level;
    final items = <Ingredient>[
      ...venue.mandatory,
      ...level.toppings,
      if (venue.closer != null) venue.closer!,
    ];
    return _panel(
      "INGREDIENTS",
      Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            Expanded(
              child: _tapTile(
                onTap: () {
                  _haptic(HapticFeedback.selectionClick);
                  Sfx.instance.tap();
                  game.tapTray(items[i]);
                },
                color: Color.lerp(venue.panel, Colors.white, 0.12)!,
                child: Column(
                  children: [
                    Expanded(
                      child: CustomPaint(
                        painter: TrayIconPainter(items[i]),
                        child: const SizedBox.expand(),
                      ),
                    ),
                    Text(items[i].label.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 7.5,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ),
            if (i < items.length - 1) const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }

  Widget _tapTile({
    required VoidCallback onTap,
    required Color color,
    required Widget child,
    bool glow = false,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        boxShadow: glow
            ? [
                BoxShadow(
                    color: kGood.withValues(alpha: 0.8),
                    blurRadius: 10,
                    spreadRadius: 1)
              ]
            : const [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.all(4), child: child),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ overlays

  Widget _hintBanner() {
    return Positioned(
      left: 30,
      right: 30,
      bottom: 16,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Text(
            _hint,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Widget _scrim(Widget child) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.65),
        alignment: Alignment.center,
        child: child,
      ),
    );
  }

  Widget _card(List<Widget> children) {
    return SingleChildScrollView(
      child: Container(
        width: 320,
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
        decoration: BoxDecoration(
          color: const Color(0xFF2C3E50),
          borderRadius: BorderRadius.circular(22),
          border:
              Border.all(color: venue.accent.withValues(alpha: 0.5), width: 2),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }

  Widget _bigButton(String label, VoidCallback onTap, {Color? color}) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: color ?? venue.accent,
          foregroundColor: Colors.black87,
          padding: const EdgeInsets.symmetric(vertical: 12),
          textStyle:
              const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: onTap,
        child: Text(label),
      ),
    );
  }

  Widget _introOverlay() {
    final level = widget.level;
    final endless = level.endless;
    return _scrim(_card([
      Text(endless ? venue.name.toUpperCase() : "LEVEL ${level.id}",
          style: const TextStyle(
              color: Colors.white54,
              fontWeight: FontWeight.w800,
              letterSpacing: 3,
              fontSize: 13)),
      const SizedBox(height: 4),
      Text(level.title,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w900, fontSize: 24)),
      const SizedBox(height: 8),
      Text(level.blurb,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 14)),
      const SizedBox(height: 14),
      if (endless)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.favorite_rounded, color: kBad, size: 22),
            const Icon(Icons.favorite_rounded, color: kBad, size: 22),
            const Icon(Icons.favorite_rounded, color: kBad, size: 22),
            const SizedBox(width: 10),
            Text("Best: ${widget.storage.endlessBest(venue.id)}",
                style: const TextStyle(
                    color: Colors.white70, fontWeight: FontWeight.w700)),
          ],
        )
      else
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                children: [
                  Icon(Icons.star_rounded,
                      color: venue.accent, size: 22 + i * 4.0),
                  Text("${level.starCoins[i]}",
                      style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                ],
              ),
            );
          }),
        ),
      const SizedBox(height: 6),
      if (!endless)
        Text("${level.customers} customers",
            style: const TextStyle(color: Colors.white38, fontSize: 12)),
      const SizedBox(height: 16),
      _bigButton("START COOKING", () {
        _haptic(HapticFeedback.mediumImpact);
        Sfx.instance.tap();
        game.start();
        if (!endless && widget.level.id == 1) {
          _showHint(switch (venue.flow) {
            VenueFlow.cookThenAssemble =>
              "Tap RAW to grill a patty, and BUN to start a plate!",
            VenueFlow.assembleThenCook =>
              "Tap DOUGH, SAUCE and CHEESE, then tap the oven to bake!",
            VenueFlow.assembleThenRoll =>
              "Tap NORI, RICE and a filling, then tap a mat to roll!",
          });
        }
      }),
      const SizedBox(height: 8),
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text("Back to menu",
            style: TextStyle(color: Colors.white54)),
      ),
    ]));
  }

  Widget _pauseOverlay() {
    return _scrim(_card([
      const Text("PAUSED",
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 24,
              letterSpacing: 2)),
      const SizedBox(height: 18),
      _bigButton("RESUME", () {
        Sfx.instance.tap();
        game.resume();
      }),
      const SizedBox(height: 10),
      _bigButton("RESTART", _restart, color: const Color(0xFF8AB4D8)),
      const SizedBox(height: 10),
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child:
            const Text("Quit level", style: TextStyle(color: Colors.white54)),
      ),
    ]));
  }

  Widget _resultsOverlay() {
    final endless = widget.level.endless;
    final won = game.phase == GamePhase.won;
    final levels = levelsFor(venue.id);
    final nextExists = !endless && widget.level.id < levels.length;
    final best = widget.storage.endlessBest(venue.id);
    return _scrim(_card([
      Text(
          endless
              ? "SHIFT OVER!"
              : (won ? "LEVEL COMPLETE!" : "OUT OF LUCK..."),
          style: TextStyle(
              color: won || endless ? venue.accent : kBad,
              fontWeight: FontWeight.w900,
              fontSize: 22,
              letterSpacing: 1)),
      const SizedBox(height: 12),
      if (endless) ...[
        Text("${game.coins}",
            style: TextStyle(
                color: venue.accent,
                fontWeight: FontWeight.w900,
                fontSize: 44)),
        Text(
            game.coins >= best && game.coins > 0
                ? "NEW BEST!"
                : "Best: $best",
            style: const TextStyle(
                color: Colors.white70, fontWeight: FontWeight.w700)),
      ] else
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final earned = i < game.stars;
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: Duration(milliseconds: 350 + i * 250),
              curve: Curves.elasticOut,
              builder: (context, v, child) =>
                  Transform.scale(scale: v, child: child),
              child: Icon(
                Icons.star_rounded,
                size: i == 1 ? 56 : 44,
                color: earned ? venue.accent : Colors.white12,
              ),
            );
          }),
        ),
      const SizedBox(height: 10),
      _statLine("Coins earned", "${game.coins}"),
      _statLine("Tips", "${game.tips}"),
      _statLine(
          "Customers served",
          endless
              ? "${game.servedCustomers}"
              : "${game.servedCustomers} / ${widget.level.customers}"),
      if (game.lostCustomers > 0)
        _statLine("Walked out", "${game.lostCustomers}"),
      const SizedBox(height: 16),
      if (won && nextExists)
        _bigButton("NEXT LEVEL", () {
          Sfx.instance.tap();
          Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (_) => KitchenScreen(
                level: levels[widget.level.id], storage: widget.storage),
          ));
        }),
      if (won && nextExists) const SizedBox(height: 10),
      _bigButton(won || endless ? "PLAY AGAIN" : "TRY AGAIN", _restart,
          color: won || endless ? const Color(0xFF8AB4D8) : venue.accent),
      const SizedBox(height: 10),
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text("Back to menu",
            style: TextStyle(color: Colors.white54)),
      ),
    ]));
  }

  Widget _statLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white60, fontSize: 14)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14)),
        ],
      ),
    );
  }
}

double _lerp(double a, double b, double t) => a + (b - a) * t;
