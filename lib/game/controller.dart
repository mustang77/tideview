import "dart:math";

import "package:flutter/foundation.dart";

import "models.dart";

enum CookState { empty, cooking, done, burnt }

class GrillSlot {
  CookState state = CookState.empty;
  double t = 0;
}

class FryerState {
  CookState state = CookState.empty;
  double t = 0;
}

class DrinkState {
  CookState state = CookState.empty; // cooking = filling
  double t = 0;
}

/// An in-progress burger on an assembly plate.
class Assembly {
  final List<Ingredient> stack = [];
  bool get started => stack.isNotEmpty;
  bool get complete => stack.isNotEmpty && stack.last == Ingredient.bunTop;
  bool get hasPatty => stack.contains(Ingredient.patty);
}

/// A finished item sitting on the pass, waiting to be served.
class ReadyItem {
  final ItemType type;
  final List<Ingredient> stack;
  ReadyItem.burger(List<Ingredient> s)
      : type = ItemType.burger,
        stack = List.of(s);
  ReadyItem.fries()
      : type = ItemType.fries,
        stack = const [];
  ReadyItem.drink()
      : type = ItemType.drink,
        stack = const [];
}

enum GamePhase { intro, running, paused, won, lost }

/// A transient event the UI can animate (coin popups, serve flights...).
class GameEvent {
  final String kind; // serve | coin | angry | burnt | hint
  final String message;
  final int amount;
  final int customerIndex;
  GameEvent(this.kind,
      {this.message = "", this.amount = 0, this.customerIndex = -1});
}

/// All simulation state and rules for one level. UI listens and repaints.
class KitchenController extends ChangeNotifier {
  static const double grillCookTime = 5.0;
  static const double grillDoneWindow = 6.0;
  static const double fryCookTime = 6.0;
  static const double fryDoneWindow = 7.0;
  static const double drinkFillTime = 2.5;
  static const int maxWaiting = 4;
  static const int maxReady = 3;

  final LevelDef level;
  final Random _rng;

  final List<GrillSlot> grill;
  final FryerState fryer = FryerState();
  final DrinkState drink = DrinkState();
  final List<Assembly> assemblies = [Assembly(), Assembly()];
  int selectedAssembly = 0;
  final List<ReadyItem> ready = [];

  final List<Customer> customers = [];
  int spawned = 0;
  double _spawnTimer = 1.5;

  GamePhase phase = GamePhase.intro;
  int coins = 0;
  int tips = 0;
  int servedCustomers = 0;
  int lostCustomers = 0;
  int combo = 0;
  double elapsed = 0;

  final List<GameEvent> events = [];

  KitchenController(this.level, {int? seed})
      : _rng = Random(seed),
        grill = List.generate(level.grillSlots, (_) => GrillSlot());

  int get stars {
    if (coins >= level.starCoins[2]) return 3;
    if (coins >= level.starCoins[1]) return 2;
    if (coins >= level.starCoins[0]) return 1;
    return 0;
  }

  int get goalCoins => level.starCoins[0];

  bool get isOver => phase == GamePhase.won || phase == GamePhase.lost;

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

  /// Pull pending UI events (popups etc). The UI drains this every frame.
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

    for (final s in grill) {
      _advanceCook(s.state, s.t + dt, grillCookTime, grillDoneWindow,
          (st, t) {
        s.state = st;
        s.t = t;
      }, whenBurnt: () => _emit(GameEvent("burnt", message: "A patty burnt!")));
    }
    if (fryer.state != CookState.empty) {
      _advanceCook(fryer.state, fryer.t + dt, fryCookTime, fryDoneWindow,
          (st, t) {
        fryer.state = st;
        fryer.t = t;
      }, whenBurnt: () => _emit(GameEvent("burnt", message: "Fries burnt!")));
    }
    if (drink.state == CookState.cooking) {
      drink.t += dt;
      if (drink.t >= drinkFillTime) {
        drink.state = CookState.done;
        drink.t = 0;
      }
    }

    // Customer walk animations.
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
        _spawnTimer = level.spawnGapMin +
            _rng.nextDouble() * (level.spawnGapMax - level.spawnGapMin);
      }
    }

    // End of level.
    if (spawned >= level.customers && customers.isEmpty) {
      phase = stars >= 1 ? GamePhase.won : GamePhase.lost;
    }

    notifyListeners();
  }

  void _advanceCook(CookState state, double t, double cookTime,
      double doneWindow, void Function(CookState, double) set,
      {required VoidCallback whenBurnt}) {
    switch (state) {
      case CookState.cooking:
        if (t >= cookTime) {
          set(CookState.done, 0);
        } else {
          set(CookState.cooking, t);
        }
      case CookState.done:
        if (t >= doneWindow) {
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
    final items = <OrderItem>[];
    final patties =
        _rng.nextDouble() < level.burgerTwoPattyChance ? 2 : 1;
    final available = List<Ingredient>.of(level.toppings)..shuffle(_rng);
    final nToppings = level.toppings.isEmpty
        ? 0
        : _rng.nextInt(level.maxToppingsPerBurger + 1);
    final toppings = available.take(nToppings).toList()
      ..sort((a, b) => a.index - b.index);
    items.add(OrderItem.burger([
      Ingredient.bunBottom,
      for (var i = 0; i < patties; i++) Ingredient.patty,
      ...toppings,
      Ingredient.bunTop,
    ]));
    if (level.fries && _rng.nextDouble() < level.friesChance) {
      items.add(const OrderItem.fries());
    }
    if (level.drinks && _rng.nextDouble() < level.drinkChance) {
      items.add(const OrderItem.drink());
    }

    customers.add(Customer(
      seed: _rng.nextInt(1 << 30),
      items: items,
      patienceTotal: level.patiencePerItem * items.length,
    ));
    spawned++;
  }

  // ---------------------------------------------------------------- inputs

  /// Tap the raw patty tray: put a patty on the first free grill slot.
  bool tapPattyTray() {
    if (phase != GamePhase.running) return false;
    for (final s in grill) {
      if (s.state == CookState.empty) {
        s.state = CookState.cooking;
        s.t = 0;
        notifyListeners();
        return true;
      }
    }
    return false;
  }

  /// Tap a grill slot: collect a done patty onto the selected assembly,
  /// or discard a burnt one.
  bool tapGrillSlot(int i) {
    if (phase != GamePhase.running) return false;
    final s = grill[i];
    if (s.state == CookState.burnt) {
      s.state = CookState.empty;
      s.t = 0;
      notifyListeners();
      return true;
    }
    if (s.state == CookState.done) {
      final a = _targetAssembly();
      if (a == null || !a.started || a.complete) {
        _emit(GameEvent("hint", message: "Start with a bun first!"));
        return false;
      }
      a.stack.add(Ingredient.patty);
      s.state = CookState.empty;
      s.t = 0;
      notifyListeners();
      return true;
    }
    return false;
  }

  Assembly? _targetAssembly() {
    final sel = assemblies[selectedAssembly];
    if (sel.started && !sel.complete) return sel;
    for (final a in assemblies) {
      if (a.started && !a.complete) return a;
    }
    return null;
  }

  /// Tap the bun tray: start a burger on the first empty plate.
  bool tapBunTray() {
    if (phase != GamePhase.running) return false;
    for (var i = 0; i < assemblies.length; i++) {
      if (!assemblies[i].started) {
        assemblies[i].stack.add(Ingredient.bunBottom);
        selectedAssembly = i;
        notifyListeners();
        return true;
      }
    }
    _emit(GameEvent("hint", message: "Both plates are busy!"));
    return false;
  }

  bool tapTopping(Ingredient topping) {
    if (phase != GamePhase.running) return false;
    final a = _targetAssembly();
    if (a == null) {
      _emit(GameEvent("hint", message: "Start with a bun first!"));
      return false;
    }
    if (!a.hasPatty) {
      _emit(GameEvent("hint", message: "Add a grilled patty first!"));
      return false;
    }
    a.stack.add(topping);
    notifyListeners();
    return true;
  }

  /// Tap the top-bun tray: close the burger and move it to the pass.
  bool tapTopBun() {
    if (phase != GamePhase.running) return false;
    final a = _targetAssembly();
    if (a == null || !a.hasPatty) {
      _emit(GameEvent("hint", message: "The burger needs a patty!"));
      return false;
    }
    if (ready.length >= maxReady) {
      _emit(GameEvent("hint", message: "The pass is full — serve items!"));
      return false;
    }
    a.stack.add(Ingredient.bunTop);
    ready.add(ReadyItem.burger(a.stack));
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
    notifyListeners();
  }

  bool tapFryer() {
    if (phase != GamePhase.running) return false;
    switch (fryer.state) {
      case CookState.empty:
        fryer.state = CookState.cooking;
        fryer.t = 0;
        notifyListeners();
        return true;
      case CookState.burnt:
        fryer.state = CookState.empty;
        fryer.t = 0;
        notifyListeners();
        return true;
      case CookState.done:
        if (ready.length >= maxReady) {
          _emit(GameEvent("hint", message: "The pass is full — serve items!"));
          return false;
        }
        ready.add(ReadyItem.fries());
        fryer.state = CookState.empty;
        fryer.t = 0;
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
          _emit(GameEvent("hint", message: "The pass is full — serve items!"));
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
      final wi = item.type == ItemType.burger
          ? c.wantsBurgerIndex(item.stack)
          : c.wantsIndex(item.type);
      if (wi < 0) continue;

      c.served[wi] = true;
      final price = c.items[wi].price;
      coins += price;
      _emit(GameEvent("coin",
          amount: price, customerIndex: ci, message: "+$price"));

      if (c.complete) {
        combo = min(combo + 1, 5);
        final tip = c.patienceFrac > 0.55 ? 2 + combo : (c.patienceFrac > 0.25 ? 1 : 0);
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
    notifyListeners();
  }
}
