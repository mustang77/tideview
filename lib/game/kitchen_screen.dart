import "dart:math";

import "package:flutter/material.dart";
import "package:flutter/scheduler.dart";
import "package:flutter/services.dart";

import "controller.dart";
import "game_home.dart";
import "models.dart";
import "painters.dart";
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
            0.12 + 0.22 * max(0, e.customerIndex),
            game.elapsed,
          ));
          HapticFeedback.lightImpact();
        case "angry":
          _popups.add(_Popup(
            "Customer lost!",
            const Color(0xFFE05B5B),
            0.12 + 0.22 * max(0, e.customerIndex),
            game.elapsed,
          ));
          HapticFeedback.heavyImpact();
        case "burnt":
          _showHint(e.message);
          HapticFeedback.mediumImpact();
        case "hint":
          _showHint(e.message);
      }
    }
    _popups.removeWhere((p) => game.elapsed - p.born > 1.4);

    if (game.isOver && !_recorded) {
      _recorded = true;
      widget.storage.recordResult(
        levelId: widget.level.id,
        stars: game.stars,
        coins: game.coins,
        served: game.servedCustomers,
      );
    }
    if (mounted) setState(() {});
  }

  void _showHint(String message) {
    _hint = message;
    _hintUntil = game.elapsed + 2.4;
  }

  void _restart() {
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
      backgroundColor: const Color(0xFF23150C),
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
            if (_hint.isNotEmpty && game.elapsed < _hintUntil)
              _hintBanner(),
            if (game.phase == GamePhase.intro) _introOverlay(),
            if (game.phase == GamePhase.paused) _pauseOverlay(),
            if (game.isOver) _resultsOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _hud() {
    final goal = widget.level.starCoins;
    final frac = (game.coins / goal[2]).clamp(0.0, 1.0);
    return Container(
      color: const Color(0xFF1A0F08),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _roundButton(Icons.pause_rounded, () {
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
                    ...List.generate(3, (i) {
                      return Icon(
                        Icons.star_rounded,
                        size: 20,
                        color: game.coins >= goal[i]
                            ? kAccent
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
                          gradient: const LinearGradient(
                              colors: [kAccentDark, kAccent]),
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
                "Level ${widget.level.id}",
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
              Text(
                "${game.spawned - game.servedCustomers - game.lostCustomers}"
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
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF9AC4DB), Color(0xFFBFDDE8)],
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Back wall details: window + picture.
            Positioned(
              left: w * 0.06,
              top: 8,
              child: Container(
                width: w * 0.2,
                height: box.maxHeight * 0.28,
                decoration: BoxDecoration(
                  color: const Color(0xFFDFF1F7),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: const Color(0xFF7B5233), width: 3),
                ),
              ),
            ),
            // Counter along the bottom.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: box.maxHeight * 0.22,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF9A6B40), Color(0xFF7B5233)],
                  ),
                ),
              ),
            ),
            for (var i = 0; i < game.customers.length; i++)
              _customerWidget(i, box, slotW),
            for (final p in _popups) _popupWidget(p, box),
          ],
        ),
      );
    });
  }

  Widget _customerWidget(int i, BoxConstraints box, double slotW) {
    final c = game.customers[i];
    final slotX = 8 + i * (slotW + 6);
    double x;
    switch (c.phase) {
      case CustomerPhase.walkingIn:
        x = lerpDouble2(box.maxWidth, slotX, Curves.easeOut.transform(c.walk));
      case CustomerPhase.waiting:
        x = slotX;
      case CustomerPhase.leavingHappy:
      case CustomerPhase.leavingAngry:
        x = lerpDouble2(slotX, box.maxWidth + slotW,
            Curves.easeIn.transform(c.walk));
    }
    final bodyH = box.maxHeight * 0.52;
    final bubbleH = box.maxHeight * 0.34;
    final leaving = c.phase == CustomerPhase.leavingHappy ||
        c.phase == CustomerPhase.leavingAngry;
    final bounce = c.phase == CustomerPhase.leavingHappy
        ? -6 * (sin(c.walk * pi * 4)).abs()
        : 0.0;

    return Positioned(
      left: x,
      bottom: box.maxHeight * 0.06 - bounce,
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
          // Patience bar.
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
                      color: Color.lerp(const Color(0xFFE05B5B),
                          const Color(0xFF5FBF6E), c.patienceFrac),
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
    final icon = switch (item.type) {
      ItemType.burger => CustomPaint(painter: BurgerPainter(item.stack)),
      ItemType.fries =>
        const CustomPaint(painter: FriesPainter(CookState.done)),
      ItemType.drink => const CustomPaint(painter: DrinkPainter()),
    };
    return Opacity(
      opacity: served ? 0.25 : 1,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Padding(padding: const EdgeInsets.all(1), child: icon),
          if (served)
            const Center(
                child:
                    Icon(Icons.check_circle, color: Color(0xFF5FBF6E), size: 16)),
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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF5E3A20), Color(0xFF4A2D18)],
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
              HapticFeedback.selectionClick();
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
              color: has ? kAccent : Colors.white10, width: has ? 2 : 1),
        ),
        padding: const EdgeInsets.all(3),
        child: has
            ? CustomPaint(
                painter: switch (game.ready[i].type) {
                  ItemType.burger => BurgerPainter(game.ready[i].stack),
                  ItemType.fries =>
                    const FriesPainter(CookState.done) as CustomPainter,
                  ItemType.drink => const DrinkPainter(),
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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF352112), Color(0xFF23150C)],
        ),
      ),
      child: Column(
        children: [
          // Row 1: grill + fryer + drinks.
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 5, child: _grillStation()),
                if (level.fries) ...[
                  const SizedBox(width: 8),
                  Expanded(flex: 2, child: _fryerStation()),
                ],
                if (level.drinks) ...[
                  const SizedBox(width: 8),
                  Expanded(flex: 2, child: _drinkStation()),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Row 2: assembly plates + ingredient trays.
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 5, child: _assemblyStation()),
                const SizedBox(width: 8),
                Expanded(flex: 6, child: _trays()),
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
        color: const Color(0xFF4A3322),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF6B4A2E), width: 1.5),
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

  Widget _grillStation() {
    return _panel(
      "GRILL",
      Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Raw patty tray.
          Expanded(
            child: _tapTile(
              onTap: game.tapPattyTray,
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
          for (var i = 0; i < game.grill.length; i++) ...[
            Expanded(child: _grillSlot(i)),
            if (i < game.grill.length - 1) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }

  Widget _grillSlot(int i) {
    final s = game.grill[i];
    final progress = switch (s.state) {
      CookState.cooking => s.t / KitchenController.grillCookTime,
      CookState.done => s.t / KitchenController.grillDoneWindow,
      _ => 0.0,
    };
    final barColor = switch (s.state) {
      CookState.cooking => kAccent,
      CookState.done => const Color(0xFF5FBF6E),
      CookState.burnt => const Color(0xFFE05B5B),
      CookState.empty => Colors.transparent,
    };
    return _tapTile(
      onTap: () => game.tapGrillSlot(i),
      color: const Color(0xFF2B2B2B),
      glow: s.state == CookState.done,
      child: Column(
        children: [
          Expanded(
            child: CustomPaint(
              painter: PattyPainter(
                  s.state,
                  s.state == CookState.cooking
                      ? (s.t / KitchenController.grillCookTime)
                      : 1),
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

  Widget _fryerStation() {
    final f = game.fryer;
    final progress = switch (f.state) {
      CookState.cooking => f.t / KitchenController.fryCookTime,
      CookState.done => f.t / KitchenController.fryDoneWindow,
      _ => 0.0,
    };
    return _panel(
      "FRYER",
      _tapTile(
        onTap: game.tapFryer,
        color: const Color(0xFF37474F),
        glow: f.state == CookState.done,
        child: Column(
          children: [
            Expanded(
              child: CustomPaint(
                painter: FriesPainter(
                    f.state == CookState.empty ? CookState.done : f.state,
                    progress: f.state == CookState.cooking ? progress : 1),
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
                        color: f.state == CookState.done
                            ? const Color(0xFF5FBF6E)
                            : kAccent),
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
      CookState.cooking => d.t / KitchenController.drinkFillTime,
      CookState.done => 1.0,
      _ => 0.0,
    };
    return _panel(
      "DRINKS",
      _tapTile(
        onTap: game.tapDrink,
        color: const Color(0xFF31465A),
        glow: d.state == CookState.done,
        child: CustomPaint(
          painter: DrinkPainter(fill: fill),
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
      onTap: () => game.selectAssembly(i),
      onLongPress: a.started ? () => game.trashAssembly(i) : null,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF6EBD9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? kAccent : Colors.black26,
            width: selected ? 2.5 : 1,
          ),
        ),
        padding: const EdgeInsets.all(4),
        child: a.started
            ? Stack(
                children: [
                  CustomPaint(
                    painter: BurgerPainter(List.of(a.stack)),
                    child: const SizedBox.expand(),
                  ),
                  const Positioned(
                    right: 0,
                    top: 0,
                    child: Icon(Icons.delete_outline,
                        size: 13, color: Colors.black26),
                  ),
                ],
              )
            : const Center(
                child: Text("plate",
                    style: TextStyle(
                        color: Colors.black26,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ),
      ),
    );
  }

  Widget _trays() {
    final level = widget.level;
    final trayItems = <(String, Ingredient, VoidCallback)>[
      ("BUN", Ingredient.bunBottom, () => game.tapBunTray()),
      for (final t in level.toppings)
        (t.label.toUpperCase(), t, () => game.tapTopping(t)),
      ("TOP", Ingredient.bunTop, () => game.tapTopBun()),
    ];
    return _panel(
      "INGREDIENTS",
      Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < trayItems.length; i++) ...[
            Expanded(
              child: _tapTile(
                onTap: () {
                  HapticFeedback.selectionClick();
                  trayItems[i].$3();
                },
                color: const Color(0xFF5A422C),
                child: Column(
                  children: [
                    Expanded(
                      child: CustomPaint(
                        painter: BurgerPainter([trayItems[i].$2]),
                        child: const SizedBox.expand(),
                      ),
                    ),
                    Text(trayItems[i].$1,
                        style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 8,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ),
            if (i < trayItems.length - 1) const SizedBox(width: 5),
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
                    color: const Color(0xFF5FBF6E).withValues(alpha: 0.8),
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
    return Container(
      width: 320,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
      decoration: BoxDecoration(
        color: const Color(0xFF2C3E50),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: kAccent.withValues(alpha: 0.5), width: 2),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }

  Widget _bigButton(String label, VoidCallback onTap,
      {Color color = kAccent}) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: color,
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
    return _scrim(_card([
      Text("LEVEL ${level.id}",
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
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (i) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: [
                Icon(Icons.star_rounded, color: kAccent, size: 22 + i * 4.0),
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
      Text("${level.customers} customers",
          style: const TextStyle(color: Colors.white38, fontSize: 12)),
      const SizedBox(height: 16),
      _bigButton("START COOKING", () {
        HapticFeedback.mediumImpact();
        game.start();
        if (widget.level.id == 1) {
          _showHint("Tap the RAW tray to grill a patty, and BUN to start a plate!");
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
      _bigButton("RESUME", game.resume),
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
    final won = game.phase == GamePhase.won;
    final nextExists = widget.level.id < kLevels.length;
    return _scrim(_card([
      Text(won ? "LEVEL COMPLETE!" : "OUT OF LUCK...",
          style: TextStyle(
              color: won ? kAccent : const Color(0xFFE05B5B),
              fontWeight: FontWeight.w900,
              fontSize: 22,
              letterSpacing: 1)),
      const SizedBox(height: 12),
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
              color: earned ? kAccent : Colors.white12,
            ),
          );
        }),
      ),
      const SizedBox(height: 10),
      _statLine("Coins earned", "${game.coins}"),
      _statLine("Tips", "${game.tips}"),
      _statLine("Customers served",
          "${game.servedCustomers} / ${widget.level.customers}"),
      if (game.lostCustomers > 0)
        _statLine("Walked out", "${game.lostCustomers}"),
      const SizedBox(height: 16),
      if (won && nextExists)
        _bigButton("NEXT LEVEL", () {
          Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (_) => KitchenScreen(
                level: kLevels[widget.level.id], storage: widget.storage),
          ));
        }),
      if (won && nextExists) const SizedBox(height: 10),
      _bigButton(won ? "PLAY AGAIN" : "TRY AGAIN", _restart,
          color: won ? const Color(0xFF8AB4D8) : kAccent),
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

double lerpDouble2(double a, double b, double t) => a + (b - a) * t;
