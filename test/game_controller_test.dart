import "package:flutter_test/flutter_test.dart";
import "package:tideview/game/controller.dart";
import "package:tideview/game/models.dart";

void main() {
  KitchenController newGame({int levelIndex = 0, int seed = 42}) {
    final g = KitchenController(kLevels[levelIndex], seed: seed);
    g.start();
    return g;
  }

  group("grill", () {
    test("patty cooks, is ready, then burns", () {
      final g = newGame();
      expect(g.tapPattyTray(), isTrue);
      expect(g.grill[0].state, CookState.cooking);

      g.tick(KitchenController.grillCookTime + 0.1);
      expect(g.grill[0].state, CookState.done);

      g.tick(KitchenController.grillDoneWindow + 0.1);
      expect(g.grill[0].state, CookState.burnt);

      // Tapping a burnt patty discards it.
      expect(g.tapGrillSlot(0), isTrue);
      expect(g.grill[0].state, CookState.empty);
    });

    test("patty tray fills free slots only", () {
      final g = newGame();
      for (var i = 0; i < g.grill.length; i++) {
        expect(g.tapPattyTray(), isTrue);
      }
      expect(g.tapPattyTray(), isFalse);
    });
  });

  group("assembly", () {
    test("full burger build reaches the pass", () {
      final g = newGame();
      g.tapPattyTray();
      g.tick(KitchenController.grillCookTime + 0.1);

      expect(g.tapBunTray(), isTrue);
      expect(g.tapGrillSlot(0), isTrue);
      expect(g.tapTopBun(), isTrue);

      expect(g.ready.length, 1);
      expect(g.ready[0].type, ItemType.burger);
      expect(g.ready[0].stack, [
        Ingredient.bunBottom,
        Ingredient.patty,
        Ingredient.bunTop,
      ]);
      expect(g.assemblies[0].stack, isEmpty);
    });

    test("patty requires a started plate", () {
      final g = newGame();
      g.tapPattyTray();
      g.tick(KitchenController.grillCookTime + 0.1);
      expect(g.tapGrillSlot(0), isFalse);
      expect(g.grill[0].state, CookState.done);
    });

    test("top bun requires a patty", () {
      final g = newGame();
      g.tapBunTray();
      expect(g.tapTopBun(), isFalse);
    });
  });

  group("orders and serving", () {
    test("matching burger is served for coins", () {
      final g = newGame();
      // Force a customer in.
      g.tick(3.0);
      while (g.customers.isEmpty) {
        g.tick(1.0);
      }
      // Walk-in completes.
      g.tick(1.0);
      final customer = g.customers[0];
      final burger =
          customer.items.firstWhere((i) => i.type == ItemType.burger);

      // Level 1 burgers are always bun + patty + bun.
      expect(burger.stack,
          [Ingredient.bunBottom, Ingredient.patty, Ingredient.bunTop]);

      g.tapPattyTray();
      g.tick(KitchenController.grillCookTime + 0.1);
      g.tapBunTray();
      g.tapGrillSlot(0);
      g.tapTopBun();

      final before = g.coins;
      expect(g.serveReady(0), 0);
      expect(g.coins, greaterThan(before));
      expect(g.ready, isEmpty);
    });

    test("order matching ignores topping order", () {
      const item = OrderItem.burger([
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
      final g = newGame();
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
      final g = newGame();
      // Let every customer spawn and storm out unserved.
      for (var i = 0; i < 600 && !g.isOver; i++) {
        g.tick(1.0);
      }
      expect(g.isOver, isTrue);
      expect(g.phase, GamePhase.lost);
      expect(g.lostCustomers, kLevels[0].customers);
    });

    test("stars follow coin thresholds", () {
      final g = newGame();
      expect(g.stars, 0);
      g.coins = kLevels[0].starCoins[0];
      expect(g.stars, 1);
      g.coins = kLevels[0].starCoins[2];
      expect(g.stars, 3);
    });

    test("pause stops the simulation", () {
      final g = newGame();
      g.tapPattyTray();
      g.pause();
      g.tick(10);
      expect(g.grill[0].state, CookState.cooking);
      expect(g.grill[0].t, 0);
      g.resume();
      g.tick(KitchenController.grillCookTime + 0.1);
      expect(g.grill[0].state, CookState.done);
    });
  });

  group("level definitions", () {
    test("12 levels with ascending star thresholds", () {
      expect(kLevels.length, 12);
      for (final l in kLevels) {
        expect(l.starCoins.length, 3);
        expect(l.starCoins[0], lessThan(l.starCoins[1]));
        expect(l.starCoins[1], lessThan(l.starCoins[2]));
        expect(l.spawnGapMin, lessThanOrEqualTo(l.spawnGapMax));
        expect(l.grillSlots, inInclusiveRange(2, 4));
      }
    });
  });
}
