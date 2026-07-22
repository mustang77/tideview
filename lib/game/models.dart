import "dart:ui";

/// Every ingredient across all venues, in each venue's canonical build order.
enum Ingredient {
  // Burger Bar
  bunBottom,
  patty,
  cheese,
  tomato,
  lettuce,
  bunTop,
  // Pizza Palace
  dough,
  pizzaSauce,
  mozzarella,
  pepperoni,
  mushroom,
  olive,
  // Sushi Dock
  nori,
  rice,
  salmon,
  tuna,
  shrimp,
  cucumber,
}

extension IngredientInfo on Ingredient {
  String get label => switch (this) {
        Ingredient.bunBottom => "Bun",
        Ingredient.patty => "Patty",
        Ingredient.cheese => "Cheese",
        Ingredient.tomato => "Tomato",
        Ingredient.lettuce => "Lettuce",
        Ingredient.bunTop => "Top",
        Ingredient.dough => "Dough",
        Ingredient.pizzaSauce => "Sauce",
        Ingredient.mozzarella => "Cheese",
        Ingredient.pepperoni => "Pepperoni",
        Ingredient.mushroom => "Mushroom",
        Ingredient.olive => "Olive",
        Ingredient.nori => "Nori",
        Ingredient.rice => "Rice",
        Ingredient.salmon => "Salmon",
        Ingredient.tuna => "Tuna",
        Ingredient.shrimp => "Shrimp",
        Ingredient.cucumber => "Cucumber",
      };

  Color get color => switch (this) {
        Ingredient.bunBottom => const Color(0xFFE0A050),
        Ingredient.patty => const Color(0xFF6B3E26),
        Ingredient.cheese => const Color(0xFFFFC93C),
        Ingredient.tomato => const Color(0xFFE53935),
        Ingredient.lettuce => const Color(0xFF66BB6A),
        Ingredient.bunTop => const Color(0xFFE8A952),
        Ingredient.dough => const Color(0xFFEFD9A7),
        Ingredient.pizzaSauce => const Color(0xFFC63D2F),
        Ingredient.mozzarella => const Color(0xFFF7E8B0),
        Ingredient.pepperoni => const Color(0xFFB3402E),
        Ingredient.mushroom => const Color(0xFFC9B79C),
        Ingredient.olive => const Color(0xFF3A3F2E),
        Ingredient.nori => const Color(0xFF1E3B2A),
        Ingredient.rice => const Color(0xFFF5F2E8),
        Ingredient.salmon => const Color(0xFFFA8A6B),
        Ingredient.tuna => const Color(0xFFD64560),
        Ingredient.shrimp => const Color(0xFFF6B8A2),
        Ingredient.cucumber => const Color(0xFF7FBF6E),
      };
}

enum ItemType { main, side, drink }

/// One thing a customer wants: a venue main dish with a specific stack,
/// a side, or a drink.
class OrderItem {
  final ItemType type;

  /// For mains: the full canonical stack.
  final List<Ingredient> stack;

  const OrderItem.main(this.stack) : type = ItemType.main;
  const OrderItem.side()
      : type = ItemType.side,
        stack = const [];
  const OrderItem.drink()
      : type = ItemType.drink,
        stack = const [];

  int price(VenueDef venue) => switch (type) {
        ItemType.main =>
          venue.mainBasePrice + 3 * _optionalCount(venue),
        ItemType.side => venue.sidePrice,
        ItemType.drink => venue.drinkPrice,
      };

  int _optionalCount(VenueDef venue) =>
      stack.where(venue.toppingPool.contains).length +
      (venue.id == VenueId.burger
          ? stack.where((i) => i == Ingredient.patty).length - 1
          : 0);

  /// Whether a built stack fulfils this item. Order of the optional
  /// ingredients is irrelevant; the multiset must match exactly.
  bool matchesStack(List<Ingredient> built) {
    if (type != ItemType.main) return false;
    if (built.length != stack.length) return false;
    final want = List<Ingredient>.of(stack)..sort((a, b) => a.index - b.index);
    final have = List<Ingredient>.of(built)..sort((a, b) => a.index - b.index);
    for (var i = 0; i < want.length; i++) {
      if (want[i] != have[i]) return false;
    }
    return true;
  }
}

// ------------------------------------------------------------------ venues

enum VenueId { burger, pizza, sushi }

/// How the main dish is produced in this venue.
enum VenueFlow {
  /// Cook a component first (grill patty), then build around it. The
  /// finished dish is closed on the assembly plate (top bun).
  cookThenAssemble,

  /// Build the dish raw (pizza), then cook the whole thing; the cooked
  /// dish can burn if forgotten.
  assembleThenCook,

  /// Build the dish (sushi), then process it briefly with no burn risk.
  assembleThenRoll,
}

class VenueDef {
  final VenueId id;
  final String name;
  final String tagline;
  final VenueFlow flow;

  /// Trays shown in build order: the mandatory base ingredients first,
  /// then the optional topping pool.
  final List<Ingredient> mandatory; // e.g. bun / dough+sauce+cheese / nori+rice
  final List<Ingredient> toppingPool;

  /// Burger only: the cooked component placed from the processor.
  final Ingredient? cookedComponent;

  /// Whether the dish is closed by a final tray tap (burger top bun).
  final Ingredient? closer;

  final String processorLabel; // GRILL / OVEN / ROLLING
  final double processTime;
  final double processBurnWindow; // <= 0 means cannot burn

  final String sideLabel; // FRIES / GARLIC BREAD / MISO SOUP
  final String sideStationLabel; // FRYER / OVEN RACK / SOUP POT
  final double sideCookTime;
  final double sideBurnWindow;

  final String drinkLabel; // SODA / ITALIAN SODA / GREEN TEA
  final double drinkFillTime;

  final int mainBasePrice;
  final int sidePrice;
  final int drinkPrice;

  // Theme.
  final Color wallTop;
  final Color wallBottom;
  final Color counterTop;
  final Color counterBottom;
  final Color kitchenTop;
  final Color kitchenBottom;
  final Color panel;
  final Color panelBorder;
  final Color accent;

  const VenueDef({
    required this.id,
    required this.name,
    required this.tagline,
    required this.flow,
    required this.mandatory,
    required this.toppingPool,
    this.cookedComponent,
    this.closer,
    required this.processorLabel,
    required this.processTime,
    required this.processBurnWindow,
    required this.sideLabel,
    required this.sideStationLabel,
    required this.sideCookTime,
    required this.sideBurnWindow,
    required this.drinkLabel,
    required this.drinkFillTime,
    required this.mainBasePrice,
    required this.sidePrice,
    required this.drinkPrice,
    required this.wallTop,
    required this.wallBottom,
    required this.counterTop,
    required this.counterBottom,
    required this.kitchenTop,
    required this.kitchenBottom,
    required this.panel,
    required this.panelBorder,
    required this.accent,
  });

  String get mainLabel => switch (id) {
        VenueId.burger => "burger",
        VenueId.pizza => "pizza",
        VenueId.sushi => "roll",
      };
}

const VenueDef kBurgerVenue = VenueDef(
  id: VenueId.burger,
  name: "Burger Bar",
  tagline: "Grill it. Stack it. Serve it hot.",
  flow: VenueFlow.cookThenAssemble,
  mandatory: [Ingredient.bunBottom],
  toppingPool: [Ingredient.cheese, Ingredient.tomato, Ingredient.lettuce],
  cookedComponent: Ingredient.patty,
  closer: Ingredient.bunTop,
  processorLabel: "GRILL",
  processTime: 5.0,
  processBurnWindow: 6.0,
  sideLabel: "FRIES",
  sideStationLabel: "FRYER",
  sideCookTime: 6.0,
  sideBurnWindow: 7.0,
  drinkLabel: "SODA",
  drinkFillTime: 2.5,
  mainBasePrice: 8,
  sidePrice: 5,
  drinkPrice: 4,
  wallTop: Color(0xFF9AC4DB),
  wallBottom: Color(0xFFC7E0EC),
  counterTop: Color(0xFF9A6B40),
  counterBottom: Color(0xFF7B5233),
  kitchenTop: Color(0xFF352112),
  kitchenBottom: Color(0xFF23150C),
  panel: Color(0xFF4A3322),
  panelBorder: Color(0xFF6B4A2E),
  accent: Color(0xFFF2A03D),
);

const VenueDef kPizzaVenue = VenueDef(
  id: VenueId.pizza,
  name: "Pizza Palace",
  tagline: "Stone oven. Bubbling cheese.",
  flow: VenueFlow.assembleThenCook,
  mandatory: [Ingredient.dough, Ingredient.pizzaSauce, Ingredient.mozzarella],
  toppingPool: [Ingredient.pepperoni, Ingredient.mushroom, Ingredient.olive],
  processorLabel: "STONE OVEN",
  processTime: 6.0,
  processBurnWindow: 6.0,
  sideLabel: "GARLIC BREAD",
  sideStationLabel: "BREAD OVEN",
  sideCookTime: 5.0,
  sideBurnWindow: 6.0,
  drinkLabel: "SODA",
  drinkFillTime: 2.5,
  mainBasePrice: 10,
  sidePrice: 5,
  drinkPrice: 4,
  wallTop: Color(0xFFE8CBA8),
  wallBottom: Color(0xFFF2DEC3),
  counterTop: Color(0xFF8A4B2D),
  counterBottom: Color(0xFF6B3A22),
  kitchenTop: Color(0xFF3A1F14),
  kitchenBottom: Color(0xFF28150D),
  panel: Color(0xFF4E2E1D),
  panelBorder: Color(0xFF74452C),
  accent: Color(0xFFE05B3A),
);

const VenueDef kSushiVenue = VenueDef(
  id: VenueId.sushi,
  name: "Sushi Dock",
  tagline: "Fresh cuts by the harbour.",
  flow: VenueFlow.assembleThenRoll,
  mandatory: [Ingredient.nori, Ingredient.rice],
  toppingPool: [
    Ingredient.salmon,
    Ingredient.tuna,
    Ingredient.shrimp,
    Ingredient.cucumber,
  ],
  processorLabel: "ROLLING MAT",
  processTime: 2.8,
  processBurnWindow: 0,
  sideLabel: "MISO SOUP",
  sideStationLabel: "SOUP POT",
  sideCookTime: 5.0,
  sideBurnWindow: 8.0,
  drinkLabel: "GREEN TEA",
  drinkFillTime: 2.2,
  mainBasePrice: 9,
  sidePrice: 5,
  drinkPrice: 4,
  wallTop: Color(0xFF7FB6C4),
  wallBottom: Color(0xFFB5DAE2),
  counterTop: Color(0xFF4E6E75),
  counterBottom: Color(0xFF3A555C),
  kitchenTop: Color(0xFF14282E),
  kitchenBottom: Color(0xFF0D1C21),
  panel: Color(0xFF1F3B43),
  panelBorder: Color(0xFF32565F),
  accent: Color(0xFF4FBBA8),
);

const List<VenueDef> kVenues = [kBurgerVenue, kPizzaVenue, kSushiVenue];

VenueDef venueById(VenueId id) =>
    kVenues.firstWhere((v) => v.id == id);

// --------------------------------------------------------------- customers

enum CustomerMood { happy, neutral, impatient, angry }

enum CustomerPhase { walkingIn, waiting, leavingHappy, leavingAngry }

class Customer {
  /// Drives the procedurally drawn avatar (skin/hair/outfit/extras).
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

  /// First unserved main matching the built stack, or -1.
  int wantsMainIndex(List<Ingredient> built) {
    for (var i = 0; i < items.length; i++) {
      if (!served[i] && items[i].matchesStack(built)) return i;
    }
    return -1;
  }
}

// ------------------------------------------------------------------ levels

/// Static definition of one level (or the endless mode template).
class LevelDef {
  final VenueId venueId;
  final int id; // 1-based within the venue; 0 for endless
  final String title;
  final String blurb;
  final int customers;

  /// Seconds between customer arrivals (min..max).
  final double spawnGapMin;
  final double spawnGapMax;

  /// Base patience in seconds per order item.
  final double patiencePerItem;
  final int processorSlots;
  final List<Ingredient> toppings;
  final int maxToppingsPerMain;

  /// Venue-specific "heavy order" chance: double patty (burger),
  /// extra-loaded pizza, or double-filling roll.
  final double heavyChance;
  final bool sides;
  final bool drinks;
  final double sideChance;
  final double drinkChance;

  /// Coins needed for 1 / 2 / 3 stars (empty for endless).
  final List<int> starCoins;
  final bool endless;

  const LevelDef({
    required this.venueId,
    required this.id,
    required this.title,
    required this.blurb,
    required this.customers,
    required this.spawnGapMin,
    required this.spawnGapMax,
    required this.patiencePerItem,
    required this.processorSlots,
    required this.toppings,
    required this.maxToppingsPerMain,
    this.heavyChance = 0,
    this.sides = false,
    this.drinks = false,
    this.sideChance = 0.5,
    this.drinkChance = 0.5,
    this.starCoins = const [],
    this.endless = false,
  });

  VenueDef get venue => venueById(venueId);
}

const List<String> _burgerTitles = [
  "First Shift", "Say Cheese", "Fresh & Crisp", "Side of Fries",
  "Thirsty Crowd", "Lunch Rush", "Double Trouble", "Food Critics",
  "Game Night", "Saturday Slam", "Festival Stand", "Master Chef",
];
const List<String> _burgerBlurbs = [
  "Learn the grill. Plain burgers only.",
  "Cheeseburgers join the menu.",
  "Tomato and lettuce arrive.",
  "The fryer is installed. Watch the timer!",
  "Cold drinks on tap.",
  "The office crowd pours in.",
  "Some folks want double patties.",
  "Picky eaters with short fuses.",
  "Everyone orders sides tonight.",
  "Weekend crowds wait for no one.",
  "A festival outside your window.",
  "The final service. Prove yourself.",
];

const List<String> _pizzaTitles = [
  "Opening Night", "Margherita Basics", "Pepperoni Please", "Funghi Fever",
  "Garlic & Soda", "Trattoria Rush", "The Works", "Nonna Inspects",
  "Match Night", "Street Fair", "Critics' Table", "Pizzaiolo",
];
const List<String> _pizzaBlurbs = [
  "Dough, sauce, cheese — into the stone oven.",
  "Keep the classics coming.",
  "Pepperoni joins the counter.",
  "Mushrooms and olives arrive.",
  "Garlic bread and cold soda on the menu.",
  "The dinner crowd is hungry.",
  "Fully loaded pies, no mistakes.",
  "She has no patience for burnt crust.",
  "Halftime means a packed house.",
  "The whole street smells your oven.",
  "Every slice gets judged tonight.",
  "Earn the title. Run the palace.",
];

const List<String> _sushiTitles = [
  "First Roll", "Salmon Season", "Tuna Tide", "Ebi Express",
  "Soup & Tea", "Harbour Lunch", "Double Fill", "Omakase Eyes",
  "Ferry Crowd", "Night Market", "Dockside Storm", "Itamae",
];
const List<String> _sushiBlurbs = [
  "Nori, rice, roll. Keep it tidy.",
  "Fresh salmon on the board.",
  "Rich tuna joins the menu.",
  "Sweet shrimp for the regulars.",
  "Warm miso and green tea, too.",
  "Dockworkers eat fast — serve faster.",
  "Some rolls take two fillings.",
  "They watch every grain of rice.",
  "A ferry just unloaded. Good luck.",
  "Lanterns up, queue around the pier.",
  "Everyone shelters in your shop.",
  "Master the knife. Own the dock.",
];

/// Builds the 12-level campaign for a venue. Difficulty scales with the
/// level index; feature unlocks (toppings, sides, drinks) are staggered.
List<LevelDef> _campaign(
  VenueId venueId,
  List<String> titles,
  List<String> blurbs, {
  required List<Ingredient> pool,
  required int baseMainPrice,
}) {
  final levels = <LevelDef>[];
  for (var i = 0; i < 12; i++) {
    final n = i + 1;
    final t = i / 11.0; // 0..1 difficulty
    final customers = 4 + (i * 0.9).round(); // 4..14
    // How many ingredients from the pool are unlocked at this level.
    final toppingCount = switch (venueId) {
      // L1: plain, L2: cheese, L3: +tomato, L4+: +lettuce
      VenueId.burger => (n - 1).clamp(0, pool.length),
      // L1-2: margherita, L3: pepperoni, L4: +mushroom, L5+: +olive
      VenueId.pizza => (n - 2).clamp(0, pool.length),
      // L1-2: salmon, L3: +tuna, L4: +shrimp, L5+: +cucumber
      VenueId.sushi => (n - 1).clamp(1, pool.length),
    };
    // Sushi mains always need at least one filling and cap at two.
    final minToppings = venueId == VenueId.sushi ? 1 : 0;
    final toppings = pool.take(toppingCount).toList();
    final maxTop = venueId == VenueId.sushi
        ? (n >= 7 ? 2 : 1)
        : switch (n) {
            1 || 2 => toppingCount.clamp(0, 1),
            <= 5 => 2,
            _ => 3,
          };
    final sides = n >= 4;
    final drinks = n >= 5;
    // Average order value estimate to derive coin goals.
    final avgToppings =
        minToppings + (maxTop - minToppings) * 0.5;
    final avgOrder = (baseMainPrice + 3 * avgToppings) +
        (sides ? 0.55 * 5 : 0) +
        (drinks ? 0.55 * 4 : 0) +
        2.2; // tips
    final maxCoins = customers * avgOrder;
    final starCoins = [
      (maxCoins * 0.42).round(),
      (maxCoins * 0.62).round(),
      (maxCoins * 0.80).round(),
    ];
    levels.add(LevelDef(
      venueId: venueId,
      id: n,
      title: titles[i],
      blurb: blurbs[i],
      customers: customers,
      spawnGapMin: 9.0 - 5.0 * t,
      spawnGapMax: 12.0 - 5.5 * t,
      patiencePerItem: 40.0 - 20.0 * t,
      processorSlots: n <= 4 ? 2 : (n <= 8 ? 3 : 4),
      toppings: toppings,
      maxToppingsPerMain: maxTop,
      heavyChance: n >= 7 ? 0.25 + 0.25 * t : 0,
      sides: sides,
      drinks: drinks,
      sideChance: 0.5 + 0.25 * t,
      drinkChance: 0.5 + 0.25 * t,
      starCoins: starCoins,
    ));
  }
  return levels;
}

final List<LevelDef> kBurgerLevels = _campaign(
  VenueId.burger,
  _burgerTitles,
  _burgerBlurbs,
  pool: kBurgerVenue.toppingPool,
  baseMainPrice: kBurgerVenue.mainBasePrice,
);

final List<LevelDef> kPizzaLevels = _campaign(
  VenueId.pizza,
  _pizzaTitles,
  _pizzaBlurbs,
  pool: kPizzaVenue.toppingPool,
  baseMainPrice: kPizzaVenue.mainBasePrice,
);

final List<LevelDef> kSushiLevels = _campaign(
  VenueId.sushi,
  _sushiTitles,
  _sushiBlurbs,
  pool: kSushiVenue.toppingPool,
  baseMainPrice: kSushiVenue.mainBasePrice,
);

List<LevelDef> levelsFor(VenueId id) => switch (id) {
      VenueId.burger => kBurgerLevels,
      VenueId.pizza => kPizzaLevels,
      VenueId.sushi => kSushiLevels,
    };

/// The endless-mode template for a venue. Spawning parameters ramp over
/// time inside the controller; these are the starting values.
LevelDef endlessLevel(VenueId id) {
  final venue = venueById(id);
  return LevelDef(
    venueId: id,
    id: 0,
    title: "Endless Rush",
    blurb: "Customers never stop. Three walk-outs and the shift is over.",
    customers: 1 << 30,
    spawnGapMin: 7.0,
    spawnGapMax: 9.5,
    patiencePerItem: 34.0,
    processorSlots: 3,
    toppings: venue.toppingPool,
    maxToppingsPerMain: 3,
    heavyChance: 0.25,
    sides: true,
    drinks: true,
    sideChance: 0.55,
    drinkChance: 0.55,
    endless: true,
  );
}
