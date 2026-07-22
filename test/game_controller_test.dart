import "package:flutter_test/flutter_test.dart";
import "package:tideview/game/controller.dart";
import "package:tideview/game/models.dart";

void main() {
  KitchenController newGame(List<LevelDef> levels,
      {int levelIndex = 0, int seed = 42}) {
    final g = KitchenController(levels[levelIndex], seed: seed);
    g.start();
    return g;
  }

  group("burger grill", () {
    test("patty cooks, is ready, then burns", () {
      final g = newGame(kBurgerLevels);
      expect(g.tapRawTray(), isTrue);
      expect(g.processors[0].state, CookState.cooking);

      g.tick(g.venue.processTime + 0.1);
      expect(g.processors[0].state, CookState.done);

      g.tick(g.venue.processBurnWindow + 0.1);
      expect(g.processors[0].state, CookState.burnt);

      // Tapping a burnt patty discards it.
      expect(g.tapProcessor(0), isTrue);
      expect(g.processors[0].state, CookState.empty);
    });

    test("raw tray fills free slots only", () {
      final g = newGame(kBurgerLevels);
      for (var i = 0; i < g.processors.length; i++) {
        expect(g.tapRawTray(), isTrue);
      }
      expect(g.tapRawTray(), isFalse);
    });

    test("full burger build reaches the pass", () {
      final g = newGame(kBurgerLevels);
      g.tapRawTray();
      g.tick(g.venue.processTime + 0.1);

      expect(g.tapTray(Ingredient.bunBottom), isTrue);
      expect(g.tapProcessor(0), isTrue);
      expect(g.tapTray(Ingredient.bunTop), isTrue);

      expect(g.ready.length, 1);
      expect(g.ready[0].type, ItemType.main);
      expect(g.ready[0].stack, [
        Ingredient.bunBottom,
        Ingredient.patty,
        Ingredient.bunTop,
      ]);
      expect(g.assemblies[0].stack, isEmpty);
    });

    test("patty requires a started plate; top bun requires a patty", () {
      final g = newGame(kBurgerLevels);
      g.tapRawTray();
      g.tick(g.venue.processTime + 0.1);
      expect(g.tapProcessor(0), isFalse);
      expect(g.processors[0].state, CookState.done);

      g.tapTray(Ingredient.bunBottom);
      expect(g.tapTray(Ingredient.bunTop), isFalse);
    });

    test("toppings need a patty underneath", () {
      final g = newGame(kBurgerLevels, levelIndex: 3);
      g.tapTray(Ingredient.bunBottom);
      expect(g.tapTray(Ingredient.cheese), isFalse);
    });
  });

  group("pizza oven", () {
    test("mandatory build order is enforced", () {
      final g = newGame(kPizzaLevels);
      expect(g.tapTray(Ingredient.mozzarella), isFalse);
      expect(g.tapTray(Ingredient.dough), isTrue);
      expect(g.tapTray(Ingredient.mozzarella), isFalse); // sauce first
      expect(g.tapTray(Ingredient.pizzaSauce), isTrue);
      expect(g.tapTray(Ingredient.mozzarella), isTrue);
    });

    test("assembled pizza bakes and reaches the pass", () {
      final g = newGame(kPizzaLevels);
      g.tapTray(Ingredient.dough);
      g.tapTray(Ingredient.pizzaSauce);
      g.tapTray(Ingredient.mozzarella);

      // Empty oven slot takes the assembly.
      expect(g.tapProcessor(0), isTrue);
      expect(g.assemblies[0].stack, isEmpty);
      expect(g.processors[0].state, CookState.cooking);
      expect(g.processors[0].stack, [
        Ingredient.dough,
        Ingredient.pizzaSauce,
        Ingredient.mozzarella,
      ]);

      g.tick(g.venue.processTime + 0.1);
      expect(g.processors[0].state, CookState.done);

      expect(g.tapProcessor(0), isTrue);
      expect(g.ready.length, 1);
      expect(g.ready[0].stack.contains(Ingredient.mozzarella), isTrue);
    });

    test("incomplete pizza cannot enter the oven", () {
      final g = newGame(kPizzaLevels);
      g.tapTray(Ingredient.dough);
      g.tapTray(Ingredient.pizzaSauce);
      expect(g.tapProcessor(0), isFalse);
      expect(g.processors[0].state, CookState.empty);
    });

    test("forgotten pizza burns", () {
      final g = newGame(kPizzaLevels);
      g.tapTray(Ingredient.dough);
      g.tapTray(Ingredient.pizzaSauce);
      g.tapTray(Ingredient.mozzarella);
      g.tapProcessor(0);
      g.tick(g.venue.processTime + 0.1);
      expect(g.processors[0].state, CookState.done);
      g.tick(g.venue.processBurnWindow + 0.1);
      expect(g.processors[0].state, CookState.burnt);
    });
  });

  group("sushi mat", () {
    test("roll needs nori, rice and a filling", () {
      final g = newGame(kSushiLevels);
      g.tapTray(Ingredient.nori);
      g.tapTray(Ingredient.rice);
      expect(g.tapProcessor(0), isFalse); // no filling yet
      expect(g.tapTray(Ingredient.salmon), isTrue);
      expect(g.tapProcessor(0), isTrue);
      expect(g.processors[0].state, CookState.cooking);
    });

    test("rolls never burn", () {
      final g = newGame(kSushiLevels);
      g.tapTray(Ingredient.nori);
      g.tapTray(Ingredient.rice);
      g.tapTray(Ingredient.salmon);
      g.tapProcessor(0);
      g.tick(g.venue.processTime + 60);
      expect(g.processors[0].state, CookState.done);
      expect(g.tapProcessor(0), isTrue);
      expect(g.ready.length, 1);
    });

    test("rice must follow nori", () {
      final g = newGame(kSushiLevels);
      expect(g.tapTray(Ingredient.rice), isFalse);
      g.tapTray(Ingredient.nori);
      expect(g.tapTray(Ingredient.salmon), isFalse); // rice first
      expect(g.tapTray(Ingredient.rice), isTrue);
    });
  });

  group("orders and serving", () {
    test("matching burger is served for coins", () {
      final g = newGame(kBurgerLevels);
      g.tick(3.0);
      while (g.customers.isEmpty) {
        g.tick(1.0);
      }
      g.tick(1.0); // walk-in completes
      final customer = g.customers[0];
      final main = customer.items.firstWhere((i) => i.type == ItemType.main);
      expect(main.stack,
          [Ingredient.bunBottom, Ingredient.patty, Ingredient.bunTop]);

      g.tapRawTray();
      g.tick(g.venue.processTime + 0.1);
      g.tapTray(Ingredient.bunBottom);
      g.tapProcessor(0);
      g.tapTray(Ingredient.bunTop);

      final before = g.coins;
      expect(g.serveReady(0), 0);
      expect(g.coins, greaterThan(before));
      expect(g.ready, isEmpty);
    });

    test("order matching ignores topping order", () {
      const item = OrderItem.main([
        Ingredient.bunBottom,
        Ingredient.patty,
        Ingredient.cheese,
        Ingredient.tomato,
        Ingredient.bunTop,
      ]);
      expect(
          item.matchesStack(const [
            Ingredient.bunBottom,
            Ingredient.patty,
            Ingredient.tomato,
            Ingredient.cheese,
            Ingredient.bunTop,
          ]),
          isTrue);
      expect(
          item.matchesStack(const [
            Ingredient.bunBottom,
            Ingredient.patty,
            Ingredient.cheese,
            Ingredient.bunTop,
          ]),
          isFalse);
    });

    test("customer leaves angry when patience runs out", () {
      final g = newGame(kBurgerLevels);
      g.tick(3.0);
      while (g.customers.isEmpty) {
        g.tick(1.0);
      }
      g.tick(1.0);
      final total = g.customers[0].patienceTotal;
      g.tick(total + 1);
      expect(g.lostCustomers, greaterThanOrEqualTo(1));
    });
  });

  group("level lifecycle", () {
    test("level ends after all customers resolved", () {
      final g = newGame(kBurgerLevels);
      for (var i = 0; i < 600 && !g.isOver; i++) {
        g.tick(1.0);
      }
      expect(g.isOver, isTrue);
      expect(g.phase, GamePhase.lost);
      expect(g.lostCustomers, kBurgerLevels[0].customers);
    });

    test("stars follow coin thresholds", () {
      final g = newGame(kPizzaLevels);
      expect(g.stars, 0);
      g.coins = kPizzaLevels[0].starCoins[0];
      expect(g.stars, 1);
      g.coins = kPizzaLevels[0].starCoins[2];
      expect(g.stars, 3);
    });

    test("pause stops the simulation", () {
      final g = newGame(kBurgerLevels);
      g.tapRawTray();
      g.pause();
      g.tick(10);
      expect(g.processors[0].state, CookState.cooking);
      expect(g.processors[0].t, 0);
      g.resume();
      g.tick(g.venue.processTime + 0.1);
      expect(g.processors[0].state, CookState.done);
    });
  });

  group("endless mode", () {
    test("three walk-outs end the run", () {
      final g = KitchenController(endlessLevel(VenueId.burger), seed: 7)
        ..start();
      for (var i = 0; i < 1200 && !g.isOver; i++) {
        g.tick(1.0);
      }
      expect(g.isOver, isTrue);
      expect(g.phase, GamePhase.lost);
      expect(g.lostCustomers, KitchenController.endlessLives);
      expect(g.livesLeft, 0);
    });

    test("spawning never stops while lives remain", () {
      final g = KitchenController(endlessLevel(VenueId.sushi), seed: 7)
        ..start();
      var lastSpawned = 0;
      for (var i = 0; i < 60 && g.lostCustomers < 2; i++) {
        g.tick(1.0);
        lastSpawned = g.spawned;
      }
      expect(lastSpawned, greaterThan(2));
    });
  });

  group("level definitions", () {
    test("12 levels per venue with sane, ascending thresholds", () {
      for (final venue in kVenues) {
        final levels = levelsFor(venue.id);
        expect(levels.length, 12);
        for (final l in levels) {
          expect(l.starCoins.length, 3);
          expect(l.starCoins[0], lessThan(l.starCoins[1]));
          expect(l.starCoins[1], lessThan(l.starCoins[2]));
          expect(l.spawnGapMin, lessThanOrEqualTo(l.spawnGapMax));
          expect(l.processorSlots, inInclusiveRange(2, 4));
          expect(l.venue.id, venue.id);
        }
      }
    });

    test("sushi orders always include a filling", () {
      final g = newGame(kSushiLevels, seed: 3);
      for (var i = 0; i < 200 && g.customers.length < 2; i++) {
        g.tick(0.5);
      }
      for (final c in g.customers) {
        final main = c.items.firstWhere((i) => i.type == ItemType.main);
        expect(main.stack.length, greaterThanOrEqualTo(3));
        expect(main.stack.sublist(0, 2),
            [Ingredient.nori, Ingredient.rice]);
      }
    });
  });
}
