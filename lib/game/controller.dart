import "dart:math";

import "package:flutter/foundation.dart";

import "models.dart";

enum CookState { empty, cooking, done, burnt }

/// A processor slot: a grill spot (burger), an oven mouth (pizza) or a
/// rolling mat (sushi). For assemble-then-process venues it carries the
/// dish's stack while it cooks.
class ProcessorSlot {
  CookState state = CookState.empty;
  double t = 0;
  List<Ingredient> stack = const [];
}

class SideStation {
  CookState state = CookState.empty;
  double t = 0;
}

class DrinkStation {
  CookState state = CookState.empty; // cooking = filling
  double t = 0;
}

/// An in-progress dish on an assembly plate.
class Assembly {
  final List<Ingredient> stack = [];
  bool get started => stack.isNotEmpty;
}

/// A finished item sitting on the pass, waiting to be served.
class ReadyItem {
  final ItemType type;
  final List<Ingredient> stack;
  ReadyItem.main(List<Ingredient> s)
      : type = ItemType.main,
        stack = List.of(s);
  ReadyItem.side()
      : type = ItemType.side,
        stack = const [];
  ReadyItem.drink()
      : type = ItemType.drink,
        stack = const [];
}

enum GamePhase { intro, running, paused, won, lost }

/// A transient event the UI can animate or voice (popups, sounds...).
class GameEvent {
  final String kind; // serve | coin | angry | burnt | hint | ready | tap
  final String message;
  final int amount;
  final int customerIndex;
  GameEvent(this.kind,
      {this.message = "", this.amount = 0, this.customerIndex = -1});
}

/// All simulation state and rules for one level (or an endless run).
/// The UI listens and repaints; it never mutates state directly.
class KitchenController extends ChangeNotifier {
  static const int maxWaiting = 4;
  static const int maxReady = 3;
  static const int endlessLives = 3;

  final LevelDef level;
  final VenueDef venue;
  final Random _rng;

  final List<ProcessorSlot> processors;
  final SideStation side = SideStation();
  final DrinkStation drink = DrinkStation();
  final List<Assembly> assemblies = [Assembly(), Assembly()];
  int selectedAssembly = 0;
  final List<ReadyItem> ready = [];

  final List<Customer> customers = [];
  int spawned = 0;
  double _spawnTimer = 2.0;

  GamePhase phase = GamePhase.intro;
  int coins = 0;
  int tips = 0;
  int servedCustomers = 0;
  int lostCustomers = 0;
  int combo = 0;
  double elapsed = 0;

  final List<GameEvent> events = [];

  KitchenController(this.level, {int? seed})
      : venue = level.venue,
        _rng = Random(seed),
        processors =
            List.generate(level.processorSlots, (_) => ProcessorSlot());

  // ------------------------------------------------------------- scoring

  int get stars {
    if (level.endless || level.starCoins.isEmpty) return 0;
    if (coins >= level.starCoins[2]) return 3;
    if (coins >= level.starCoins[1]) return 2;
    if (coins >= level.starCoins[0]) return 1;
    return 0;
  }

  int get livesLeft =>
      level.endless ? (endlessLives - lostCustomers).clamp(0, endlessLives) : 0;

  bool get isOver => phase == GamePhase.won || phase == GamePhase.lost;

  // Endless difficulty ramp: 0 at start -> 1 after ~3.5 minutes.
  double get _ramp => level.endless ? (elapsed / 210).clamp(0.0, 1.0) : 0;

  double get _spawnGapMin => level.spawnGapMin - 3.6 * _ramp;
  double get _spawnGapMax => level.spawnGapMax - 4.5 * _ramp;
  double get _patiencePerItem => level.patiencePerItem - 14 * _ramp;

  void start() {
    if (phase == GamePhase.intro) {
      phase = GamePhase.running;
      notifyListeners();
    }
  }

  void pause() {
    if (phase == GamePhase.running) {
      phase = GamePhase.paused;
      notifyListeners();
    }
  }

  void resume() {
    if (phase == GamePhase.paused) {
      phase = GamePhase.running;
      notifyListeners();
    }
  }

  void _emit(GameEvent e) {
    events.add(e);
    if (events.length > 24) events.removeAt(0);
  }

  /// Pull pending UI events (popups, sounds). The UI drains this every frame.
  List<GameEvent> drainEvents() {
    if (events.isEmpty) return const [];
    final out = List<GameEvent>.of(events);
    events.clear();
    return out;
  }

  // ---------------------------------------------------------------- ticking

  void tick(double dt) {
    if (phase != GamePhase.running) return;
    elapsed += dt;

    for (final p in processors) {
      _advance(
        p.state,
        p.t + dt,
        venue.processTime,
        venue.processBurnWindow,
        (st, t) {
          p.state = st;
          p.t = t;
          if (st == CookState.done && t == 0) {
            _emit(GameEvent("ready"));
          }
        },
        whenBurnt: () {
          _emit(GameEvent("burnt",
              message: "The ${_processedName()} burnt!"));
        },
      );
    }
    if (side.state != CookState.empty) {
      _advance(side.state, side.t + dt, venue.sideCookTime,
          venue.sideBurnWindow, (st, t) {
        side.state = st;
        side.t = t;
        if (st == CookState.done && t == 0) _emit(GameEvent("ready"));
      },
          whenBurnt: () => _emit(GameEvent("burnt",
              message: "The ${venue.sideLabel.toLowerCase()} burnt!")));
    }
    if (drink.state == CookState.cooking) {
      drink.t += dt;
      if (drink.t >= venue.drinkFillTime) {
        drink.state = CookState.done;
        drink.t = 0;
        _emit(GameEvent("ready"));
      }
    }

    // Customer walk animations + patience.
    for (final c in customers) {
      switch (c.phase) {
        case CustomerPhase.walkingIn:
          c.walk = min(1, c.walk + dt / 0.8);
          if (c.walk >= 1) c.phase = CustomerPhase.waiting;
        case CustomerPhase.waiting:
          c.patience -= dt;
          if (c.patience <= 0) {
            c.phase = CustomerPhase.leavingAngry;
            c.walk = 0;
            lostCustomers++;
            combo = 0;
            _emit(GameEvent("angry",
                message: "A customer left angry!",
                customerIndex: customers.indexOf(c)));
          }
        case CustomerPhase.leavingHappy:
        case CustomerPhase.leavingAngry:
          c.walk = min(1, c.walk + dt / 0.7);
      }
    }
    customers.removeWhere((c) =>
        (c.phase == CustomerPhase.leavingHappy ||
            c.phase == CustomerPhase.leavingAngry) &&
        c.walk >= 1);

    // Spawning.
    if (spawned < level.customers && customers.length < maxWaiting) {
      _spawnTimer -= dt;
      if (_spawnTimer <= 0) {
        _spawnCustomer();
        final gapMin = max(2.5, _spawnGapMin);
        final gapMax = max(gapMin + 0.5, _spawnGapMax);
        _spawnTimer = gapMin + _rng.nextDouble() * (gapMax - gapMin);
      }
    }

    // End conditions.
    if (level.endless) {
      if (lostCustomers >= endlessLives) {
        phase = GamePhase.lost;
        _emit(GameEvent("over"));
      }
    } else if (spawned >= level.customers && customers.isEmpty) {
      phase = stars >= 1 ? GamePhase.won : GamePhase.lost;
      _emit(GameEvent("over"));
    }

    notifyListeners();
  }

  String _processedName() => switch (venue.flow) {
        VenueFlow.cookThenAssemble => "patty",
        VenueFlow.assembleThenCook => venue.mainLabel,
        VenueFlow.assembleThenRoll => venue.mainLabel,
      };

  void _advance(CookState state, double t, double cookTime, double burnWindow,
      void Function(CookState, double) set,
      {required VoidCallback whenBurnt}) {
    switch (state) {
      case CookState.cooking:
        set(t >= cookTime ? CookState.done : CookState.cooking,
            t >= cookTime ? 0 : t);
      case CookState.done:
        if (burnWindow > 0 && t >= burnWindow) {
          set(CookState.burnt, 0);
          whenBurnt();
        } else {
          set(CookState.done, t);
        }
      case CookState.empty:
      case CookState.burnt:
        break;
    }
  }

  // ------------------------------------------------------------- customers

  void _spawnCustomer() {
    final heavy = _rng.nextDouble() < level.heavyChance;
    final stack = <Ingredient>[];

    switch (venue.flow) {
      case VenueFlow.cookThenAssemble: // burger
        final available = List<Ingredient>.of(level.toppings)..shuffle(_rng);
        final nTop = level.toppings.isEmpty
            ? 0
            : _rng.nextInt(level.maxToppingsPerMain + 1);
        final toppings = available.take(nTop).toList()
          ..sort((a, b) => a.index - b.index);
        stack
          ..add(Ingredient.bunBottom)
          ..add(Ingredient.patty);
        if (heavy) stack.add(Ingredient.patty);
        stack
          ..addAll(toppings)
          ..add(Ingredient.bunTop);
      case VenueFlow.assembleThenCook: // pizza
        final available = List<Ingredient>.of(level.toppings)..shuffle(_rng);
        var nTop = level.toppings.isEmpty
            ? 0
            : _rng.nextInt(level.maxToppingsPerMain + 1);
        if (heavy && level.toppings.isNotEmpty) {
          nTop = level.maxToppingsPerMain;
        }
        final toppings = available.take(nTop).toList()
          ..sort((a, b) => a.index - b.index);
        stack
          ..addAll(venue.mandatory)
          ..addAll(toppings);
      case VenueFlow.assembleThenRoll: // sushi
        final available = List<Ingredient>.of(level.toppings)..shuffle(_rng);
        final nFill =
            (heavy && level.maxToppingsPerMain >= 2 && available.length >= 2)
                ? 2
                : 1;
        final fillings = available.take(nFill).toList()
          ..sort((a, b) => a.index - b.index);
        stack
          ..addAll(venue.mandatory)
          ..addAll(fillings);
    }

    final items = <OrderItem>[OrderItem.main(stack)];
    if (level.sides && _rng.nextDouble() < level.sideChance) {
      items.add(const OrderItem.side());
    }
    if (level.drinks && _rng.nextDouble() < level.drinkChance) {
      items.add(const OrderItem.drink());
    }

    customers.add(Customer(
      seed: _rng.nextInt(1 << 30),
      items: items,
      patienceTotal: max(12.0, _patiencePerItem) * items.length,
    ));
    spawned++;
  }

  // ---------------------------------------------------------------- inputs

  /// The plate the player is working on: the selected one if it has a
  /// dish started, otherwise the first started plate.
  Assembly? _targetAssembly() {
    if (assemblies[selectedAssembly].started) {
      return assemblies[selectedAssembly];
    }
    for (final a in assemblies) {
      if (a.started) return a;
    }
    return null;
  }

  /// Burger only: put a raw patty on the first free grill slot.
  bool tapRawTray() {
    if (phase != GamePhase.running ||
        venue.flow != VenueFlow.cookThenAssemble) {
      return false;
    }
    for (final p in processors) {
      if (p.state == CookState.empty) {
        p.state = CookState.cooking;
        p.t = 0;
        p.stack = const [];
        notifyListeners();
        return true;
      }
    }
    _emit(GameEvent("hint", message: "The grill is full!"));
    return false;
  }

  /// Tap a processor slot. Behaviour depends on the venue flow.
  bool tapProcessor(int i) {
    if (phase != GamePhase.running) return false;
    final p = processors[i];

    if (p.state == CookState.burnt) {
      p.state = CookState.empty;
      p.t = 0;
      p.stack = const [];
      notifyListeners();
      return true;
    }

    switch (venue.flow) {
      case VenueFlow.cookThenAssemble:
        // Collect a done patty onto the working assembly.
        if (p.state != CookState.done) return false;
        final a = _targetAssembly();
        if (a == null) {
          _emit(GameEvent("hint", message: "Start with a bun first!"));
          return false;
        }
        a.stack.add(venue.cookedComponent!);
        p.state = CookState.empty;
        p.t = 0;
        notifyListeners();
        return true;

      case VenueFlow.assembleThenCook:
      case VenueFlow.assembleThenRoll:
        if (p.state == CookState.done) {
          if (ready.length >= maxReady) {
            _emit(GameEvent("hint", message: "The pass is full — serve up!"));
            return false;
          }
          ready.add(ReadyItem.main(p.stack));
          p.state = CookState.empty;
          p.t = 0;
          p.stack = const [];
          notifyListeners();
          return true;
        }
        if (p.state == CookState.empty) {
          final a = _targetAssembly();
          if (a == null || !_assemblyProcessable(a)) {
            _emit(GameEvent("hint",
                message: venue.flow == VenueFlow.assembleThenCook
                    ? "Build dough, sauce and cheese first!"
                    : "A roll needs nori, rice and a filling!"));
            return false;
          }
          p.stack = List.of(a.stack);
          p.state = CookState.cooking;
          p.t = 0;
          a.stack.clear();
          notifyListeners();
          return true;
        }
        return false;
    }
  }

  bool _assemblyProcessable(Assembly a) =>
      a.stack.length > venue.mandatory.length ||
      (a.stack.length == venue.mandatory.length &&
          venue.flow == VenueFlow.assembleThenCook);

  /// Tap an ingredient tray (any mandatory base, topping, or the closer).
  bool tapTray(Ingredient ing) {
    if (phase != GamePhase.running) return false;

    // Closing tray (burger top bun) finishes the dish onto the pass.
    if (ing == venue.closer) return _tapCloser();

    // Base ingredient that starts a dish.
    if (ing == venue.mandatory.first) {
      for (var i = 0; i < assemblies.length; i++) {
        if (!assemblies[i].started) {
          assemblies[i].stack.add(ing);
          selectedAssembly = i;
          notifyListeners();
          return true;
        }
      }
      _emit(GameEvent("hint", message: "Both plates are busy!"));
      return false;
    }

    final a = _targetAssembly();
    if (a == null) {
      _emit(GameEvent("hint",
          message: "Start with ${venue.mandatory.first.label.toLowerCase()} first!"));
      return false;
    }

    // Later mandatory ingredients must follow canonical order.
    final mi = venue.mandatory.indexOf(ing);
    if (mi > 0) {
      if (a.stack.length != mi) {
        _emit(GameEvent("hint",
            message: "Add ${venue.mandatory[a.stack.length.clamp(0, venue.mandatory.length - 1)].label.toLowerCase()} next!"));
        return false;
      }
      a.stack.add(ing);
      notifyListeners();
      return true;
    }

    // Optional toppings need the full mandatory base (and, for burgers,
    // a cooked patty) underneath.
    if (!_baseComplete(a)) {
      _emit(GameEvent("hint",
          message: venue.flow == VenueFlow.cookThenAssemble
              ? "Add a grilled patty first!"
              : "Finish the base first!"));
      return false;
    }
    a.stack.add(ing);
    notifyListeners();
    return true;
  }

  bool _baseComplete(Assembly a) {
    switch (venue.flow) {
      case VenueFlow.cookThenAssemble:
        return a.stack.contains(venue.cookedComponent);
      case VenueFlow.assembleThenCook:
      case VenueFlow.assembleThenRoll:
        return a.stack.length >= venue.mandatory.length;
    }
  }

  bool _tapCloser() {
    final a = _targetAssembly();
    if (a == null || !_baseComplete(a)) {
      _emit(GameEvent("hint",
          message: "The ${venue.mainLabel} needs a patty!"));
      return false;
    }
    if (ready.length >= maxReady) {
      _emit(GameEvent("hint", message: "The pass is full — serve up!"));
      return false;
    }
    a.stack.add(venue.closer!);
    ready.add(ReadyItem.main(a.stack));
    a.stack.clear();
    notifyListeners();
    return true;
  }

  void selectAssembly(int i) {
    selectedAssembly = i;
    notifyListeners();
  }

  void trashAssembly(int i) {
    if (phase != GamePhase.running) return;
    assemblies[i].stack.clear();
    _emit(GameEvent("trash"));
    notifyListeners();
  }

  bool tapSide() {
    if (phase != GamePhase.running) return false;
    switch (side.state) {
      case CookState.empty:
        side.state = CookState.cooking;
        side.t = 0;
        notifyListeners();
        return true;
      case CookState.burnt:
        side.state = CookState.empty;
        side.t = 0;
        notifyListeners();
        return true;
      case CookState.done:
        if (ready.length >= maxReady) {
          _emit(GameEvent("hint", message: "The pass is full — serve up!"));
          return false;
        }
        ready.add(ReadyItem.side());
        side.state = CookState.empty;
        side.t = 0;
        notifyListeners();
        return true;
      case CookState.cooking:
        return false;
    }
  }

  bool tapDrink() {
    if (phase != GamePhase.running) return false;
    switch (drink.state) {
      case CookState.empty:
        drink.state = CookState.cooking;
        drink.t = 0;
        notifyListeners();
        return true;
      case CookState.done:
        if (ready.length >= maxReady) {
          _emit(GameEvent("hint", message: "The pass is full — serve up!"));
          return false;
        }
        ready.add(ReadyItem.drink());
        drink.state = CookState.empty;
        drink.t = 0;
        notifyListeners();
        return true;
      case CookState.cooking:
      case CookState.burnt:
        return false;
    }
  }

  /// Tap an item on the pass: serve it to the first waiting customer who
  /// wants it. Returns the customer index served, or -1 if nobody wants it.
  int serveReady(int readyIndex) {
    if (phase != GamePhase.running || readyIndex >= ready.length) return -1;
    final item = ready[readyIndex];
    for (var ci = 0; ci < customers.length; ci++) {
      final c = customers[ci];
      if (c.phase != CustomerPhase.waiting) continue;
      final wi = item.type == ItemType.main
          ? c.wantsMainIndex(item.stack)
          : c.wantsIndex(item.type);
      if (wi < 0) continue;

      c.served[wi] = true;
      final price = c.items[wi].price(venue);
      coins += price;
      _emit(GameEvent("coin",
          amount: price, customerIndex: ci, message: "+$price"));

      if (c.complete) {
        combo = min(combo + 1, 5);
        final tip = c.patienceFrac > 0.55
            ? 2 + combo
            : (c.patienceFrac > 0.25 ? 1 : 0);
        if (tip > 0) {
          coins += tip;
          tips += tip;
          _emit(GameEvent("coin",
              amount: tip, customerIndex: ci, message: "+$tip tip!"));
        }
        servedCustomers++;
        c.phase = CustomerPhase.leavingHappy;
        c.walk = 0;
        _emit(GameEvent("serve", customerIndex: ci));
      }
      ready.removeAt(readyIndex);
      notifyListeners();
      return ci;
    }
    _emit(GameEvent("hint", message: "Nobody ordered that right now."));
    return -1;
  }

  void trashReady(int readyIndex) {
    if (phase != GamePhase.running || readyIndex >= ready.length) return;
    ready.removeAt(readyIndex);
    _emit(GameEvent("trash"));
    notifyListeners();
  }
}
