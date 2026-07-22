import "dart:ui";

/// Everything that can appear in a burger stack, in canonical build order.
enum Ingredient { bunBottom, patty, cheese, tomato, lettuce, bunTop }

extension IngredientInfo on Ingredient {
  String get label => switch (this) {
        Ingredient.bunBottom => "Bun",
        Ingredient.patty => "Patty",
        Ingredient.cheese => "Cheese",
        Ingredient.tomato => "Tomato",
        Ingredient.lettuce => "Lettuce",
        Ingredient.bunTop => "Top Bun",
      };

  Color get color => switch (this) {
        Ingredient.bunBottom => const Color(0xFFE0A050),
        Ingredient.patty => const Color(0xFF6B3E26),
        Ingredient.cheese => const Color(0xFFFFC93C),
        Ingredient.tomato => const Color(0xFFE53935),
        Ingredient.lettuce => const Color(0xFF66BB6A),
        Ingredient.bunTop => const Color(0xFFE8A952),
      };

  bool get isTopping =>
      this == Ingredient.cheese ||
      this == Ingredient.tomato ||
      this == Ingredient.lettuce;
}

enum ItemType { burger, fries, drink }

/// One thing a customer wants: a burger with a specific stack, fries or drink.
class OrderItem {
  final ItemType type;

  /// For burgers: full stack including both buns, in canonical order.
  final List<Ingredient> stack;

  const OrderItem.burger(this.stack) : type = ItemType.burger;
  const OrderItem.fries()
      : type = ItemType.fries,
        stack = const [];
  const OrderItem.drink()
      : type = ItemType.drink,
        stack = const [];

  int get price => switch (type) {
        ItemType.burger => 8 + 3 * stack.where((i) => i.isTopping).length,
        ItemType.fries => 5,
        ItemType.drink => 4,
      };

  /// Whether a built burger stack fulfils this item. Topping order is
  /// irrelevant; the multiset of ingredients must match exactly.
  bool matchesStack(List<Ingredient> built) {
    if (type != ItemType.burger) return false;
    if (built.length != stack.length) return false;
    final want = List<Ingredient>.of(stack)..sort((a, b) => a.index - b.index);
    final have = List<Ingredient>.of(built)..sort((a, b) => a.index - b.index);
    for (var i = 0; i < want.length; i++) {
      if (want[i] != have[i]) return false;
    }
    return true;
  }
}

enum CustomerMood { happy, neutral, impatient, angry }

enum CustomerPhase { walkingIn, waiting, leavingHappy, leavingAngry }

class Customer {
  /// Drives the procedurally drawn avatar (skin/hair/shirt/hat).
  final int seed;
  final List<OrderItem> items;
  final List<bool> served;
  final double patienceTotal;
  double patience;
  CustomerPhase phase = CustomerPhase.walkingIn;

  /// 0..1 animation progress for walking in/out.
  double walk = 0;

  Customer({
    required this.seed,
    required this.items,
    required this.patienceTotal,
  })  : served = List<bool>.filled(items.length, false),
        patience = patienceTotal;

  bool get complete => served.every((s) => s);

  double get patienceFrac =>
      patienceTotal <= 0 ? 0 : (patience / patienceTotal).clamp(0.0, 1.0);

  CustomerMood get mood {
    if (phase == CustomerPhase.leavingAngry) return CustomerMood.angry;
    if (phase == CustomerPhase.leavingHappy) return CustomerMood.happy;
    final f = patienceFrac;
    if (f > 0.6) return CustomerMood.happy;
    if (f > 0.3) return CustomerMood.neutral;
    return CustomerMood.impatient;
  }

  /// First unserved item of the given type, or -1.
  int wantsIndex(ItemType type) {
    for (var i = 0; i < items.length; i++) {
      if (!served[i] && items[i].type == type) return i;
    }
    return -1;
  }

  /// First unserved burger item matching the built stack, or -1.
  int wantsBurgerIndex(List<Ingredient> built) {
    for (var i = 0; i < items.length; i++) {
      if (!served[i] && items[i].matchesStack(built)) return i;
    }
    return -1;
  }
}

/// Static definition of one level.
class LevelDef {
  final int id;
  final String title;
  final String blurb;
  final int customers;

  /// Seconds between customer arrivals (min..max).
  final double spawnGapMin;
  final double spawnGapMax;

  /// Base patience in seconds per order item.
  final double patiencePerItem;
  final int grillSlots;
  final List<Ingredient> toppings;
  final int maxToppingsPerBurger;
  final double burgerTwoPattyChance;
  final bool fries;
  final bool drinks;
  final double friesChance;
  final double drinkChance;

  /// Coins needed for 1 / 2 / 3 stars.
  final List<int> starCoins;

  const LevelDef({
    required this.id,
    required this.title,
    required this.blurb,
    required this.customers,
    required this.spawnGapMin,
    required this.spawnGapMax,
    required this.patiencePerItem,
    required this.grillSlots,
    required this.toppings,
    required this.maxToppingsPerBurger,
    this.burgerTwoPattyChance = 0,
    this.fries = false,
    this.drinks = false,
    this.friesChance = 0.5,
    this.drinkChance = 0.5,
    required this.starCoins,
  });
}

const List<LevelDef> kLevels = [
  LevelDef(
    id: 1,
    title: "First Shift",
    blurb: "Learn the grill. Plain burgers only.",
    customers: 4,
    spawnGapMin: 9,
    spawnGapMax: 12,
    patiencePerItem: 40,
    grillSlots: 2,
    toppings: [],
    maxToppingsPerBurger: 0,
    starCoins: [16, 24, 32],
  ),
  LevelDef(
    id: 2,
    title: "Say Cheese",
    blurb: "Cheeseburgers join the menu.",
    customers: 5,
    spawnGapMin: 8,
    spawnGapMax: 11,
    patiencePerItem: 36,
    grillSlots: 2,
    toppings: [Ingredient.cheese],
    maxToppingsPerBurger: 1,
    starCoins: [25, 38, 50],
  ),
  LevelDef(
    id: 3,
    title: "Fresh & Crisp",
    blurb: "Tomato and lettuce arrive.",
    customers: 6,
    spawnGapMin: 8,
    spawnGapMax: 11,
    patiencePerItem: 34,
    grillSlots: 2,
    toppings: [Ingredient.cheese, Ingredient.tomato, Ingredient.lettuce],
    maxToppingsPerBurger: 2,
    starCoins: [35, 52, 70],
  ),
  LevelDef(
    id: 4,
    title: "Side of Fries",
    blurb: "The fryer is installed. Watch the timer!",
    customers: 6,
    spawnGapMin: 8,
    spawnGapMax: 10,
    patiencePerItem: 32,
    grillSlots: 2,
    toppings: [Ingredient.cheese, Ingredient.tomato],
    maxToppingsPerBurger: 2,
    fries: true,
    friesChance: 0.6,
    starCoins: [42, 62, 82],
  ),
  LevelDef(
    id: 5,
    title: "Thirsty Crowd",
    blurb: "Cold drinks on tap.",
    customers: 7,
    spawnGapMin: 7.5,
    spawnGapMax: 10,
    patiencePerItem: 30,
    grillSlots: 3,
    toppings: [Ingredient.cheese, Ingredient.tomato, Ingredient.lettuce],
    maxToppingsPerBurger: 2,
    fries: true,
    drinks: true,
    friesChance: 0.5,
    drinkChance: 0.5,
    starCoins: [55, 80, 105],
  ),
  LevelDef(
    id: 6,
    title: "Lunch Rush",
    blurb: "The office crowd pours in.",
    customers: 8,
    spawnGapMin: 6.5,
    spawnGapMax: 9,
    patiencePerItem: 28,
    grillSlots: 3,
    toppings: [Ingredient.cheese, Ingredient.tomato, Ingredient.lettuce],
    maxToppingsPerBurger: 3,
    fries: true,
    drinks: true,
    starCoins: [70, 98, 128],
  ),
  LevelDef(
    id: 7,
    title: "Double Trouble",
    blurb: "Some folks want double patties.",
    customers: 8,
    spawnGapMin: 6.5,
    spawnGapMax: 9,
    patiencePerItem: 28,
    grillSlots: 3,
    toppings: [Ingredient.cheese, Ingredient.tomato, Ingredient.lettuce],
    maxToppingsPerBurger: 2,
    burgerTwoPattyChance: 0.35,
    fries: true,
    drinks: true,
    starCoins: [78, 108, 140],
  ),
  LevelDef(
    id: 8,
    title: "Food Critics",
    blurb: "Picky eaters with short fuses.",
    customers: 9,
    spawnGapMin: 6,
    spawnGapMax: 8.5,
    patiencePerItem: 24,
    grillSlots: 3,
    toppings: [Ingredient.cheese, Ingredient.tomato, Ingredient.lettuce],
    maxToppingsPerBurger: 3,
    burgerTwoPattyChance: 0.3,
    fries: true,
    drinks: true,
    starCoins: [90, 122, 158],
  ),
  LevelDef(
    id: 9,
    title: "Game Night",
    blurb: "Everyone orders sides tonight.",
    customers: 10,
    spawnGapMin: 5.5,
    spawnGapMax: 8,
    patiencePerItem: 24,
    grillSlots: 4,
    toppings: [Ingredient.cheese, Ingredient.tomato, Ingredient.lettuce],
    maxToppingsPerBurger: 3,
    burgerTwoPattyChance: 0.35,
    fries: true,
    drinks: true,
    friesChance: 0.7,
    drinkChance: 0.7,
    starCoins: [105, 142, 182],
  ),
  LevelDef(
    id: 10,
    title: "Saturday Slam",
    blurb: "Weekend crowds wait for no one.",
    customers: 11,
    spawnGapMin: 5,
    spawnGapMax: 7.5,
    patiencePerItem: 22,
    grillSlots: 4,
    toppings: [Ingredient.cheese, Ingredient.tomato, Ingredient.lettuce],
    maxToppingsPerBurger: 3,
    burgerTwoPattyChance: 0.4,
    fries: true,
    drinks: true,
    friesChance: 0.65,
    drinkChance: 0.65,
    starCoins: [120, 162, 208],
  ),
  LevelDef(
    id: 11,
    title: "Festival Stand",
    blurb: "A festival outside your window.",
    customers: 12,
    spawnGapMin: 4.5,
    spawnGapMax: 7,
    patiencePerItem: 21,
    grillSlots: 4,
    toppings: [Ingredient.cheese, Ingredient.tomato, Ingredient.lettuce],
    maxToppingsPerBurger: 3,
    burgerTwoPattyChance: 0.45,
    fries: true,
    drinks: true,
    friesChance: 0.7,
    drinkChance: 0.7,
    starCoins: [138, 185, 236],
  ),
  LevelDef(
    id: 12,
    title: "Master Chef",
    blurb: "The final service. Prove yourself.",
    customers: 14,
    spawnGapMin: 4,
    spawnGapMax: 6.5,
    patiencePerItem: 20,
    grillSlots: 4,
    toppings: [Ingredient.cheese, Ingredient.tomato, Ingredient.lettuce],
    maxToppingsPerBurger: 3,
    burgerTwoPattyChance: 0.5,
    fries: true,
    drinks: true,
    friesChance: 0.75,
    drinkChance: 0.75,
    starCoins: [165, 220, 280],
  ),
];
