import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, Clipboard, ClipboardData;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'store.dart';
import 'api.dart';
import 'push.dart';
import 'receipt.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Push.init();
  runApp(const ParamallApp());
}

// Called after a successful register/login: hands the session token + account back to the shell.
typedef Authed = Future<void> Function(String token, String name, String phone, String address);

// ---------- config ----------
const String kWaNumber = ''; // isi nomor WhatsApp penjual, contoh: '628123456789'
// Hidden staff access: salted-SHA256 of the passcodes (server holds the real ones).
const String kAdminHash = 'ca106a58d913c7884d69c2eb174233a2c05bf11f3e07f2b42eee9468ae51d8ad'; // 'paramall2026'
const String kDriverHash = '091ce939cb21f96cbc3592627761c196915935c69c572c05911c0127f2b9eff9'; // 'driver2026'
const int kFreeOngkirMin = 100000; // gratis ongkir di atas nominal ini (promo, tetap untung karena ada margin)
const int kMinOrder = 25000; // minimal belanja
const double kMarginPct = 0.12; // markup harga jual (12%) — sumber profit utama, skala dengan besar belanja

// --- Pembayaran & anti-risiko COD ---
// Nudge: beri GRATIS ongkir kalau pelanggan bayar di muka (QRIS/Transfer).
// Ini menukar ongkir dengan kepastian bayar + tanpa risiko COD. Set false untuk matikan.
const bool kPrepayFreeOngkir = true;
// Info transfer bank — ISI dengan rekeningmu.
const String kBankName = 'BCA';              // contoh: 'BCA', 'BRI', 'Mandiri'
const String kBankAccount = '0000000000';    // nomor rekening
const String kBankHolder = 'Paramall';       // atas nama
// QRIS: tempel URL gambar QRIS statis-mu (opsional). Kosongkan kalau belum ada.
const String kQrisImageUrl = '';

class DeliveryZone {
  final String label;
  final int fee;
  const DeliveryZone(this.label, this.fee);
}

// Ongkir berdasarkan jarak. Ubah label/tarif sesuai areamu.
const List<DeliveryZone> kZones = [
  DeliveryZone('Dalam 1 km', 10000),
  DeliveryZone('1 – 2 km', 15000),
  DeliveryZone('2 – 3 km', 20000),
];

int roundTo(num v, int step) => step <= 0 ? v.round() : (v / step).round() * step;
int sellPrice(int base) => roundTo(base * (1 + kMarginPct), 500);

// ---------- promo banners (managed from Admin → Kelola Promo) ----------
class PromoBanner {
  final int id;
  final String title, subtitle, emoji;
  final List<Color> colors; // gradient (top-left → bottom-right)
  final String? action;     // 'cat:Sembako' opens a category, else null
  final bool isPopup;       // true = shown as the app-open popup instead of the carousel
  const PromoBanner({this.id = 0, required this.title, required this.subtitle, this.emoji = '🎉', required this.colors, this.action, this.isPopup = false});
  factory PromoBanner.fromJson(Map<String, dynamic> j) => PromoBanner(
        id: int.tryParse('${j['id'] ?? 0}') ?? 0,
        title: (j['title'] ?? '').toString(),
        subtitle: (j['subtitle'] ?? '').toString(),
        emoji: (j['emoji'] ?? '').toString().isEmpty ? '🎉' : (j['emoji']).toString(),
        colors: [promoHex((j['color1'] ?? '#2E9C6E').toString()), promoHex((j['color2'] ?? '#12543A').toString())],
        action: (j['action'] ?? '').toString().isEmpty ? null : (j['action']).toString(),
        isPopup: j['is_popup'] == true || j['is_popup'] == 1 || (j['is_popup'] ?? '').toString() == '1',
      );
}

Color promoHex(String s) {
  s = s.replaceAll('#', '').trim();
  if (s.length == 6) s = 'FF$s';
  return Color(int.tryParse(s, radix: 16) ?? 0xFF2E9C6E);
}

// Preset gradients the admin picks from (stored as hex on the server).
const List<List<String>> kPromoGradients = [
  ['#2E9C6E', '#12543A'], // Hijau
  ['#E4952A', '#B4671A'], // Oranye
  ['#3A7BD5', '#1E4F97'], // Biru
  ['#E0533D', '#9E2A1B'], // Merah
  ['#8E5AE0', '#5A2E9E'], // Ungu
];
const List<String> kPromoGradientNames = ['Hijau', 'Oranye', 'Biru', 'Merah', 'Ungu'];

// Fallbacks used when the server has no promos or is unreachable.
const List<PromoBanner> kPromos = [
  PromoBanner(title: 'Gratis Ongkir 🛵', subtitle: 'Belanja min. Rp100.000 — kami antar gratis ke rumah', emoji: '🛵', colors: [Color(0xFF2E9C6E), Color(0xFF12543A)]),
  PromoBanner(title: 'Bayar Online, Hemat', subtitle: 'Pakai QRIS / Transfer → ongkir GRATIS', emoji: '📱', colors: [Color(0xFFE4952A), Color(0xFFB4671A)]),
  PromoBanner(title: 'Sembako Lengkap', subtitle: 'Beras, minyak, gula & kebutuhan harian', emoji: '🍚', colors: [Color(0xFF3A7BD5), Color(0xFF1E4F97)], action: 'cat:Sembako'),
];
const bool kPromoPopupEnabled = true;
const PromoBanner kPromoPopupDefault = PromoBanner(
  title: 'Selamat Datang! 🎉',
  subtitle: 'Belanja kebutuhan harian di Paramall, kami antar ke rumah.\nGratis ongkir min. Rp100.000.',
  emoji: '🛒',
  colors: [Color(0xFF2E9C6E), Color(0xFF12543A)],
  isPopup: true,
);

// ---------- palette ----------
const kGreen = Color(0xFF1E6E4F);
const kGreenInk = Color(0xFF134A34);
const kGreenSoft = Color(0xFFE4F0E9);
const kMango = Color(0xFFE4952A);
const kMangoSoft = Color(0xFFFBEAD1);
const kGround = Color(0xFFF6F5F1);
const kSurface = Color(0xFFFFFFFF);
const kTile = Color(0xFFF1EFE8);
const kInk = Color(0xFF16211C);
const kMuted = Color(0xFF657069);
const kLine = Color(0xFFE7E1D5);

// ---------- helpers ----------
String rupiah(num n) {
  final s = n.round().abs().toString();
  final buf = StringBuffer('Rp');
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return buf.toString();
}

const List<String> _months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
String shortDate(DateTime d) => '${d.day} ${_months[d.month - 1]}';

const List<String> kCatOrder = [
  'Semua', 'Sembako', 'Makanan Instan', 'Minuman', 'Snack', 'Perawatan', 'Kesehatan', 'Rumah Tangga', 'Bayi', 'Rokok', 'Lainnya',
];
const Map<String, String> kCatEmoji = {
  'Sembako': '🍚', 'Makanan Instan': '🍜', 'Minuman': '🥤', 'Snack': '🍪',
  'Perawatan': '🧴', 'Kesehatan': '💊', 'Rumah Tangga': '🧻', 'Bayi': '🍼', 'Rokok': '🚬', 'Lainnya': '🛍️',
};
// Order matters — first match wins. Specific/priority categories come first so
// e.g. baby milk doesn't fall into "Minuman" and mosquito repellent ("obat
// nyamuk") doesn't fall into "Kesehatan".
final List<List<String>> _catRules = [
  ['Bayi', r'(popok|diaper|mamypoko|mamy poko|sweety|merries|pampers|makuku|goo\.?n|bayi|\bbaby\b|milna|sgm|bebelac|nutrilon|lactogen|cerelac|promina|dancow|nutribaby|morinaga|lactamil|chil ?mil|chil ?kid|minyak telon|telon|bubur bayi|sun baby|cussons baby|zwitsal|avent|dot bayi|probaby)'],
  ['Rokok', r'(rokok|sampoerna|djarum|gudang garam|marlboro|dji sam soe|dunhill|\besse\b|magnum filter|lucky strike|class mild|clas mild|kretek|filter rokok|sigaret|\bpods?\b|puffs?|veeva|veev)'],
  ['Kesehatan', r'(obat batuk|obat flu|obat demam|obat maag|obat sakit|obat diare|obat masuk angin|vitamin|multivitamin|masker medis|masker kn95|masker duckbill|kondom|durex|sutra bkkbn|fiesta kondom|hansaplast|plester|betadine|antiseptik|hand ?sanitizer|tolak angin|antangin|bodrex|paramex|promag|entrostop|panadol|mixagrip|decolgen|komix|vicks|counterpain|salonpas|koyo|minyak kayu putih|minyak angin|freshcare|balsem|kapsul|tablet|patch jerawat|salicylic|termometer|redoxon|imboost|enervon|blackmores|paracetamol|antimo|feminax|kiranti|diapet|actifed|syrup|adult pants|lifree)'],
  ['Perawatan', r'(sabun mandi|sabun batang|body ?wash|body cleanser|shower|shampoo|sampo|conditioner|pasta gigi|sikat gigi|odol|deodoran|deodorant|antiperspirant|lotion|hand ?body|body ?lotion|hand cream|pembalut|pantyliner|panty liner|kapas|cotton bud|parfum|cologne|eau de|body mist|body spray|\bspray\b|\bfoam\b|lip |lipstik|lipstick|lip cream|lip balm|lip tint|bedak|face powder|foundation|cushion|maskara|mascara|eyeliner|eyeshadow|blush|concealer|serum|toner|micellar|sunscreen|sunblock|facial|pembersih wajah|pencuci muka|face wash|gel cleanser|scrub wajah|masker wajah|pelembab|moisturizer|day cream|night cream|bb cream|pomade|minyak rambut|hair |cukur|razor|gillette|wardah|pixy|emina|maybelline|garnier|pond|nivea|vaseline|citra|marina|gatsby|makarizo|rexona|\bdove\b|sunsilk|\bclear\b|pantene|head ?& ?shoulders|tresemme|loreal|revlon|shinzui|lifebuoy|mouthwash|listerine|kojiesan|kojie ?san|beauty charm|\bposh\b|biore|scora|glow ?& ?lovely|glow and lovely)'],
  ['Rumah Tangga', r'(tisu|tissue|tissu|detergen|deterjen|pewangi|pelembut|pelicin|pembersih|sabun cuci|sabun colek|sunlight|mama lemon|mama lime|pencuci piring|pengharum|glade|kamper|baterai|battery|obat nyamuk|anti nyamuk|pembasmi nyamuk|baygon|autan|soffell|\bhit\b|vape|racun serangga|superpell|super pell|wipol|bayclin|pemutih|vixal|harpic|porstex|kispray|karbol|plastik|pelumas|spray anti|lampu|korek|kanebo|spons|sikat lantai|ember|kabel|\bgas\b|tabung|\blem\b|isolasi|kantong sampah|trash bag|karpet|keset|gantungan|pengki|sapu|tumbler|botol minum|kotak makan)'],
  ['Makanan Instan', r'(indomie|mie |\bmi \b|mi instan|mi goreng|mie goreng|sedaap|sarimi|supermi|super ?mi|pop ?mie|bihun instan|kwetiau instan|bubur instan|spaghetti instan|spageti|spaghetti|lemonilo|mie gelas|nissin)'],
  ['Minuman', r'(\bteh |kopi|susu|\bmilk\b|fresh milk|soy milk|lactasoy|greenfields|jus |juice|minuman|air mineral|aqua|isotonik|soda|sari kacang|sari buah|sari apel|sari asem|nutriboost|pocari|kratingdaeng|le mineral|sprite|coca|fanta|floridina|koffie|milo|energen|sirup|marjan|nutrisari|extra joss|larutan|hydro coco|cocodee|yakult|good day|nescafe|luwak|teh pucuk|frestea|fruit tea|\btebs\b|adem sari|you c1000|mizone|hemaviton|jasjus|pop ice|marimas|ovaltine|bear brand|ultra milk|frisian flag|indomilk|kental manis)'],
  ['Snack', r'(keripik|kripik|biskuit|biscuit|wafer|coklat|cokelat|permen|snack|chiki|tortilla|mentos|roti|kacang|astor|oreo|chitato|lays|taro|qtela|cheetos|richeese|nabati|tango|beng ?beng|silver ?queen|delfi|cadbury|kit ?kat|kopiko|relaxa|pilus|momogi|jelly|agar|marshmallow|crackers|malkist|\bgery\b|khong guan|monde|kue |cookies|kentang goreng|makaroni|basreng|popcorn|slai|selamat|nyam|choki|gummy|candy|snickers|kinder joy|kinder|pringles|bagelen|bolu|muesli|granola|obalab|cake|seaweed|ice cream|es krim|es potong|walls|\baice\b|campina|crab stick|chikuwa|mallow|ice cup|raisin bar|\bbar grape\b)'],
  ['Sembako', r'(beras|minyak goreng|minyak sayur|\bgula\b|telur|tepung|terigu|maizena|sagu|kecap|saus|saos|sambal|garam|margarin|mentega|santan|bumbu|penyedap|masako|royco|sasa|micin|\bmsg\b|kaldu|madu|honey|selai|meses|keju|cheese|lada|merica|ketumbar|kunyit|jahe|cabe|cabai|abon|kismis|\boat\b|gandum|ketan|kacang hijau|kacang tanah|nugget|sosis|smoked beef|bakso|sarden|kornet|tuna kaleng|ebi|dori|saikoro|cumi|shisamo|kanzler|so good|fiesta|cedea|meltique|seafood|\bbeef\b|bebek|ayam potong|ayam|my fruit|apel fuji|pear century|sunkist)'],
];
String catOf(String name) {
  final n = name.toLowerCase();
  for (final r in _catRules) {
    if (RegExp(r[1]).hasMatch(n)) return r[0];
  }
  return 'Lainnya';
}

int _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.round();
  return int.tryParse('${v ?? ''}') ?? 0;
}

// ---------- product model ----------
class Product {
  final String name;
  final int price;
  final int? priceOriginal;
  final String imageUrl;
  final String cat;
  Product({required this.name, required this.price, this.priceOriginal, required this.imageUrl, required this.cat});

  factory Product.fromJson(Map<String, dynamic> j) {
    final name = (j['name'] ?? '').toString();
    final po = j['priceOriginal'];
    return Product(
      name: name,
      price: _asInt(j['price']),
      priceOriginal: po == null ? null : _asInt(po),
      imageUrl: (j['imageUrl'] ?? '').toString(),
      cat: catOf(name),
    );
  }
  bool get discounted => priceOriginal != null && priceOriginal! > price;
  int get discountPct => discounted ? (((priceOriginal! - price) / priceOriginal!) * 100).round() : 0;
}

Future<List<Product>> loadCatalog() async {
  final raw = await rootBundle.loadString('assets/catalog.json');
  final data = jsonDecode(raw) as List<dynamic>;
  return data
      .map((e) => Product.fromJson(e as Map<String, dynamic>))
      .where((p) => p.name.isNotEmpty && p.price > 0)
      // Apply the selling margin so displayed prices are our prices, not the shelf price.
      .map((p) => Product(
            name: p.name,
            price: sellPrice(p.price),
            priceOriginal: p.priceOriginal == null ? null : sellPrice(p.priceOriginal!),
            imageUrl: p.imageUrl,
            cat: p.cat,
          ))
      .toList();
}

// ---------- app ----------
class ParamallApp extends StatelessWidget {
  const ParamallApp({super.key});
  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(seedColor: kGreen);
    return MaterialApp(
      title: 'Paramall',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: scheme, useMaterial3: true, scaffoldBackgroundColor: kGround, fontFamily: 'PlusJakartaSans'),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  bool _loading = true;
  bool _promoShown = false;
  List<PromoBanner> _promos = kPromos;
  PromoBanner _popup = kPromoPopupDefault;
  List<Product> _products = [];
  final Map<int, int> _cart = {};
  String _shopCat = 'Semua';
  Profile _profile = Profile();
  List<Order> _orders = [];
  bool _session = false;
  String _token = '';
  DateTime _notifSeenAt = DateTime.fromMillisecondsSinceEpoch(0);
  Set<String> _seenPromos = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<AppNotif> get _notifs => buildNotifications(_orders, _promos, _notifSeenAt, _seenPromos);
  int get _notifUnread => notifUnreadCount(_notifs);

  // Open the bell inbox, then mark everything currently shown as read.
  Future<void> _openNotifications() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => NotificationsPage(
      notifs: _notifs,
      onOpenOrder: (id) {
        for (final o in _orders) {
          if (o.id == id) { _openTracking(o); return; }
        }
        setState(() => _tab = 3); // fall back to the orders tab
      },
      onPromoAction: _notifPromoAction,
    )));
    _notifSeenAt = DateTime.now();
    _seenPromos = {..._promos.map(promoKey)};
    await Store.setNotifSeenAt(_notifSeenAt);
    await Store.setSeenPromoKeys(_seenPromos);
    if (mounted) setState(() {});
  }

  void _notifPromoAction(String a) {
    if (a.startsWith('cat:')) _setCat(a.substring(4));
  }

  Future<void> _load() async {
    try {
      final p = await loadCatalog();
      final prof = await Store.getProfile();
      final ords = await Store.getOrders();
      final token = await Store.getToken();
      final notifSeenAt = await Store.getNotifSeenAt();
      final seenPromos = await Store.getSeenPromoKeys();
      if (!mounted) return;
      setState(() {
        _products = p;
        _profile = prof;
        _orders = ords;
        _token = token;
        _session = token.isNotEmpty;
        _notifSeenAt = notifSeenAt;
        _seenPromos = seenPromos;
        _loading = false;
      });
      // Have a token from a previous session → refresh account & orders from the server.
      if (token.isNotEmpty) _syncSession();
      _loadPromos(); // fetch server-managed banners, then show the popup
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadPromos() async {
    try {
      final rows = await Api.promos().timeout(const Duration(seconds: 6));
      final all = rows.map(PromoBanner.fromJson).toList();
      if (mounted && all.isNotEmpty) {
        final carousel = all.where((p) => !p.isPopup).toList();
        final popups = all.where((p) => p.isPopup).toList();
        setState(() {
          if (carousel.isNotEmpty) _promos = carousel;
          if (popups.isNotEmpty) _popup = popups.first;
        });
      }
    } catch (_) {
      // Offline / no promos on server → keep the built-in defaults.
    } finally {
      _maybeShowPopup();
    }
  }

  void _maybeShowPopup() {
    if (!mounted || !kPromoPopupEnabled || _promoShown) return;
    _promoShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showPromoPopup(context, _popup);
    });
  }

  // Validate the stored token and pull the latest account + orders.
  Future<void> _syncSession() async {
    try {
      final me = await Api.me(_token);
      final orders = await Api.myOrders(_token);
      if (!mounted) return;
      _profile = Profile(name: me.name, phone: me.phone, address: me.address);
      await Store.saveProfile(_profile);
      await Store.saveOrders(orders);
      await Push.registerDevice(_token); // keep the push token fresh
      setState(() => _orders = orders);
    } on ApiException catch (e) {
      // Token expired/invalid → sign out. Ignore plain network errors (stay on cache).
      if (e.code == 401) await _doLogout();
    } catch (_) {
      // Offline: keep showing the cached account & orders.
    }
  }

  Future<void> _refreshOrders() async {
    if (_token.isEmpty) return;
    try {
      final orders = await Api.myOrders(_token);
      await Store.saveOrders(orders);
      if (mounted) setState(() => _orders = orders);
    } catch (_) {
      // Ignore; the cached list stays on screen.
    }
  }

  // Re-fetch orders and return the one with this id (used by the tracking page to show live status).
  Future<Order?> _refreshOrder(String id) async {
    await _refreshOrders();
    for (final o in _orders) {
      if (o.id == id) return o;
    }
    return null;
  }

  Future<DriverLoc?> _orderLocation(String id) async {
    if (_token.isEmpty) return null;
    try {
      return await Api.orderLocation(token: _token, id: id);
    } catch (_) {
      return null;
    }
  }

  int get cartCount => _cart.values.fold(0, (a, b) => a + b);
  int get subtotal => _cart.entries.fold(0, (a, e) => a + _products[e.key].price * e.value);
  // Cart estimate uses the nearest zone; the real zone is chosen at checkout.
  int get ongkir => (subtotal >= kFreeOngkirMin || subtotal == 0) ? 0 : kZones[0].fee;

  void _setQty(int i, int v) => setState(() {
        if (v <= 0) {
          _cart.remove(i);
        } else {
          _cart[i] = v;
        }
      });

  void _addToCart(int i, int qty) {
    _setQty(i, (_cart[i] ?? 0) + qty);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Ditambahkan ke keranjang'), duration: Duration(milliseconds: 1100)));
  }

  void _setCat(String c) => setState(() {
        _shopCat = c;
        _tab = 0;
      });

  void _openSheet(int i) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProductSheet(product: _products[i], onAdd: (qty) => _addToCart(i, qty)),
    );
  }

  void _openCheckout() {
    if (cartCount == 0) return;
    _requireLogin(_pushCheckout);
  }

  void _pushCheckout() {
    Navigator.push(context, MaterialPageRoute(builder: (_) {
      return CheckoutPage(
        products: _products,
        cart: Map<int, int>.from(_cart),
        profile: _profile,
        subtotal: subtotal,
        onPlaced: _placeOrder,
        onRefresh: _refreshOrder,
        onLocation: _orderLocation,
      );
    }));
  }

  // Browse freely; ask for an account only when buying (Tokopedia-style).
  void _requireLogin(VoidCallback onOk) {
    if (_session) {
      onOk();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LoginLanding(account: _profile, onAuthed: _onAuthed)),
    ).then((_) {
      if (mounted && _session) onOk();
    });
  }

  // Sends the order to the server; returns the confirmed order (with its real id). Throws on failure.
  Future<Order> _placeOrder(Order draft, String zoneLabel) async {
    final id = await Api.placeOrder(token: _token, order: draft, zone: zoneLabel);
    final confirmed = Order(
      id: id, at: DateTime.now(),
      name: draft.name, phone: draft.phone, addr: draft.addr, note: draft.note, pay: draft.pay,
      items: draft.items, subtotal: draft.subtotal, ongkir: draft.ongkir, total: draft.total,
      status: 'Diterima',
    );
    _profile = Profile(name: draft.name, phone: draft.phone, address: draft.addr);
    await Store.saveProfile(_profile);
    if (mounted) {
      setState(() {
        _orders.insert(0, confirmed);
        _cart.clear();
      });
    }
    await Store.saveOrders(_orders);
    _refreshOrders(); // background sync with the authoritative server list
    return confirmed;
  }

  void _openTracking(Order o, {bool justPlaced = false}) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => TrackingPage(order: o, justPlaced: justPlaced, onRefresh: _refreshOrder, onLocation: _orderLocation)));
  }

  void _reorder(Order o) {
    int added = 0;
    for (final it in o.items) {
      final idx = _products.indexWhere((p) => p.name == it.name);
      if (idx >= 0) {
        _cart[idx] = (_cart[idx] ?? 0) + it.qty;
        added += it.qty;
      }
    }
    setState(() => _tab = 2);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(added > 0 ? '$added barang ditambahkan ke keranjang' : 'Produk sudah tidak tersedia'),
        duration: const Duration(milliseconds: 1400),
      ));
  }

  void _saveProfile(Profile p) async {
    setState(() => _profile = p);
    await Store.saveProfile(p);
    if (_token.isNotEmpty) {
      try {
        await Api.saveProfile(token: _token, name: p.name, address: p.address);
      } catch (_) {
        // Saved locally; server sync will catch up next time we're online.
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Data tersimpan')));
    }
  }

  Future<void> _onAuthed(String token, String name, String phone, String address) async {
    _token = token;
    _profile = Profile(name: name, phone: phone, address: address);
    await Store.setToken(token);
    await Store.saveProfile(_profile);
    await Store.setLoggedIn(true);
    await Push.registerDevice(token); // start receiving order-status pushes
    if (!mounted) return;
    setState(() => _session = true);
    await _refreshOrders();
  }

  Future<void> _doLogout() async {
    await Store.setToken('');
    await Store.setLoggedIn(false);
    _token = '';
    if (!mounted) return;
    setState(() {
      _session = false;
      _orders = [];
      _tab = 0;
    });
  }

  void _logout() => _doLogout();

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: kGreen)));
    }
    final pages = [
      ShopPage(products: _products, cart: _cart, activeCat: _shopCat, onCat: _setCat,
          onAdd: (i) => _addToCart(i, 1), onOpen: _openSheet, onGoOrders: () => setState(() => _tab = 3),
          promos: _promos, notifUnread: _notifUnread, onBell: _openNotifications),
      CategoryPage(products: _products, onPick: _setCat),
      CartPage(products: _products, cart: _cart, onQty: _setQty, subtotal: subtotal, ongkir: ongkir, onCheckout: _openCheckout),
      _session
          ? OrdersPage(orders: _orders, products: _products, onOpen: (o) => _openTracking(o), onReorder: _reorder, onRefresh: _refreshOrders)
          : GuestGate(title: 'Pesanan', emoji: '🧾', message: 'Masuk dulu untuk melihat & melacak pesananmu.', onLogin: () => _requireLogin(() {})),
      _session
          ? ProfilePage(profile: _profile, onSave: _saveProfile, onGoOrders: () => setState(() => _tab = 3), onLogout: _logout)
          : GuestGate(title: 'Saya', emoji: '😊', message: 'Masuk atau daftar untuk kelola akun & alamatmu.', onLogin: () => _requireLogin(() {})),
    ];
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: NavigationBar(
        height: 64,
        backgroundColor: kSurface,
        indicatorColor: kGreenSoft,
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront), label: 'Toko'),
          const NavigationDestination(icon: Icon(Icons.grid_view_outlined), selectedIcon: Icon(Icons.grid_view_rounded), label: 'Kategori'),
          NavigationDestination(
            icon: Badge(isLabelVisible: cartCount > 0, label: Text('$cartCount'), child: const Icon(Icons.shopping_cart_outlined)),
            selectedIcon: Badge(isLabelVisible: cartCount > 0, label: Text('$cartCount'), child: const Icon(Icons.shopping_cart)),
            label: 'Keranjang',
          ),
          const NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Pesanan'),
          const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Saya'),
        ],
      ),
    );
  }
}

// ---------- shared widgets ----------
// Route images through our same-origin proxy so Flutter Web's canvas can draw
// them (the source CDN sends no CORS headers). img.php lives at the site root.
const String kImgProxy = '/img.php?u=';

Widget productImage(Product p, {double emojiSize = 40}) {
  final emoji = kCatEmoji[p.cat] ?? '🛍️';
  Widget fallback() => Center(child: Text(emoji, style: TextStyle(fontSize: emojiSize)));
  if (p.imageUrl.isEmpty) return fallback();
  // Web needs the same-origin proxy (canvas CORS); native (Android/iOS) can
  // load the CDN image directly.
  final src = kIsWeb ? '$kImgProxy${Uri.encodeComponent(p.imageUrl)}' : p.imageUrl;
  return Image.network(
    src,
    fit: BoxFit.contain,
    errorBuilder: (_, __, ___) => fallback(),
    loadingBuilder: (_, child, prog) => prog == null ? child : fallback(),
  );
}

class GreenHeader extends StatelessWidget {
  final String title;
  final Widget? leading;
  const GreenHeader({super.key, required this.title, this.leading});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 14, 16, 14),
      decoration: const BoxDecoration(color: kGreen, borderRadius: BorderRadius.vertical(bottom: Radius.circular(20))),
      child: Row(children: [
        if (leading != null) ...[leading!, const SizedBox(width: 8)],
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

class EmptyView extends StatelessWidget {
  final String emoji;
  final String text;
  const EmptyView({super.key, required this.emoji, required this.text});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(emoji, style: const TextStyle(fontSize: 46)),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: kMuted, fontSize: 14)),
          ]),
        ),
      );
}

Widget moneyRow(String a, String b, {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Text(a, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: bold ? kInk : kMuted, fontWeight: bold ? FontWeight.w800 : FontWeight.w500, fontSize: bold ? 16 : 13.5))),
        const SizedBox(width: 10),
        Text(b, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600, fontSize: bold ? 17 : 13.5)),
      ]),
    );

// ---------- shop ----------
class ShopPage extends StatefulWidget {
  final List<Product> products;
  final Map<int, int> cart;
  final String activeCat;
  final void Function(String) onCat;
  final void Function(int) onAdd;
  final void Function(int) onOpen;
  final VoidCallback onGoOrders;
  final List<PromoBanner> promos;
  final int notifUnread;
  final VoidCallback onBell;
  const ShopPage({super.key, required this.products, required this.cart, required this.activeCat,
      required this.onCat, required this.onAdd, required this.onOpen, required this.onGoOrders, required this.promos,
      this.notifUnread = 0, required this.onBell});
  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  String _search = '';
  String _sort = 'Relevan';
  final TextEditingController _searchCtrl = TextEditingController();

  static const List<String> _sortOptions = ['Relevan', 'Termurah', 'Termahal', 'Promo'];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<int> get _visible {
    final term = _search.trim().toLowerCase();
    final searching = term.isNotEmpty;
    final out = <int>[];
    for (int i = 0; i < widget.products.length; i++) {
      final p = widget.products[i];
      // While searching, look across ALL categories; otherwise honour the active category.
      final catOk = searching || widget.activeCat == 'Semua' || p.cat == widget.activeCat;
      final nameOk = !searching || p.name.toLowerCase().contains(term);
      if (catOk && nameOk) out.add(i);
    }
    final ps = widget.products;
    switch (_sort) {
      case 'Termurah':
        out.sort((a, b) => ps[a].price.compareTo(ps[b].price));
        break;
      case 'Termahal':
        out.sort((a, b) => ps[b].price.compareTo(ps[a].price));
        break;
      case 'Promo':
        // Discounted first (biggest saving on top), the rest keep catalog order.
        out.sort((a, b) => ps[b].discountPct.compareTo(ps[a].discountPct));
        break;
      // 'Relevan' — keep catalog order.
    }
    return out;
  }

  List<String> get _cats {
    final present = widget.products.map((p) => p.cat).toSet();
    return kCatOrder.where((c) => c == 'Semua' || present.contains(c)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final idxs = _visible;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _header()),
        SliverToBoxAdapter(child: _quickMenu()),
        SliverToBoxAdapter(child: _catChips()),
        SliverPadding(padding: const EdgeInsets.only(top: 12), sliver: SliverToBoxAdapter(child: PromoCarousel(promos: widget.promos, onAction: _onPromoAction))),
        if (idxs.isNotEmpty) SliverToBoxAdapter(child: _sortBar(idxs.length)),
        if (idxs.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(30, 50, 30, 30),
              child: Column(children: [
                const Text('🔍', style: TextStyle(fontSize: 44)),
                const SizedBox(height: 12),
                Text(
                  _search.trim().isEmpty ? 'Belum ada produk di kategori ini.' : 'Tidak ada hasil untuk "${_search.trim()}".',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: kMuted, fontSize: 14),
                ),
              ]),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.66),
              delegate: SliverChildBuilderDelegate(
                (_, k) {
                  final i = idxs[k];
                  return ProductCard(product: widget.products[i], onAdd: () => widget.onAdd(i), onOpen: () => widget.onOpen(i));
                },
                childCount: idxs.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _sortBar(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 0),
      child: Row(children: [
        Text('$count produk', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kMuted)),
        const Spacer(),
        const Icon(Icons.swap_vert, size: 18, color: kMuted),
        const SizedBox(width: 2),
        DropdownButton<String>(
          value: _sort,
          isDense: true,
          underline: const SizedBox.shrink(),
          borderRadius: BorderRadius.circular(12),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kInk),
          items: [
            for (final s in _sortOptions) DropdownMenuItem(value: s, child: Text(s)),
          ],
          onChanged: (v) => setState(() => _sort = v ?? 'Relevan'),
        ),
      ]),
    );
  }

  Widget _bell() {
    return GestureDetector(
      onTap: widget.onBell,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(left: 6),
        child: Stack(clipBehavior: Clip.none, children: [
          const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 27),
          if (widget.notifUnread > 0)
            Positioned(
              right: -3, top: -3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                decoration: BoxDecoration(color: const Color(0xFFE0533D), borderRadius: BorderRadius.circular(999), border: Border.all(color: kGreen, width: 1.5)),
                child: Text(
                  widget.notifUnread > 9 ? '9+' : '${widget.notifUnread}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w800, height: 1.15),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 12, 16, 14),
      decoration: const BoxDecoration(color: kGreen, borderRadius: BorderRadius.vertical(bottom: Radius.circular(20))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const _LogoBox(),
          const SizedBox(width: 10),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('Paramall', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
            Text('Belanja online di Paramall — kami antar ke rumah', style: TextStyle(color: Colors.white70, fontSize: 11)),
          ])),
          _bell(),
        ]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(13)),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _search = v),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              icon: const Icon(Icons.search, size: 20, color: kMuted),
              hintText: 'Cari Indomie, beras, minyak…',
              border: InputBorder.none,
              suffixIcon: _search.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18, color: kMuted),
                      onPressed: () => setState(() {
                        _search = '';
                        _searchCtrl.clear();
                      }),
                    ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _quickMenu() {
    final items = <List<Object>>[
      ['🍚', 'Sembako', const Color(0xFFE3F0E9), 'cat:Sembako'],
      ['🍜', 'Makanan\nInstan', const Color(0xFFFBEAD1), 'cat:Makanan Instan'],
      ['🥤', 'Minuman', const Color(0xFFE3EDF6), 'cat:Minuman'],
      ['🛵', 'Lacak\nPesanan', const Color(0xFFEEE6F4), 'orders'],
      ['💬', 'Bantuan', const Color(0xFFE7F2EB), 'help'],
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 2),
      child: Row(
        children: items.map((it) {
          final act = it[3] as String;
          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                if (act.startsWith('cat:')) {
                  widget.onCat(act.substring(4));
                } else if (act == 'orders') {
                  widget.onGoOrders();
                } else {
                  _help();
                }
              },
              child: Column(children: [
                Container(width: 50, height: 50, decoration: BoxDecoration(color: it[2] as Color, borderRadius: BorderRadius.circular(15)),
                    child: Center(child: Text(it[0] as String, style: const TextStyle(fontSize: 24)))),
                const SizedBox(height: 6),
                Text(it[1] as String, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, height: 1.1)),
                const SizedBox(height: 4),
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _help() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportChatPage()));
  }

  void _onPromoAction(String a) {
    if (a.startsWith('cat:')) {
      widget.onCat(a.substring(4));
    } else if (a == 'help') {
      _help();
    }
  }

  Widget _catChips() {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
        children: _cats.map((c) {
          final on = c == widget.activeCat;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => widget.onCat(c),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: on ? kGreen : kTile, borderRadius: BorderRadius.circular(999)),
                child: Text(c, style: TextStyle(color: on ? Colors.white : kInk, fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ignore: unused_element
  Widget _promoOld() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: kMangoSoft, borderRadius: BorderRadius.circular(16), border: Border.all(color: kLine)),
      child: Row(children: const [
        Text('🛵', style: TextStyle(fontSize: 24)),
        SizedBox(width: 11),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text('Kami yang belanja & antar', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
          SizedBox(height: 1),
          Text('Pilih barangnya, tim Paramall belanjakan & antar langsung ke rumah kamu.', style: TextStyle(fontSize: 12, color: kMuted)),
        ])),
      ]),
    );
  }
}

class _LogoBox extends StatelessWidget {
  const _LogoBox();
  @override
  Widget build(BuildContext context) => Container(
      width: 34, height: 34, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
      child: const Center(child: Text('🛒', style: TextStyle(fontSize: 18))));
}

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onAdd;
  final VoidCallback onOpen;
  const ProductCard({super.key, required this.product, required this.onAdd, required this.onOpen});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(16), border: Border.all(color: kLine)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Stack(children: [
              Positioned.fill(child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Container(color: kTile, child: productImage(product)))),
              if (product.discounted)
                Positioned(top: 6, left: 6, child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(color: kMango, borderRadius: BorderRadius.circular(999)),
                  child: Text(product.discountPct >= 1 ? 'Hemat ${product.discountPct}%' : 'Hemat', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF3A2400))))),
            ]),
          ),
          const SizedBox(height: 8),
          SizedBox(height: 34, child: Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.25))),
          const SizedBox(height: 6),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              if (product.discounted)
                Text(rupiah(product.priceOriginal!), style: const TextStyle(fontSize: 11, color: kMuted, decoration: TextDecoration.lineThrough)),
              Text(rupiah(product.price), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            ])),
            GestureDetector(
              onTap: onAdd,
              child: Container(width: 34, height: 34, decoration: BoxDecoration(color: kGreenSoft, borderRadius: BorderRadius.circular(11)), child: const Icon(Icons.add, size: 20, color: kGreenInk)),
            ),
          ]),
        ]),
      ),
    );
  }
}

class ProductSheet extends StatefulWidget {
  final Product product;
  final void Function(int qty) onAdd;
  const ProductSheet({super.key, required this.product, required this.onAdd});
  @override
  State<ProductSheet> createState() => _ProductSheetState();
}

class _ProductSheetState extends State<ProductSheet> {
  int qty = 1;
  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    return Container(
      decoration: const BoxDecoration(color: kSurface, borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 10, bottom: 4), decoration: BoxDecoration(color: kLine, borderRadius: BorderRadius.circular(999))),
          Container(margin: const EdgeInsets.fromLTRB(16, 6, 16, 0), height: 180, decoration: BoxDecoration(color: kTile, borderRadius: BorderRadius.circular(16)), child: productImage(p, emojiSize: 80)),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(p.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, height: 1.35)),
              const SizedBox(height: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: kGreenSoft, borderRadius: BorderRadius.circular(999)),
                  child: Text(p.cat, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: kGreenInk))),
              const SizedBox(height: 12),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(rupiah(p.price), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                const Text(' /pcs', style: TextStyle(fontSize: 12.5, color: kMuted, fontWeight: FontWeight.w600)),
                if (p.discounted) ...[const SizedBox(width: 8), Text(rupiah(p.priceOriginal!), style: const TextStyle(fontSize: 14, color: kMuted, decoration: TextDecoration.lineThrough))],
              ]),
              const SizedBox(height: 18),
              Row(children: [
                _stepBtn(Icons.remove, () => setState(() => qty = qty > 1 ? qty - 1 : 1)),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Text('$qty', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                _stepBtn(Icons.add, () => setState(() => qty++)),
                const SizedBox(width: 12),
                Expanded(child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: kGreen, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  onPressed: () {
                    widget.onAdd(qty);
                    Navigator.pop(context);
                  },
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Keranjang · ${rupiah(p.price * qty)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                )),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _stepBtn(IconData ic, VoidCallback onTap) => GestureDetector(
      onTap: onTap, child: Container(width: 34, height: 34, decoration: BoxDecoration(color: kTile, borderRadius: BorderRadius.circular(10)), child: Icon(ic, size: 18, color: kInk)));
}

// ---------- categories ----------
class CategoryPage extends StatelessWidget {
  final List<Product> products;
  final void Function(String) onPick;
  const CategoryPage({super.key, required this.products, required this.onPick});
  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final p in products) {
      counts[p.cat] = (counts[p.cat] ?? 0) + 1;
    }
    final cats = kCatOrder.where((c) => c != 'Semua' && (counts[c] ?? 0) > 0).toList();
    return Column(children: [
      const GreenHeader(title: 'Kategori'),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: cats.map((c) {
            return GestureDetector(
              onTap: () => onPick(c),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(16), border: Border.all(color: kLine)),
                child: Row(children: [
                  Container(width: 46, height: 46, decoration: BoxDecoration(color: kGreenSoft, borderRadius: BorderRadius.circular(13)), child: Center(child: Text(kCatEmoji[c] ?? '🛍️', style: const TextStyle(fontSize: 24)))),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(c, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    Text('${counts[c]} produk', style: const TextStyle(color: kMuted, fontSize: 11.5)),
                  ])),
                  const Icon(Icons.chevron_right, color: kMuted),
                ]),
              ),
            );
          }).toList(),
        ),
      ),
    ]);
  }
}

// ---------- cart ----------
class CartPage extends StatelessWidget {
  final List<Product> products;
  final Map<int, int> cart;
  final void Function(int, int) onQty;
  final int subtotal;
  final int ongkir;
  final VoidCallback onCheckout;
  const CartPage({super.key, required this.products, required this.cart, required this.onQty, required this.subtotal, required this.ongkir, required this.onCheckout});

  @override
  Widget build(BuildContext context) {
    final entries = cart.entries.toList();
    return Column(children: [
      const GreenHeader(title: 'Keranjang'),
      Expanded(
        child: entries.isEmpty
            ? const EmptyView(emoji: '🛒', text: 'Keranjang masih kosong.\nYuk pilih barang di Toko.')
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ...entries.map((e) {
                    final p = products[e.key];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(16), border: Border.all(color: kLine)),
                      child: Row(children: [
                        Container(width: 64, height: 64, decoration: BoxDecoration(color: kTile, borderRadius: BorderRadius.circular(12)), child: productImage(p, emojiSize: 28)),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                          Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(rupiah(p.price), style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          Row(children: [
                            _step(Icons.remove, () => onQty(e.key, e.value - 1)),
                            Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text('${e.value}', style: const TextStyle(fontWeight: FontWeight.w700))),
                            _step(Icons.add, () => onQty(e.key, e.value + 1)),
                          ]),
                        ])),
                      ]),
                    );
                  }),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(16), border: Border.all(color: kLine)),
                    child: Column(children: [
                      moneyRow('Subtotal', rupiah(subtotal)),
                      moneyRow(ongkir == 0 ? 'Ongkir (gratis)' : 'Ongkir', rupiah(ongkir)),
                      const Divider(height: 18),
                      moneyRow('Total', rupiah(subtotal + ongkir), bold: true),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: kGreen, minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    onPressed: onCheckout,
                    child: Text('Checkout · ${rupiah(subtotal + ongkir)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                ],
              ),
      ),
    ]);
  }

  Widget _step(IconData ic, VoidCallback onTap) => GestureDetector(
      onTap: onTap, child: Container(width: 28, height: 28, decoration: BoxDecoration(color: kTile, borderRadius: BorderRadius.circular(9), border: Border.all(color: kLine)), child: Icon(ic, size: 16, color: kInk)));
}

// ---------- checkout ----------
class CheckoutPage extends StatefulWidget {
  final List<Product> products;
  final Map<int, int> cart;
  final Profile profile;
  final int subtotal;
  final Future<Order> Function(Order draft, String zoneLabel) onPlaced;
  final Future<Order?> Function(String id)? onRefresh;
  final Future<DriverLoc?> Function(String id)? onLocation;
  const CheckoutPage({super.key, required this.products, required this.cart, required this.profile, required this.subtotal, required this.onPlaced, this.onRefresh, this.onLocation});
  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  late final TextEditingController _name = TextEditingController(text: widget.profile.name);
  late final TextEditingController _phone = TextEditingController(text: widget.profile.phone);
  late final TextEditingController _addr = TextEditingController(text: widget.profile.address);
  final TextEditingController _note = TextEditingController();
  String _pay = 'COD';
  int _zone = 0;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _addr.dispose();
    _note.dispose();
    super.dispose();
  }

  bool get _isPrepay => _pay == 'QRIS' || _pay == 'Transfer';
  bool get _freeOngkir => widget.subtotal >= kFreeOngkirMin || (_isPrepay && kPrepayFreeOngkir);
  int get ongkir => _freeOngkir ? 0 : kZones[_zone].fee;
  int get total => widget.subtotal + ongkir;

  String _payLabel(String p) => p == 'COD' ? 'Bayar di Tempat (COD)' : p == 'Transfer' ? 'Transfer Bank' : 'QRIS';

  void _snack(String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));

  Future<void> _place() async {
    if (widget.subtotal < kMinOrder) {
      _snack('Minimal belanja ${rupiah(kMinOrder)}');
      return;
    }
    if (_name.text.trim().isEmpty || _phone.text.trim().isEmpty || _addr.text.trim().isEmpty) {
      _snack('Lengkapi nama, HP, dan alamat dulu');
      return;
    }
    setState(() => _busy = true);
    final items = widget.cart.entries.map((e) => OrderItem(name: widget.products[e.key].name, price: widget.products[e.key].price, qty: e.value)).toList();
    final draft = Order(
      id: '', at: DateTime.now(),
      name: _name.text.trim(), phone: _phone.text.trim(), addr: _addr.text.trim(), note: _note.text.trim(), pay: _pay,
      items: items, subtotal: widget.subtotal, ongkir: ongkir, total: total,
    );
    try {
      final confirmed = await widget.onPlaced(draft, kZones[_zone].label);
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => TrackingPage(order: confirmed, justPlaced: true, onRefresh: widget.onRefresh, onLocation: widget.onLocation)));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('Gagal membuat pesanan. Coba lagi.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(children: [
        GreenHeader(title: 'Checkout', leading: _BackBtn(() => Navigator.pop(context))),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Alamat Pengantaran', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 10),
              _field('Nama penerima', _name),
              _field('Nomor HP / WhatsApp', _phone, keyboard: TextInputType.phone),
              _field('Alamat lengkap', _addr, lines: 3),
              _field('Catatan (opsional)', _note),
              const SizedBox(height: 8),
              const Text('Zona Pengantaran', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const Text('Ongkir menyesuaikan jarak dari toko.', style: TextStyle(color: kMuted, fontSize: 12.5)),
              const SizedBox(height: 10),
              ...List.generate(kZones.length, _zoneTile),
              const SizedBox(height: 8),
              const Text('Metode Pembayaran', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              if (kPrepayFreeOngkir)
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Text('Bayar online (QRIS/Transfer) → GRATIS ongkir 🎉', style: TextStyle(color: kGreen, fontSize: 12.5, fontWeight: FontWeight.w700)),
                ),
              const SizedBox(height: 10),
              _payTile('COD', '💵', 'Bayar di Tempat (COD)', 'Bayar tunai saat barang diantar'),
              _payTile('Transfer', '🏦', 'Transfer Bank', kPrepayFreeOngkir ? 'Bayar di muka · gratis ongkir' : 'Transfer sebelum diantar'),
              _payTile('QRIS', '📱', 'QRIS', kPrepayFreeOngkir ? 'Scan & bayar · gratis ongkir' : 'Scan & bayar'),
              if (_isPrepay) ...[
                const SizedBox(height: 10),
                _payInstructions(),
              ],
              const SizedBox(height: 12),
              const Text('Ringkasan Pesanan', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(16), border: Border.all(color: kLine)),
                child: Column(children: [
                  ...widget.cart.entries.map((e) => moneyRow('${e.value}× ${widget.products[e.key].name}', rupiah(widget.products[e.key].price * e.value))),
                  const Divider(height: 18),
                  moneyRow('Subtotal', rupiah(widget.subtotal)),
                  moneyRow(ongkir != 0 ? 'Ongkir (${kZones[_zone].label})' : (_isPrepay && kPrepayFreeOngkir ? 'Ongkir (gratis · bayar online)' : 'Ongkir (gratis)'), rupiah(ongkir)),
                  const SizedBox(height: 4),
                  moneyRow('Total Bayar', rupiah(total), bold: true),
                ]),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: kGreen, minimumSize: const Size.fromHeight(54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              onPressed: _busy ? null : _place,
              child: Text(_busy ? 'Memproses…' : 'Buat Pesanan · ${rupiah(total)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _field(String label, TextEditingController c, {int lines = 1, TextInputType? keyboard}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kMuted)),
          const SizedBox(height: 6),
          TextField(
            controller: c, maxLines: lines, keyboardType: keyboard,
            decoration: InputDecoration(
              filled: true, fillColor: kSurface, isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kLine)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kGreen, width: 1.5)),
            ),
          ),
        ]),
      );

  Widget _zoneTile(int i) {
    final z = kZones[i];
    final on = _zone == i;
    final free = _freeOngkir; // ≥ free-ongkir minimum OR paying online
    return GestureDetector(
      onTap: () => setState(() => _zone = i),
      child: Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: on ? kGreenSoft : kSurface, borderRadius: BorderRadius.circular(13), border: Border.all(color: on ? kGreen : kLine)),
        child: Row(children: [
          const Icon(Icons.pedal_bike, size: 20, color: kGreenInk),
          const SizedBox(width: 11),
          Expanded(child: Text(z.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5))),
          Text(free ? 'GRATIS' : rupiah(z.fee), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: free ? kGreen : kInk)),
          const SizedBox(width: 10),
          Icon(on ? Icons.radio_button_checked : Icons.radio_button_off, color: on ? kGreen : kMuted, size: 20),
        ]),
      ),
    );
  }

  Widget _payTile(String value, String emoji, String title, String sub) {
    final on = _pay == value;
    return GestureDetector(
      onTap: () => setState(() => _pay = value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: on ? kGreenSoft : kSurface, borderRadius: BorderRadius.circular(13), border: Border.all(color: on ? kGreen : kLine)),
        child: Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
            Text(sub, style: const TextStyle(color: kMuted, fontSize: 11.5)),
          ])),
          Icon(on ? Icons.radio_button_checked : Icons.radio_button_off, color: on ? kGreen : kMuted, size: 20),
        ]),
      ),
    );
  }

  Widget _payInstructions() => PayInstructions(pay: _pay, total: total);
}

// Shows how to pay for a prepaid (QRIS/Transfer) order. Reused at checkout and
// on the tracking screen. When [orderId] is set, adds a "kirim bukti" WA button.
class PayInstructions extends StatelessWidget {
  final String pay;
  final int total;
  final String? orderId;
  const PayInstructions({super.key, required this.pay, required this.total, this.orderId});

  bool get _isQris => pay == 'QRIS';

  Future<void> _copy(BuildContext context, String v) async {
    await Clipboard.setData(ClipboardData(text: v));
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Disalin'), duration: Duration(milliseconds: 900)));
    }
  }

  void _sendProof() {
    if (kWaNumber.isEmpty) return;
    final msg = 'Halo Paramall, saya sudah bayar pesanan${orderId != null ? ' #$orderId' : ''} sebesar ${rupiah(total)}. Ini bukti transfernya:';
    launchUrl(Uri.parse('https://wa.me/$kWaNumber?text=${Uri.encodeComponent(msg)}'), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: kMangoSoft, borderRadius: BorderRadius.circular(16), border: Border.all(color: kLine)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(_isQris ? '📱' : '🏦', style: const TextStyle(fontSize: 17)),
          const SizedBox(width: 8),
          Text(_isQris ? 'Bayar via QRIS' : 'Bayar via Transfer', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        ]),
        const SizedBox(height: 10),
        if (_isQris) ...[
          if (kQrisImageUrl.isNotEmpty)
            Center(child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(kQrisImageUrl, height: 200, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Text('Gagal memuat QRIS'))))
          else
            const Text('Kode QRIS akan kami kirim via WhatsApp setelah pesanan dibuat.', style: TextStyle(fontSize: 12.5, color: kInk, height: 1.35)),
        ] else ...[
          _copyRow(context, 'Bank', kBankName, copyable: false),
          _copyRow(context, 'No. Rekening', kBankAccount),
          _copyRow(context, 'Atas Nama', kBankHolder, copyable: false),
        ],
        const Divider(height: 18),
        _copyRow(context, 'Jumlah', rupiah(total)),
        const SizedBox(height: 8),
        const Text('Bayar sesuai jumlah di atas, lalu kirim bukti ke WhatsApp kami. Pesanan diproses setelah pembayaran dicek.', style: TextStyle(fontSize: 11.5, color: kMuted, height: 1.4)),
        if (orderId != null && kWaNumber.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: kGreen, minimumSize: const Size.fromHeight(46), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: _sendProof,
              icon: const Icon(Icons.chat, size: 18),
              label: const Text('Sudah bayar? Kirim bukti', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _copyRow(BuildContext context, String k, String v, {bool copyable = true}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          SizedBox(width: 92, child: Text(k, style: const TextStyle(color: kMuted, fontSize: 12.5))),
          Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5))),
          if (copyable)
            GestureDetector(
              onTap: () => _copy(context, v),
              child: const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.copy, size: 16, color: kGreenInk)),
            ),
        ]),
      );
}

// ---------- tracking ----------
class _Driver {
  final String name, veh, plate, emoji;
  const _Driver(this.name, this.veh, this.plate, this.emoji);
}

const List<_Driver> _drivers = [
  _Driver('Budi Santoso', 'Honda Vario', 'B 3245 KLM', '🧑🏻‍🦱'),
  _Driver('Andi Pratama', 'Yamaha NMAX', 'B 5521 XYZ', '🧔🏻'),
  _Driver('Slamet Riyadi', 'Honda Beat', 'B 8890 QRS', '👨🏻'),
  _Driver('Dewi Lestari', 'Honda Scoopy', 'B 1123 TUV', '👩🏻'),
];
const List<List<String>> _stages = [
  ['Pesanan diterima', 'Menunggu tim menyiapkan'],
  ['Sedang dibelanjakan', 'Tim Paramall sedang menyiapkan pesananmu'],
  ['Driver mengantar', 'Driver dalam perjalanan ke rumahmu'],
  ['Pesanan selesai', 'Barang sudah diterima. Terima kasih!'],
];
class TrackingPage extends StatefulWidget {
  final Order order;
  final bool justPlaced;
  // Polls the server for this order's latest status; null when there's nothing to refresh against.
  final Future<Order?> Function(String id)? onRefresh;
  // Polls the driver's live GPS for this order (for the moving map).
  final Future<DriverLoc?> Function(String id)? onLocation;
  const TrackingPage({super.key, required this.order, this.justPlaced = false, this.onRefresh, this.onLocation});
  @override
  State<TrackingPage> createState() => _TrackingPageState();
}

class _TrackingPageState extends State<TrackingPage> {
  late Order _order = widget.order;
  Timer? _t;
  Timer? _locT;
  LatLng? _driverPos;
  @override
  void initState() {
    super.initState();
    if (widget.onRefresh != null) {
      _refresh();
      _t = Timer.periodic(const Duration(seconds: 8), (_) => _refresh());
    }
    if (widget.onLocation != null) {
      _pollLoc();
      _locT = Timer.periodic(const Duration(seconds: 4), (_) => _pollLoc());
    }
  }

  Future<void> _refresh() async {
    final o = await widget.onRefresh!(_order.id);
    if (o != null && mounted) setState(() => _order = o);
  }

  Future<void> _pollLoc() async {
    final loc = await widget.onLocation!(_order.id);
    if (loc != null && loc.hasFix && mounted) {
      setState(() => _driverPos = LatLng(loc.lat!, loc.lng!));
    }
  }

  @override
  void dispose() {
    _t?.cancel();
    _locT?.cancel();
    super.dispose();
  }

  int get _stage => orderStage(_order);

  _Driver get _driver {
    int sum = 0;
    for (final c in _order.id.codeUnits) {
      sum += c;
    }
    return _drivers[sum % _drivers.length];
  }

  @override
  Widget build(BuildContext context) {
    final o = _order;
    final st = _stage;
    final d = _driver;
    return Scaffold(
      body: Column(children: [
        GreenHeader(title: 'Lacak Pesanan', leading: _BackBtn(() => Navigator.pop(context))),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (widget.justPlaced)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: kGreenSoft, borderRadius: BorderRadius.circular(14)),
                  child: Row(children: [const Text('✅', style: TextStyle(fontSize: 18)), const SizedBox(width: 9), Expanded(child: Text('Pesanan #${o.id} berhasil dibuat!', style: const TextStyle(fontWeight: FontWeight.w700, color: kGreenInk)))]),
                ),
              // Prepaid order not yet processed → show payment instructions until it's paid & moved on.
              if (o.pay != 'COD' && st == 0) ...[
                PayInstructions(pay: o.pay, total: o.total, orderId: o.id),
                const SizedBox(height: 16),
              ],
              // Live map while the driver is on the way; illustrative map otherwise.
              if (st == 2 && widget.onLocation != null)
                _liveMap()
              else
                _map(st),
              const SizedBox(height: 16),
              ...List.generate(_stages.length, (i) => _stepRow(i, st)),
              if (st >= 2 && st < 3) _driverCard(d),
              const SizedBox(height: 6),
              const Text('Detail Pesanan', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(16), border: Border.all(color: kLine)),
                child: Column(children: [
                  ...o.items.map((it) => moneyRow('${it.qty}× ${it.name}', rupiah(it.sum))),
                  moneyRow(o.ongkir == 0 ? 'Ongkir (gratis)' : 'Ongkir', rupiah(o.ongkir)),
                  const Divider(height: 18),
                  moneyRow('Total · ${_payLabel(o.pay)}', rupiah(o.total), bold: true),
                ]),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), side: const BorderSide(color: kGreen), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                icon: const Icon(Icons.receipt_long, size: 20, color: kGreen),
                label: const Text('Cetak / Simpan Struk', style: TextStyle(fontWeight: FontWeight.w800, color: kGreen)),
                onPressed: () => _printReceipt(o),
              ),
              const SizedBox(height: 10),
              if (kWaNumber.isNotEmpty)
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: kGreen, minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  onPressed: () => launchUrl(Uri.parse(_waLink(o)), mode: LaunchMode.externalApplication),
                  child: const Text('Kirim detail ke WhatsApp Paramall', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              const SizedBox(height: 10),
              OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), side: const BorderSide(color: kLine), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                onPressed: () => Navigator.pop(context),
                child: const Text('Kembali', style: TextStyle(fontWeight: FontWeight.w700, color: kInk)),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  Future<void> _printReceipt(Order o) async {
    try {
      await printReceipt(o, waNumber: kWaNumber);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Tidak bisa membuka pencetak di perangkat ini')));
      }
    }
  }

  String _payLabel(String p) => p == 'COD' ? 'COD' : p == 'Transfer' ? 'Transfer' : 'QRIS';
  String _waText(Order o) {
    final b = StringBuffer('*Pesanan Paramall*\n#${o.id}\n\n');
    for (final it in o.items) {
      b.write('• ${it.qty}× ${it.name} — ${rupiah(it.sum)}\n');
    }
    b.write('\nSubtotal: ${rupiah(o.subtotal)}\nOngkir: ${rupiah(o.ongkir)}\n*Total: ${rupiah(o.total)}*\nBayar: ${_payLabel(o.pay)}\n\n*Penerima*\n${o.name}\n${o.phone}\n${o.addr}\n');
    if (o.note.isNotEmpty) b.write('Catatan: ${o.note}\n');
    return b.toString();
  }

  String _waLink(Order o) => 'https://wa.me/$kWaNumber?text=${Uri.encodeComponent(_waText(o))}';

  Widget _liveMap() {
    if (_driverPos == null) {
      return Container(
        height: 150,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: kLine), color: kTile),
        child: const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('🛵', style: TextStyle(fontSize: 30)),
          SizedBox(height: 8),
          Text('Menunggu driver mulai berbagi lokasi…', style: TextStyle(color: kMuted, fontSize: 12.5)),
        ])),
      );
    }
    return Column(children: [
      SizedBox(height: 220, child: LiveDeliveryMap(driver: _driverPos)),
      const SizedBox(height: 6),
      Row(children: const [
        Icon(Icons.circle, size: 9, color: kGreen),
        SizedBox(width: 6),
        Text('Driver dalam perjalanan • lokasi langsung', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kGreenInk)),
      ]),
    ]);
  }

  Widget _map(int st) {
    final pos = st >= 3 ? 0.84 : st == 2 ? 0.58 : st == 1 ? 0.30 : 0.12;
    return Container(
      height: 140,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: kLine), gradient: const LinearGradient(colors: [Color(0xFFCFE6D8), Color(0xFFE8F0E5)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
      child: Stack(children: [
        const Positioned(right: 24, top: 44, child: Text('🏠', style: TextStyle(fontSize: 26))),
        Align(alignment: Alignment(pos * 2 - 1, 0.05), child: Text(st >= 3 ? '✅' : '🛵', style: const TextStyle(fontSize: 30))),
        Positioned(left: 14, bottom: 12, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(999)),
          child: Text(st >= 3 ? 'Selesai' : st == 2 ? '🛵 Menuju rumah' : st == 1 ? 'Disiapkan' : 'Menunggu', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        )),
      ]),
    );
  }

  Widget _stepRow(int i, int st) {
    final done = i < st, now = i == st;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Column(children: [
          Container(width: 22, height: 22, decoration: BoxDecoration(color: done ? kGreen : now ? kMango : kTile, shape: BoxShape.circle),
              child: Icon(done ? Icons.check : Icons.circle, size: done ? 14 : 8, color: done ? Colors.white : now ? const Color(0xFF3A2400) : kMuted)),
          if (i < _stages.length - 1) Container(width: 2, height: 26, color: kLine),
        ]),
        const SizedBox(width: 12),
        Expanded(child: Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_stages[i][0], style: TextStyle(fontWeight: (done || now) ? FontWeight.w800 : FontWeight.w500, color: (done || now) ? kInk : kMuted, fontSize: 13.5)),
            Text(_stages[i][1], style: const TextStyle(color: kMuted, fontSize: 11.5)),
            const SizedBox(height: 10),
          ]),
        )),
      ]),
    );
  }

  Widget _driverCard(_Driver d) {
    return Container(
      margin: const EdgeInsets.only(top: 6, bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(16), border: Border.all(color: kLine)),
      child: Row(children: [
        Container(width: 48, height: 48, decoration: BoxDecoration(color: kMangoSoft, shape: BoxShape.circle), child: Center(child: Text(d.emoji, style: const TextStyle(fontSize: 24)))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(d.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          Text('${d.veh} · ${d.plate}', style: const TextStyle(color: kMuted, fontSize: 12)),
        ])),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: kGreen, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11))),
          onPressed: () => launchUrl(Uri.parse('tel:081200000000')),
          child: const Text('Hubungi', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}

// ---------- orders ----------
// Map the server's status string to a 0–3 progress stage (tolerant of admin-typed variants).
int stageOfStatus(String s) {
  final t = s.toLowerCase();
  if (t.contains('selesai') || t.contains('sampai')) return 3;
  if (t.contains('antar') || t.contains('kirim')) return 2;
  if (t.contains('proses') || t.contains('belanja') || t.contains('siap')) return 1;
  return 0; // Diterima / menunggu
}

int orderStage(Order o) => stageOfStatus(o.status);

String orderStatusLabel(int stage) {
  switch (stage) {
    case 0:
      return 'Menunggu diproses';
    case 1:
      return 'Sedang dibelanjakan';
    case 2:
      return 'Sedang diantar';
    default:
      return 'Selesai';
  }
}

Color orderStatusColor(int stage) {
  if (stage >= 3) return const Color(0xFF1E8E5A);
  if (stage == 2) return kGreen;
  return const Color(0xFFC7761B);
}

// ---------- notifications (in-app bell inbox) ----------
// A lightweight, derived feed: order-status updates + active promos. No server
// "notifications" table — entries are built on the fly from data the app
// already has, and read-state is tracked locally (last-open time + seen promos).
enum NotifKind { order, promo }

class AppNotif {
  final NotifKind kind;
  final String emoji, title, body;
  final DateTime? time;
  final bool unread;
  final String? orderId;     // order taps open tracking
  final String? promoAction; // promo taps run the promo action
  const AppNotif({
    required this.kind, required this.emoji, required this.title, required this.body,
    this.time, this.unread = false, this.orderId, this.promoAction,
  });
}

String promoKey(PromoBanner p) => p.id > 0 ? 'id:${p.id}' : 'title:${p.title}';

String _orderNotifBody(int stage) {
  switch (stage) {
    case 0: return 'Pesanan diterima, menunggu diproses.';
    case 1: return 'Pesananmu sedang kami siapkan 🛒';
    case 2: return 'Driver sedang mengantar pesananmu 🛵';
    default: return 'Pesanan selesai. Terima kasih! ✅';
  }
}

const List<String> _orderNotifEmoji = ['📥', '🛒', '🛵', '✅'];

String timeAgo(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'Baru saja';
  if (diff.inMinutes < 60) return '${diff.inMinutes} mnt lalu';
  if (diff.inHours < 24) return '${diff.inHours} jam lalu';
  if (diff.inDays < 7) return '${diff.inDays} hari lalu';
  return shortDate(d);
}

// Build the inbox feed: order updates first (newest on top), then promos.
List<AppNotif> buildNotifications(List<Order> orders, List<PromoBanner> promos, DateTime seenAt, Set<String> seenPromos) {
  final orderNotifs = <AppNotif>[];
  for (final o in orders) {
    final stage = orderStage(o); // always 0..3
    orderNotifs.add(AppNotif(
      kind: NotifKind.order,
      emoji: _orderNotifEmoji[stage],
      title: 'Pesanan #${o.id}',
      body: _orderNotifBody(stage),
      time: o.updatedAt,
      unread: o.updatedAt.isAfter(seenAt),
      orderId: o.id,
    ));
  }
  orderNotifs.sort((a, b) => (b.time ?? DateTime(0)).compareTo(a.time ?? DateTime(0)));
  final promoNotifs = [
    for (final p in promos)
      AppNotif(
        kind: NotifKind.promo,
        emoji: p.emoji,
        title: p.title,
        body: p.subtitle,
        unread: !seenPromos.contains(promoKey(p)),
        promoAction: p.action,
      ),
  ];
  return [...orderNotifs, ...promoNotifs];
}

int notifUnreadCount(List<AppNotif> list) => list.where((n) => n.unread).length;

class NotificationsPage extends StatelessWidget {
  final List<AppNotif> notifs;
  final void Function(String orderId) onOpenOrder;
  final void Function(String action) onPromoAction;
  const NotificationsPage({super.key, required this.notifs, required this.onOpenOrder, required this.onPromoAction});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kGround,
      body: Column(children: [
        GreenHeader(
          title: 'Notifikasi',
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        Expanded(
          child: notifs.isEmpty
              ? const EmptyView(emoji: '🔔', text: 'Belum ada notifikasi.\nPesanan & promo akan muncul di sini.')
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                  itemCount: notifs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _tile(context, notifs[i]),
                ),
        ),
      ]),
    );
  }

  Widget _tile(BuildContext context, AppNotif n) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        if (n.kind == NotifKind.order && n.orderId != null) {
          Navigator.pop(context);
          onOpenOrder(n.orderId!);
        } else if (n.kind == NotifKind.promo && n.promoAction != null && n.promoAction!.isNotEmpty) {
          Navigator.pop(context);
          onPromoAction(n.promoAction!);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: n.unread ? kGreenSoft : kSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: n.unread ? kGreen.withValues(alpha: 0.25) : kLine),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(color: kTile, borderRadius: BorderRadius.circular(12)),
            child: Center(child: Text(n.emoji, style: const TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(n.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5))),
              if (n.unread) Container(width: 8, height: 8, margin: const EdgeInsets.only(left: 6), decoration: const BoxDecoration(color: Color(0xFFE0533D), shape: BoxShape.circle)),
            ]),
            const SizedBox(height: 3),
            Text(n.body, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kMuted, fontSize: 13, height: 1.3)),
            if (n.time != null) ...[
              const SizedBox(height: 5),
              Text(timeAgo(n.time!), style: const TextStyle(color: kMuted, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ])),
        ]),
      ),
    );
  }
}

class OrdersPage extends StatefulWidget {
  final List<Order> orders;
  final List<Product> products;
  final void Function(Order) onOpen;
  final void Function(Order) onReorder;
  final Future<void> Function()? onRefresh;
  const OrdersPage({super.key, required this.orders, required this.products, required this.onOpen, required this.onReorder, this.onRefresh});
  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  int _tab = 0;
  static const _tabs = ['Semua', 'Diproses', 'Diantar', 'Selesai'];
  late final Map<String, Product> _byName = {for (final p in widget.products) p.name: p};

  bool _match(Order o) {
    if (_tab == 0) return true;
    final s = orderStage(o);
    if (_tab == 1) return s <= 1;
    if (_tab == 2) return s == 2;
    return s >= 3;
  }

  @override
  Widget build(BuildContext context) {
    final list = widget.orders.where(_match).toList();
    return Column(children: [
      const GreenHeader(title: 'Pesanan Saya'),
      Container(
        color: kSurface,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: List.generate(_tabs.length, (i) {
            final on = i == _tab;
            return GestureDetector(
              onTap: () => setState(() => _tab = i),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: on ? kGreen : Colors.transparent, width: 2.5))),
                child: Text(_tabs[i], style: TextStyle(color: on ? kGreen : kMuted, fontWeight: on ? FontWeight.w800 : FontWeight.w600, fontSize: 13.5)),
              ),
            );
          })),
        ),
      ),
      const Divider(height: 1, color: kLine),
      Expanded(
        child: RefreshIndicator(
          color: kGreen,
          onRefresh: () async {
            if (widget.onRefresh != null) await widget.onRefresh!();
          },
          child: list.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 80),
                    EmptyView(emoji: '🧾', text: widget.orders.isEmpty ? 'Belum ada pesanan.\nYuk mulai belanja di Toko.' : 'Tidak ada pesanan di kategori ini.'),
                  ],
                )
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(12),
                  children: list.map(_card).toList(),
                ),
        ),
      ),
    ]);
  }

  Widget _thumb(OrderItem it) {
    final p = _byName[it.name];
    return Container(
      width: 56,
      height: 56,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: kTile, borderRadius: BorderRadius.circular(10)),
      child: p != null ? productImage(p, emojiSize: 24) : const Center(child: Text('🛍️', style: TextStyle(fontSize: 24))),
    );
  }

  Widget _card(Order o) {
    final stage = orderStage(o);
    final shown = o.items.take(2).toList();
    final more = o.items.length - shown.length;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: kLine)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2), decoration: BoxDecoration(color: kGreen, borderRadius: BorderRadius.circular(4)), child: const Text('Paramall', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800))),
            const SizedBox(width: 8),
            const Text('Belanja Harian', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const Spacer(),
            Text(orderStatusLabel(stage), style: TextStyle(color: orderStatusColor(stage), fontWeight: FontWeight.w700, fontSize: 12)),
          ]),
        ),
        const Divider(height: 1, color: kLine),
        ...shown.map((it) => Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _thumb(it),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(it.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, height: 1.3)),
                  const SizedBox(height: 4),
                  Text(rupiah(it.price), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                ])),
                const SizedBox(width: 8),
                Text('x${it.qty}', style: const TextStyle(color: kMuted, fontSize: 12.5)),
              ]),
            )),
        if (more > 0)
          Padding(padding: const EdgeInsets.only(bottom: 8), child: Center(child: Text('+$more produk lainnya', style: const TextStyle(color: kMuted, fontSize: 12)))),
        const Divider(height: 1, color: kLine),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            Text('Total ${o.count} produk: ', style: const TextStyle(color: kMuted, fontSize: 12.5)),
            Text(rupiah(o.total), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(side: const BorderSide(color: kLine), foregroundColor: kInk, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
              onPressed: () => widget.onOpen(o),
              child: const Text('Lacak', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 10),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: kGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
              onPressed: () => widget.onReorder(o),
              child: const Text('Beli Lagi', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ]),
        ),
      ]),
    );
  }
}


// ---------- profile ----------
class ProfilePage extends StatefulWidget {
  final Profile profile;
  final void Function(Profile) onSave;
  final VoidCallback onGoOrders;
  final VoidCallback onLogout;
  const ProfilePage({super.key, required this.profile, required this.onSave, required this.onGoOrders, required this.onLogout});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  static const _danger = Color(0xFFC0432E);

  String get _displayName => widget.profile.name.isEmpty ? 'Tamu' : widget.profile.name;
  String get _displayPhone => widget.profile.phone.isEmpty ? 'Belum ada nomor HP' : widget.profile.phone;
  String get _initial => widget.profile.name.trim().isNotEmpty ? widget.profile.name.trim()[0].toUpperCase() : 'P';

  void _snack(String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));

  void _openEdit() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProfileEditSheet(profile: widget.profile, onSave: widget.onSave),
    );
  }

  void _openSupport() => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportChatPage()));

  // Hidden admin: tap "Tentang Paramall" 7x.
  int _aboutTaps = 0;
  Timer? _aboutTimer;
  void _tapAbout() {
    _aboutTaps++;
    _aboutTimer?.cancel();
    _aboutTimer = Timer(const Duration(seconds: 2), () => _aboutTaps = 0);
    if (_aboutTaps >= 7) {
      _aboutTaps = 0;
      _aboutTimer?.cancel();
      _askAdminPin();
    } else if (_aboutTaps >= 3) {
      _snack('${7 - _aboutTaps} langkah lagi menuju mode admin…');
    } else {
      _snack('Paramall • Versi 1.0.0');
    }
  }

  void _askAdminPin() {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (dctx) => AlertDialog(
      title: const Text('Mode Staff'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: ctrl, obscureText: true, autofocus: true, keyboardType: TextInputType.text, autocorrect: false, enableSuggestions: false, decoration: const InputDecoration(labelText: 'Passcode admin / driver')),
        const SizedBox(height: 8),
        const Text('Admin: kelola semua pesanan. Driver: antar pesanan.', style: TextStyle(fontSize: 11.5, color: kMuted)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dctx), child: const Text('Batal')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: kGreen),
          onPressed: () {
            final pass = ctrl.text.trim();
            if (hashPin(pass) == kAdminHash) {
              Navigator.pop(dctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => AdminPage(adminPass: pass)));
            } else if (hashPin(pass) == kDriverHash) {
              Navigator.pop(dctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => DriverPage(driverPass: pass)));
            } else {
              _snack('Passcode salah');
            }
          },
          child: const Text('Masuk'),
        ),
      ],
    ));
  }

  @override
  void dispose() {
    _aboutTimer?.cancel();
    super.dispose();
  }

  void _about() {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Tentang Paramall'),
      content: const Text('Paramall — belanja online, kami antar ke rumah.\n\nVersi 1.0.0'),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup'))],
    ));
  }

  void _confirmLogout() {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Keluar?'),
      content: const Text('Kamu perlu masuk lagi untuk memesan.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        TextButton(onPressed: () { Navigator.pop(context); widget.onLogout(); }, child: const Text('Keluar', style: TextStyle(color: _danger, fontWeight: FontWeight.w700))),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: kGround,
      drawer: _buildDrawer(),
      appBar: AppBar(
        backgroundColor: kGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Akun Saya', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        leading: IconButton(icon: const Icon(Icons.menu), onPressed: () => _scaffoldKey.currentState?.openDrawer()),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(18))),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _summaryCard(),
          const SizedBox(height: 18),
          _label('AKUN'),
          _card([
            _tile(Icons.receipt_long_outlined, 'Pesanan Saya', 'Lihat & lacak pesanan', widget.onGoOrders),
            _sep(),
            _tile(Icons.location_on_outlined, 'Alamat Pengantaran', widget.profile.address.isEmpty ? 'Belum diatur' : widget.profile.address, _openEdit),
            _sep(),
            _tile(Icons.person_outline, 'Ubah Data Akun', 'Nama & nomor HP', _openEdit),
          ]),
          const SizedBox(height: 16),
          _label('BANTUAN & INFO'),
          _card([
            _tile(Icons.headset_mic_outlined, 'Pusat Bantuan', 'Chat dengan tim Paramall', _openSupport),
            _sep(),
            _tile(Icons.info_outline, 'Tentang Paramall', 'Versi 1.0.0', _tapAbout),
          ]),
          const SizedBox(height: 22),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), side: const BorderSide(color: Color(0xFFE7C9C1)), foregroundColor: _danger, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            onPressed: _confirmLogout,
            icon: const Icon(Icons.logout, size: 19),
            label: const Text('Keluar', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 14),
          const Center(child: Text('Paramall • v1.0.0', style: TextStyle(color: Color(0xFF9AA39C), fontSize: 12))),
        ],
      ),
    );
  }

  Widget _summaryCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(18), border: Border.all(color: kLine), boxShadow: const [BoxShadow(color: Color(0x0F14281E), blurRadius: 18, offset: Offset(0, 6))]),
    child: Row(children: [
      Container(width: 60, height: 60, decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF2E9C6E), kGreen]), shape: BoxShape.circle), child: Center(child: Text(_initial, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)))),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(_displayName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(_displayPhone, style: const TextStyle(color: kMuted, fontSize: 13)),
      ])),
      TextButton(onPressed: _openEdit, style: TextButton.styleFrom(foregroundColor: kGreen), child: const Text('Ubah', style: TextStyle(fontWeight: FontWeight.w800))),
    ]),
  );

  Widget _label(String t) => Padding(padding: const EdgeInsets.only(left: 4, bottom: 8), child: Text(t, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: kMuted, letterSpacing: 0.6)));

  Widget _card(List<Widget> children) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: kLine)),
    child: Material(color: kSurface, child: Column(children: children)),
  );

  Widget _sep() => const Divider(height: 1, thickness: 1, indent: 56, color: kLine);

  Widget _tile(IconData icon, String title, String subtitle, VoidCallback onTap) => ListTile(
    onTap: onTap,
    leading: Container(width: 38, height: 38, decoration: BoxDecoration(color: kGreenSoft, borderRadius: BorderRadius.circular(11)), child: Icon(icon, color: kGreenInk, size: 20)),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
    subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kMuted, fontSize: 12)),
    trailing: const Icon(Icons.chevron_right, color: kMuted, size: 20),
  );

  Widget _buildDrawer() => Drawer(
    backgroundColor: kGround,
    child: ListView(padding: EdgeInsets.zero, children: [
      Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 24, 20, 22),
        decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF2E9C6E), Color(0xFF12543A)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Container(width: 54, height: 54, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: Center(child: Text(_initial, style: const TextStyle(color: kGreen, fontSize: 24, fontWeight: FontWeight.w800)))),
          const SizedBox(height: 12),
          Text(_displayName, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
          Text(_displayPhone, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ]),
      ),
      _drawerTile(Icons.receipt_long_outlined, 'Pesanan Saya', () { Navigator.pop(context); widget.onGoOrders(); }),
      _drawerTile(Icons.location_on_outlined, 'Alamat Pengantaran', () { Navigator.pop(context); _openEdit(); }),
      _drawerTile(Icons.person_outline, 'Ubah Data Akun', () { Navigator.pop(context); _openEdit(); }),
      _drawerTile(Icons.headset_mic_outlined, 'Pusat Bantuan', () { Navigator.pop(context); _openSupport(); }),
      _drawerTile(Icons.info_outline, 'Tentang Paramall', () { Navigator.pop(context); _about(); }),
      const Divider(),
      _drawerTile(Icons.logout, 'Keluar', () { Navigator.pop(context); _confirmLogout(); }, danger: true),
    ]),
  );

  Widget _drawerTile(IconData icon, String label, VoidCallback onTap, {bool danger = false}) => ListTile(
    leading: Icon(icon, color: danger ? _danger : kGreenInk),
    title: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: danger ? _danger : kInk)),
    onTap: onTap,
  );
}

class _ProfileEditSheet extends StatefulWidget {
  final Profile profile;
  final void Function(Profile) onSave;
  const _ProfileEditSheet({required this.profile, required this.onSave});
  @override
  State<_ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends State<_ProfileEditSheet> {
  late final TextEditingController _name = TextEditingController(text: widget.profile.name);
  late final TextEditingController _phone = TextEditingController(text: widget.profile.phone);
  late final TextEditingController _addr = TextEditingController(text: widget.profile.address);

  @override
  void dispose() { _name.dispose(); _phone.dispose(); _addr.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: kSurface, borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      padding: EdgeInsets.only(left: 18, right: 18, top: 8, bottom: MediaQuery.of(context).viewInsets.bottom + 18),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 2, bottom: 14), decoration: BoxDecoration(color: kLine, borderRadius: BorderRadius.circular(999)))),
        const Text('Ubah Data Akun', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        _f('Nama', _name),
        const SizedBox(height: 12),
        _f('Nomor HP / WhatsApp', _phone, keyboard: TextInputType.phone),
        const SizedBox(height: 12),
        _f('Alamat', _addr, lines: 3),
        const SizedBox(height: 18),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: kGreen, minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          onPressed: () {
            widget.onSave(Profile(name: _name.text.trim(), phone: _phone.text.trim(), address: _addr.text.trim(), pinHash: widget.profile.pinHash));
            Navigator.pop(context);
          },
          child: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }

  Widget _f(String label, TextEditingController c, {int lines = 1, TextInputType? keyboard}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kMuted)),
    const SizedBox(height: 6),
    TextField(controller: c, maxLines: lines, keyboardType: keyboard, decoration: InputDecoration(
      filled: true, fillColor: kGround, isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kLine)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kGreen, width: 1.5)),
    )),
  ]);
}

class _BackBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _BackBtn(this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: Container(width: 30, height: 30, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(999)), child: const Icon(Icons.chevron_left, color: Colors.white)));
}

// ---------- login / register (H2O-style) ----------
const kLoginBg = Color(0xFFEDF3F1);
const kLoginInk = Color(0xFF15241D);
const kLoginSub = Color(0xFF5C6B64);

BoxDecoration _brandBanner() => BoxDecoration(
      borderRadius: BorderRadius.circular(30),
      gradient: const LinearGradient(colors: [Color(0xFF2E9C6E), Color(0xFF12543A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    );

class LoginLanding extends StatelessWidget {
  final Profile account;
  final Authed onAuthed;
  const LoginLanding({super.key, required this.account, required this.onAuthed});

  void _go(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => MasukScreen(account: account, onAuthed: onAuthed)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kLoginBg,
      appBar: AppBar(backgroundColor: kLoginBg, elevation: 0, foregroundColor: kLoginInk, automaticallyImplyLeading: Navigator.canPop(context)),
      body: SafeArea(
        child: Column(children: [
          const Spacer(flex: 3),
          Container(margin: const EdgeInsets.symmetric(horizontal: 24), height: 150, decoration: _brandBanner(),
              child: Center(child: Container(width: 74, height: 74, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                  child: const Icon(Icons.shopping_cart_rounded, color: kGreen, size: 38)))),
          const SizedBox(height: 22),
          const Text('PARAMALL', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: kLoginInk, letterSpacing: 1)),
          const SizedBox(height: 5),
          const Text('P A R A K A N', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: kGreen, letterSpacing: 4)),
          const SizedBox(height: 14),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text('Belanja online di Paramall —\nkami antar ke rumah.', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15.5, color: kLoginSub, height: 1.4))),
          const SizedBox(height: 30),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _go(context),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE6ECEA))),
                child: Row(children: [
                  Container(width: 56, height: 56, decoration: BoxDecoration(color: const Color(0xFFDCEFE6), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.person, color: kGreen, size: 28)),
                  const SizedBox(width: 14),
                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text('Saya Pelanggan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kLoginInk)),
                    SizedBox(height: 3),
                    Text('Masuk dengan nama & no. HP untuk belanja dan melacak pesanan', style: TextStyle(fontSize: 13, color: Color(0xFF6B7A73), height: 1.3)),
                  ])),
                  const Icon(Icons.chevron_right, color: Color(0xFF9AA8A1)),
                ]),
              ),
            ),
          ),
          const Spacer(flex: 4),
        ]),
      ),
    );
  }
}

InputDecoration _authField(String label, IconData icon) => InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: kMuted, size: 20),
      floatingLabelStyle: const TextStyle(color: kGreen),
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFD9E1DE))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kGreen, width: 1.6)),
    );

class MasukScreen extends StatefulWidget {
  final Profile account;
  final Authed onAuthed;
  const MasukScreen({super.key, required this.account, required this.onAuthed});
  @override
  State<MasukScreen> createState() => _MasukScreenState();
}

class _MasukScreenState extends State<MasukScreen> {
  late final TextEditingController _phone = TextEditingController(text: widget.account.phone);
  final TextEditingController _pin = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _phone.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final phone = _phone.text.trim();
    final pin = _pin.text.trim();
    if (phone.isEmpty || pin.isEmpty) {
      _snack('Isi nomor HP dan PIN');
      return;
    }
    setState(() => _busy = true);
    try {
      final r = await Api.login(phone: phone, pin: pin);
      await widget.onAuthed(r.token, r.name, r.phone, r.address);
      if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _snack(e.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        _snack('Gagal masuk. Coba lagi.');
      }
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kLoginBg,
      appBar: AppBar(backgroundColor: kLoginBg, elevation: 0, foregroundColor: kLoginInk, title: const Text('Masuk', style: TextStyle(fontWeight: FontWeight.w800))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        children: [
          const SizedBox(height: 20),
          Container(height: 96, decoration: _brandBanner(), child: const Center(child: Icon(Icons.person, color: Colors.white, size: 40))),
          const SizedBox(height: 22),
          const Text('Selamat datang kembali! 👋', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: kLoginInk)),
          const SizedBox(height: 6),
          const Text('Masuk dengan no. HP dan PIN Anda.', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: kLoginSub)),
          const SizedBox(height: 22),
          TextField(controller: _phone, enabled: !_busy, keyboardType: TextInputType.phone, decoration: _authField('No. HP / WhatsApp', Icons.phone_outlined)),
          const SizedBox(height: 14),
          TextField(controller: _pin, enabled: !_busy, keyboardType: TextInputType.number, obscureText: true, decoration: _authField('PIN', Icons.lock_outline)),
          const SizedBox(height: 22),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF12543A), minimumSize: const Size.fromHeight(54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28))),
            onPressed: _busy ? null : _submit,
            icon: _busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                : const Icon(Icons.login, size: 20),
            label: Text(_busy ? 'Memeriksa…' : 'Masuk', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ),
          const SizedBox(height: 18),
          Center(child: GestureDetector(
            onTap: _busy ? null : () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => DaftarScreen(onAuthed: widget.onAuthed))),
            child: const Text('Belum punya akun? Daftar', style: TextStyle(color: kGreen, fontWeight: FontWeight.w700, fontSize: 15)),
          )),
          const SizedBox(height: 16),
          const Text('Akunmu tersimpan aman di server Paramall.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF9AA8A1), fontSize: 12.5)),
        ],
      ),
    );
  }
}

class DaftarScreen extends StatefulWidget {
  final Authed onAuthed;
  const DaftarScreen({super.key, required this.onAuthed});
  @override
  State<DaftarScreen> createState() => _DaftarScreenState();
}

class _DaftarScreenState extends State<DaftarScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _pin = TextEditingController();
  final _pin2 = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _pin.dispose();
    _pin2.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim(), phone = _phone.text.trim(), pin = _pin.text.trim();
    if (name.isEmpty || phone.isEmpty || pin.isEmpty) {
      _snack('Lengkapi nama, nomor HP, dan PIN');
      return;
    }
    if (pin.length < 4) {
      _snack('PIN minimal 4 angka');
      return;
    }
    if (pin != _pin2.text.trim()) {
      _snack('Konfirmasi PIN tidak sama');
      return;
    }
    setState(() => _busy = true);
    try {
      final r = await Api.register(name: name, phone: phone, pin: pin);
      await widget.onAuthed(r.token, r.name, r.phone, r.address);
      if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _snack(e.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        _snack('Gagal mendaftar. Coba lagi.');
      }
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kLoginBg,
      appBar: AppBar(backgroundColor: kLoginBg, elevation: 0, foregroundColor: kLoginInk, title: const Text('Daftar', style: TextStyle(fontWeight: FontWeight.w800))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        children: [
          const SizedBox(height: 10),
          Container(height: 96, decoration: _brandBanner(), child: const Center(child: Icon(Icons.person_add_alt_1, color: Colors.white, size: 38))),
          const SizedBox(height: 20),
          const Text('Buat akun Paramall', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: kLoginInk)),
          const SizedBox(height: 6),
          const Text('Sekali daftar, belanja jadi cepat.', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: kLoginSub)),
          const SizedBox(height: 22),
          TextField(controller: _name, enabled: !_busy, textCapitalization: TextCapitalization.words, decoration: _authField('Nama', Icons.person_outline)),
          const SizedBox(height: 14),
          TextField(controller: _phone, enabled: !_busy, keyboardType: TextInputType.phone, decoration: _authField('No. HP / WhatsApp', Icons.phone_outlined)),
          const SizedBox(height: 14),
          TextField(controller: _pin, enabled: !_busy, keyboardType: TextInputType.number, obscureText: true, decoration: _authField('Buat PIN (min. 4 angka)', Icons.lock_outline)),
          const SizedBox(height: 14),
          TextField(controller: _pin2, enabled: !_busy, keyboardType: TextInputType.number, obscureText: true, decoration: _authField('Ulangi PIN', Icons.lock_outline)),
          const SizedBox(height: 22),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF12543A), minimumSize: const Size.fromHeight(54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28))),
            onPressed: _busy ? null : _submit,
            icon: _busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                : const Icon(Icons.check, size: 20),
            label: Text(_busy ? 'Mendaftarkan…' : 'Daftar & Masuk', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ),
          const SizedBox(height: 18),
          Center(child: GestureDetector(
            onTap: _busy ? null : () => Navigator.pop(context),
            child: const Text('Sudah punya akun? Masuk', style: TextStyle(color: kGreen, fontWeight: FontWeight.w700, fontSize: 15)),
          )),
        ],
      ),
    );
  }
}

// ---------- guest gate (shown on Pesanan/Saya before login) ----------
class GuestGate extends StatelessWidget {
  final String title;
  final String emoji;
  final String message;
  final VoidCallback onLogin;
  const GuestGate({super.key, required this.title, required this.emoji, required this.message, required this.onLogin});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 14, 16, 14),
        decoration: const BoxDecoration(color: kGreen, borderRadius: BorderRadius.vertical(bottom: Radius.circular(20))),
        child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
      ),
      Expanded(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(emoji, style: const TextStyle(fontSize: 52)),
              const SizedBox(height: 14),
              Text(message, textAlign: TextAlign.center, style: const TextStyle(color: kMuted, fontSize: 14.5, height: 1.4)),
              const SizedBox(height: 20),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: kGreen, minimumSize: const Size(200, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                onPressed: onLogin,
                child: const Text('Masuk / Daftar', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ]),
          ),
        ),
      ),
    ]);
  }
}

// ---------- in-app support chat ----------
class _ChatMsg {
  final bool user;
  final String text;
  _ChatMsg(this.user, this.text);
}

class SupportChatPage extends StatefulWidget {
  const SupportChatPage({super.key});
  @override
  State<SupportChatPage> createState() => _SupportChatPageState();
}

class _SupportChatPageState extends State<SupportChatPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<_ChatMsg> _msgs = [];
  bool _typing = false;

  static const _quick = ['Cara pesan', 'Ongkir', 'Pembayaran', 'Lacak pesanan', 'Chat CS'];

  @override
  void initState() {
    super.initState();
    _msgs.add(_ChatMsg(false, 'Halo! 👋 Aku asisten Paramall. Ada yang bisa dibantu? Pilih topik di bawah atau ketik pesanmu.'));
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  void _send(String text) {
    text = text.trim();
    if (text.isEmpty) return;
    setState(() {
      _msgs.add(_ChatMsg(true, text));
      _typing = true;
    });
    _input.clear();
    _scrollDown();
    Future.delayed(const Duration(milliseconds: 650), () {
      if (!mounted) return;
      final reply = _botReply(text);
      setState(() => _typing = false);
      if (reply == '__WA__') {
        setState(() => _msgs.add(_ChatMsg(false, 'Oke, aku hubungkan ke tim kami lewat WhatsApp ya 👇')));
        _openWa();
      } else {
        setState(() => _msgs.add(_ChatMsg(false, reply)));
      }
      _scrollDown();
    });
  }

  String _botReply(String q) {
    final s = q.toLowerCase();
    if (RegExp(r'pesan|order|beli|cara|belanja').hasMatch(s)) {
      return 'Cara pesan: pilih produk → Keranjang → Checkout → isi alamat → Buat Pesanan. Tim Paramall yang belanjakan & antar ke rumahmu. 🛵';
    }
    if (RegExp(r'ongkir|antar|kirim|area|jauh').hasMatch(s)) {
      return 'Ongkir Rp10.000 — GRATIS untuk belanja di atas Rp100.000. Kami antar ke area kotamu.';
    }
    if (RegExp(r'bayar|pembayaran|cod|transfer|qris').hasMatch(s)) {
      return 'Pembayaran bisa Bayar di Tempat (COD) atau Transfer Bank. QRIS menyusul ya.';
    }
    if (RegExp(r'lacak|status|track|pesanan saya|driver').hasMatch(s)) {
      return 'Lacak pesanan: buka tab Pesanan → pilih pesananmu untuk lihat status & driver. 📦';
    }
    if (RegExp(r'jam|buka|operasional|kapan').hasMatch(s)) {
      return 'Kami melayani setiap hari. Pesanan yang masuk langsung diproses tim kami.';
    }
    if (RegExp(r'cs|admin|manusia|orang|whatsapp|komplain|refund|batal').hasMatch(s)) {
      return '__WA__';
    }
    return 'Maaf, aku belum paham 🙏. Untuk bantuan lebih lanjut, chat langsung tim kami lewat WhatsApp (ikon di kanan atas).';
  }

  void _openWa() {
    if (kWaNumber.isEmpty) {
      setState(() => _msgs.add(_ChatMsg(false, 'Nomor WhatsApp tim kami segera hadir ya 🙏. Sementara ini aku bantu jawab di sini.')));
      _scrollDown();
      return;
    }
    launchUrl(Uri.parse('https://wa.me/$kWaNumber?text=${Uri.encodeComponent('Halo Paramall, saya mau tanya.')}'), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kGround,
      appBar: AppBar(
        backgroundColor: kGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        title: Row(children: [
          Container(width: 36, height: 36, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const Center(child: Text('🛒', style: TextStyle(fontSize: 18)))),
          const SizedBox(width: 10),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('Pusat Bantuan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            Text('Paramall Assistant • online', style: TextStyle(fontSize: 11, color: Colors.white70)),
          ]),
        ]),
        actions: [IconButton(onPressed: _openWa, icon: const Icon(Icons.chat_bubble_outline), tooltip: 'Chat WhatsApp')],
      ),
      body: Column(children: [
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            itemCount: _msgs.length + (_typing ? 1 : 0),
            itemBuilder: (_, i) {
              if (_typing && i == _msgs.length) return _bubble(_ChatMsg(false, 'sedang mengetik…'), typing: true);
              return _bubble(_msgs[i]);
            },
          ),
        ),
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: _quick
                .map((q) => Padding(
                      padding: const EdgeInsets.only(right: 8, top: 6, bottom: 6),
                      child: ActionChip(
                        label: Text(q),
                        backgroundColor: kGreenSoft,
                        labelStyle: const TextStyle(color: kGreenInk, fontWeight: FontWeight.w600, fontSize: 12.5),
                        side: BorderSide.none,
                        onPressed: () => _send(q),
                      ),
                    ))
                .toList(),
          ),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + MediaQuery.of(context).padding.bottom),
          decoration: const BoxDecoration(color: kSurface, border: Border(top: BorderSide(color: kLine))),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _input,
                textInputAction: TextInputAction.send,
                onSubmitted: _send,
                decoration: InputDecoration(
                  hintText: 'Ketik pesan…',
                  filled: true,
                  fillColor: kGround,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _send(_input.text),
              child: Container(width: 44, height: 44, decoration: const BoxDecoration(color: kGreen, shape: BoxShape.circle), child: const Icon(Icons.send, color: Colors.white, size: 20)),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _bubble(_ChatMsg m, {bool typing = false}) {
    final user = m.user;
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.76),
        decoration: BoxDecoration(
          color: user ? kGreen : kSurface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(user ? 16 : 4),
            bottomRight: Radius.circular(user ? 4 : 16),
          ),
          border: user ? null : Border.all(color: kLine),
        ),
        child: Text(m.text, style: TextStyle(color: user ? Colors.white : (typing ? kMuted : kInk), fontSize: 14, fontStyle: typing ? FontStyle.italic : FontStyle.normal, height: 1.35)),
      ),
    );
  }
}

// ---------- hidden in-app admin (unlock: tap Tentang Paramall 7x) ----------
class AdminPage extends StatefulWidget {
  final String adminPass;
  const AdminPage({super.key, required this.adminPass});
  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  List<Order> _orders = [];
  bool _loading = true;
  String? _error;
  final Set<String> _busy = {}; // order ids currently updating

  @override
  void initState() {
    super.initState();
    Push.subscribeStaff(); // this device now hears about new orders
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final o = await Api.adminOrders(widget.adminPass);
      if (!mounted) return;
      setState(() {
        _orders = o;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Tidak bisa memuat pesanan. Cek koneksi.';
        _loading = false;
      });
    }
  }

  Future<void> _setStatus(Order o, String status) async {
    setState(() => _busy.add(o.id));
    try {
      await Api.setStatus(adminPass: widget.adminPass, id: o.id, status: status);
      await _load();
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
    } catch (_) {
      if (mounted) _snack('Gagal memperbarui status.');
    } finally {
      if (mounted) setState(() => _busy.remove(o.id));
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));

  int get _revenue => _orders.fold(0, (a, b) => a + b.total);
  int get _active => _orders.where((o) => orderStage(o) < 3).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kGround,
      appBar: AppBar(
        backgroundColor: const Color(0xFF12543A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Mode Admin', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh), tooltip: 'Muat ulang')],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kGreen))
          : _error != null
              ? _errorView()
              : RefreshIndicator(
                  color: kGreen,
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      Row(children: [
                        Expanded(child: _stat('Total Pesanan', '${_orders.length}', Icons.receipt_long)),
                        const SizedBox(width: 10),
                        Expanded(child: _stat('Aktif', '$_active', Icons.local_shipping)),
                        const SizedBox(width: 10),
                        Expanded(child: _stat('Omzet', rupiah(_revenue), Icons.payments)),
                      ]),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: kMango, foregroundColor: const Color(0xFF3A2400), minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminPromosScreen(adminPass: widget.adminPass))),
                        icon: const Icon(Icons.campaign),
                        label: const Text('Kelola Promo (Banner)', style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: kGreen, minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                        onPressed: () => launchUrl(Uri.parse('https://paramall.h2olaundry.com/admin'), mode: LaunchMode.externalApplication),
                        icon: const Icon(Icons.tune),
                        label: const Text('Kelola Harga & Katalog (Web)', style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(height: 20),
                      const Text('Pesanan Masuk (semua pelanggan)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      const SizedBox(height: 10),
                      if (_orders.isEmpty)
                        const Padding(padding: EdgeInsets.only(top: 30), child: EmptyView(emoji: '🧾', text: 'Belum ada pesanan masuk.'))
                      else
                        ..._orders.map(_orderRow),
                    ],
                  ),
                ),
    );
  }

  Widget _errorView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('⚠️', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 12),
            Text(_error ?? '', textAlign: TextAlign.center, style: const TextStyle(color: kMuted, fontSize: 14)),
            const SizedBox(height: 18),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: kGreen),
              onPressed: _load,
              child: const Text('Coba lagi'),
            ),
          ]),
        ),
      );

  Widget _stat(String label, String value, IconData icon) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(16), border: Border.all(color: kLine)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: kGreen, size: 20),
          const SizedBox(height: 8),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kMuted, fontSize: 11)),
        ]),
      );

  Widget _orderRow(Order o) {
    final stage = orderStage(o);
    final busy = _busy.contains(o.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: kLine)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('#${o.id}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: orderStatusColor(stage).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
            child: Text(orderStatusLabel(stage), style: TextStyle(color: orderStatusColor(stage), fontWeight: FontWeight.w800, fontSize: 11)),
          ),
        ]),
        const SizedBox(height: 6),
        Text('${o.name} • ${o.phone}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
        Text(o.addr, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kMuted, fontSize: 11.5)),
        const SizedBox(height: 6),
        ...o.items.map((it) => Text('• ${it.qty}× ${it.name}', style: const TextStyle(fontSize: 11.5, color: kInk), maxLines: 1, overflow: TextOverflow.ellipsis)),
        const SizedBox(height: 6),
        Text('${o.count} produk • ${rupiah(o.total)} • ${o.pay}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
        if (o.note.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text('Catatan: ${o.note}', style: const TextStyle(fontSize: 11.5, color: kMuted, fontStyle: FontStyle.italic))),
        const Divider(height: 18),
        busy
            ? const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 4), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: kGreen))))
            : Wrap(spacing: 8, runSpacing: 8, children: [
                _statusBtn(o, 'Diproses', stage == 1),
                _statusBtn(o, 'Diantar', stage == 2),
                _statusBtn(o, 'Selesai', stage == 3),
              ]),
      ]),
    );
  }

  Widget _statusBtn(Order o, String status, bool active) {
    return GestureDetector(
      onTap: active ? null : () => _setStatus(o, status),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? kGreen : kGreenSoft,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? kGreen : kLine),
        ),
        child: Text(status, style: TextStyle(color: active ? Colors.white : kGreenInk, fontWeight: FontWeight.w800, fontSize: 12.5)),
      ),
    );
  }
}

// ---------- driver mode (unlock: staff passcode → driver code) ----------
class DriverPage extends StatefulWidget {
  final String driverPass;
  const DriverPage({super.key, required this.driverPass});
  @override
  State<DriverPage> createState() => _DriverPageState();
}

class _DriverPageState extends State<DriverPage> {
  List<Order> _orders = [];
  bool _loading = true;
  String? _error;
  final Set<String> _busy = {};
  int _tab = 0; // 0 = Perlu diantar, 1 = Sedang diantar

  @override
  void initState() {
    super.initState();
    Push.subscribeStaff(); // driver device hears about new orders
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final o = await Api.driverOrders(widget.driverPass);
      if (!mounted) return;
      setState(() {
        _orders = o;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Tidak bisa memuat pesanan. Cek koneksi.';
        _loading = false;
      });
    }
  }

  Future<void> _setStatus(Order o, String status) async {
    setState(() => _busy.add(o.id));
    try {
      await Api.driverSetStatus(driverPass: widget.driverPass, id: o.id, status: status);
      await _load();
      if (mounted) _snack(status == 'Diantar' ? 'Diambil — selamat mengantar! 🛵' : 'Pesanan selesai ✅');
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
    } catch (_) {
      if (mounted) _snack('Gagal memperbarui status.');
    } finally {
      if (mounted) setState(() => _busy.remove(o.id));
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));

  Future<void> _call(String phone) async {
    final p = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (p.isEmpty) return;
    await launchUrl(Uri.parse('tel:$p'));
  }

  Future<void> _maps(String addr) async {
    final q = Uri.encodeComponent(addr);
    await launchUrl(Uri.parse('https://www.google.com/maps/search/?api=1&query=$q'), mode: LaunchMode.externalApplication);
  }

  Future<void> _openDelivery(Order o) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => DriverDeliveryScreen(order: o, driverPass: widget.driverPass)));
    await _load();
  }

  bool _isDelivering(Order o) => orderStage(o) == 2; // Diantar

  List<Order> get _list => _orders.where((o) => _tab == 0 ? !_isDelivering(o) : _isDelivering(o)).toList();

  @override
  Widget build(BuildContext context) {
    final toPickup = _orders.where((o) => !_isDelivering(o)).length;
    final delivering = _orders.where(_isDelivering).length;
    return Scaffold(
      backgroundColor: kGround,
      appBar: AppBar(
        backgroundColor: const Color(0xFF12543A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Mode Driver', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh), tooltip: 'Muat ulang')],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kGreen))
          : _error != null
              ? _errorView()
              : Column(children: [
                  Container(
                    color: kSurface,
                    child: Row(children: [
                      _tabBtn(0, 'Perlu diantar', toPickup),
                      _tabBtn(1, 'Sedang diantar', delivering),
                    ]),
                  ),
                  const Divider(height: 1, color: kLine),
                  Expanded(
                    child: RefreshIndicator(
                      color: kGreen,
                      onRefresh: _load,
                      child: _list.isEmpty
                          ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [
                              SizedBox(height: 90),
                              EmptyView(emoji: '🛵', text: 'Tidak ada pesanan di sini.\nTarik ke bawah untuk memuat ulang.'),
                            ])
                          : ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(12),
                              children: _list.map(_card).toList(),
                            ),
                    ),
                  ),
                ]),
    );
  }

  Widget _tabBtn(int i, String label, int count) {
    final on = i == _tab;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = i),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: on ? kGreen : Colors.transparent, width: 2.5))),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(label, style: TextStyle(color: on ? kGreen : kMuted, fontWeight: on ? FontWeight.w800 : FontWeight.w600, fontSize: 13.5)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(color: on ? kGreen : kTile, borderRadius: BorderRadius.circular(999)),
              child: Text('$count', style: TextStyle(color: on ? Colors.white : kMuted, fontWeight: FontWeight.w800, fontSize: 11)),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _errorView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('⚠️', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 12),
            Text(_error ?? '', textAlign: TextAlign.center, style: const TextStyle(color: kMuted, fontSize: 14)),
            const SizedBox(height: 18),
            FilledButton(style: FilledButton.styleFrom(backgroundColor: kGreen), onPressed: _load, child: const Text('Coba lagi')),
          ]),
        ),
      );

  Widget _card(Order o) {
    final busy = _busy.contains(o.id);
    final delivering = _isDelivering(o);
    final isCod = o.pay.toUpperCase() == 'COD';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: kLine)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // COD banner — what the driver must collect on delivery.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(color: isCod ? kMangoSoft : kGreenSoft, borderRadius: const BorderRadius.vertical(top: Radius.circular(13))),
          child: Row(children: [
            Text(isCod ? '💵' : '✅', style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 8),
            Expanded(child: Text(isCod ? 'Tagih tunai (COD)' : '${o.pay} — sudah diatur', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5))),
            Text(rupiah(o.total), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: isCod ? const Color(0xFF8A5300) : kGreenInk)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('#${o.id}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
              const Spacer(),
              Text('${o.count} produk', style: const TextStyle(color: kMuted, fontSize: 12)),
            ]),
            const SizedBox(height: 6),
            Text(o.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 2),
            Text(o.addr, style: const TextStyle(fontSize: 13, color: kInk, height: 1.3)),
            if (o.note.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: Text('Catatan: ${o.note}', style: const TextStyle(fontSize: 12, color: kMuted, fontStyle: FontStyle.italic))),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: kGreenInk, side: const BorderSide(color: kLine), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 10)),
                onPressed: () => _call(o.phone),
                icon: const Icon(Icons.call, size: 17),
                label: const Text('Telepon', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
              )),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: kGreenInk, side: const BorderSide(color: kLine), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 10)),
                onPressed: () => _maps(o.addr),
                icon: const Icon(Icons.map_outlined, size: 17),
                label: const Text('Peta', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
              )),
            ]),
            const Divider(height: 20),
            ...o.items.map((it) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text('• ${it.qty}× ${it.name}', style: const TextStyle(fontSize: 12.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                )),
            const SizedBox(height: 12),
            if (busy)
              const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 4), child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: kGreen))))
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: delivering ? const Color(0xFF1E8E5A) : kGreen, minimumSize: const Size.fromHeight(46), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () => _openDelivery(o),
                  icon: Icon(delivering ? Icons.navigation : Icons.pedal_bike, size: 19),
                  label: Text(delivering ? 'Lanjut Antar (peta)' : 'Ambil & Antar', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                ),
              ),
          ]),
        ),
      ]),
    );
  }
}

// ================= live delivery tracking (OpenStreetMap) =================

// Smoothly interpolate a marker between two coordinates so it glides, not jumps.
class LatLngTween extends Tween<LatLng> {
  LatLngTween({required LatLng begin, required LatLng end}) : super(begin: begin, end: end);
  @override
  LatLng lerp(double t) => LatLng(
        begin!.latitude + (end!.latitude - begin!.latitude) * t,
        begin!.longitude + (end!.longitude - begin!.longitude) * t,
      );
}

TileLayer _osmTiles() => TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.paramall.app',
      maxZoom: 19,
    );

class _DriverPin extends StatelessWidget {
  const _DriverPin();
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: kGreen, shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: const Center(child: Text('🛵', style: TextStyle(fontSize: 22))),
      );
}

/// An OSM map that shows the driver's live (animated) position, and optionally
/// the destination. Size it from the parent (SizedBox height, or Expanded).
class LiveDeliveryMap extends StatefulWidget {
  final LatLng? driver;
  final LatLng? destination;
  const LiveDeliveryMap({super.key, this.driver, this.destination});
  @override
  State<LiveDeliveryMap> createState() => _LiveDeliveryMapState();
}

class _LiveDeliveryMapState extends State<LiveDeliveryMap> {
  final MapController _map = MapController();

  @override
  void didUpdateWidget(covariant LiveDeliveryMap old) {
    super.didUpdateWidget(old);
    final d = widget.driver;
    if (d != null && d != old.driver) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          _map.move(d, _map.camera.zoom);
        } catch (_) {}
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final center = widget.driver ?? widget.destination ?? const LatLng(-7.3167, 110.1667); // Parakan-ish default
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: FlutterMap(
        mapController: _map,
        options: MapOptions(
          initialCenter: center,
          initialZoom: 15,
          interactionOptions: const InteractionOptions(flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag),
        ),
        children: [
          _osmTiles(),
          if (widget.destination != null)
            MarkerLayer(markers: [
              Marker(point: widget.destination!, width: 40, height: 40, child: const Text('🏠', style: TextStyle(fontSize: 30))),
            ]),
          if (widget.driver != null)
            TweenAnimationBuilder<LatLng>(
              tween: LatLngTween(begin: widget.driver!, end: widget.driver!),
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeInOut,
              builder: (_, pos, __) => MarkerLayer(markers: [
                Marker(point: pos, width: 46, height: 46, child: const _DriverPin()),
              ]),
            ),
        ],
      ),
    );
  }
}

/// Driver-side screen: streams GPS to the server while delivering, and lets the
/// driver mark the order done.
class DriverDeliveryScreen extends StatefulWidget {
  final Order order;
  final String driverPass;
  const DriverDeliveryScreen({super.key, required this.order, required this.driverPass});
  @override
  State<DriverDeliveryScreen> createState() => _DriverDeliveryScreenState();
}

class _DriverDeliveryScreenState extends State<DriverDeliveryScreen> {
  Timer? _t;
  LatLng? _pos;
  String? _err;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    if (orderStage(widget.order) < 2) {
      try {
        await Api.driverSetStatus(driverPass: widget.driverPass, id: widget.order.id, status: 'Diantar');
      } catch (_) {}
    }
    if (!await _ensurePermission()) {
      if (mounted) setState(() => _err = 'Izin lokasi ditolak. Aktifkan lokasi agar pelanggan bisa melihat posisimu.');
      return;
    }
    await _tick();
    _t = Timer.periodic(const Duration(seconds: 4), (_) => _tick());
  }

  Future<bool> _ensurePermission() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return false;
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      return p == LocationPermission.always || p == LocationPermission.whileInUse;
    } catch (_) {
      return false;
    }
  }

  Future<void> _tick() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final ll = LatLng(pos.latitude, pos.longitude);
      if (mounted) setState(() => _pos = ll);
      await Api.sendDriverLocation(driverPass: widget.driverPass, id: widget.order.id, lat: ll.latitude, lng: ll.longitude);
    } catch (_) {}
  }

  Future<void> _finish() async {
    setState(() => _finishing = true);
    try {
      await Api.driverSetStatus(driverPass: widget.driverPass, id: widget.order.id, status: 'Selesai');
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _finishing = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : 'Gagal menyelesaikan')));
    }
  }

  Future<void> _call() async {
    final p = widget.order.phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (p.isNotEmpty) await launchUrl(Uri.parse('tel:$p'));
  }

  Future<void> _maps() async {
    await launchUrl(Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(widget.order.addr)}'), mode: LaunchMode.externalApplication);
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    return Scaffold(
      backgroundColor: kGround,
      appBar: AppBar(
        backgroundColor: const Color(0xFF12543A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('Antar #${o.id}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      ),
      body: Column(children: [
        Expanded(
          child: _err != null
              ? Center(child: Padding(padding: const EdgeInsets.all(30), child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('📍', style: TextStyle(fontSize: 44)),
                  const SizedBox(height: 12),
                  Text(_err!, textAlign: TextAlign.center, style: const TextStyle(color: kMuted, fontSize: 14)),
                  const SizedBox(height: 16),
                  FilledButton(style: FilledButton.styleFrom(backgroundColor: kGreen), onPressed: () { setState(() => _err = null); _start(); }, child: const Text('Coba lagi')),
                ])))
              : Padding(padding: const EdgeInsets.all(12), child: LiveDeliveryMap(driver: _pos)),
        ),
        Container(
          decoration: const BoxDecoration(color: kSurface, border: Border(top: BorderSide(color: kLine))),
          padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: kGreenSoft, borderRadius: BorderRadius.circular(999)),
                child: Text(_pos == null ? 'Mencari lokasi…' : 'Berbagi lokasi • live', style: const TextStyle(color: kGreenInk, fontWeight: FontWeight.w700, fontSize: 11.5)),
              ),
              const Spacer(),
              Text(o.pay.toUpperCase() == 'COD' ? 'Tagih ${rupiah(o.total)}' : '${o.pay} • lunas', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: kInk)),
            ]),
            const SizedBox(height: 8),
            Text(o.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            Text(o.addr, style: const TextStyle(fontSize: 13, color: kInk, height: 1.3)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: kGreenInk, side: const BorderSide(color: kLine), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 10)),
                onPressed: _call, icon: const Icon(Icons.call, size: 17), label: const Text('Telepon', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: kGreenInk, side: const BorderSide(color: kLine), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 10)),
                onPressed: _maps, icon: const Icon(Icons.navigation_outlined, size: 17), label: const Text('Navigasi', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)))),
            ]),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1E8E5A), minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: _finishing ? null : _finish,
              icon: _finishing ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white)) : const Icon(Icons.check_circle, size: 19),
              label: Text(_finishing ? 'Menyelesaikan…' : 'Tandai Selesai', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
            )),
          ]),
        ),
      ]),
    );
  }
}

// ================= promo banners =================

// Rotating, auto-scrolling promo banners with dot indicators.
class PromoCarousel extends StatefulWidget {
  final List<PromoBanner> promos;
  final void Function(String action) onAction;
  const PromoCarousel({super.key, required this.promos, required this.onAction});
  @override
  State<PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends State<PromoCarousel> {
  final PageController _pc = PageController(viewportFraction: 0.92);
  int _i = 0;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    if (widget.promos.length > 1) {
      _t = Timer.periodic(const Duration(seconds: 4), (_) {
        if (!_pc.hasClients) return;
        _pc.animateToPage((_i + 1) % widget.promos.length, duration: const Duration(milliseconds: 450), curve: Curves.easeInOut);
      });
    }
  }

  @override
  void dispose() {
    _t?.cancel();
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.promos.isEmpty) return const SizedBox.shrink();
    return Column(children: [
      SizedBox(
        height: 140,
        child: PageView.builder(
          controller: _pc,
          onPageChanged: (i) => setState(() => _i = i),
          itemCount: widget.promos.length,
          itemBuilder: (_, i) => _card(widget.promos[i]),
        ),
      ),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(widget.promos.length, (i) {
        final on = i == _i;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: on ? 18 : 6, height: 6,
          decoration: BoxDecoration(color: on ? kGreen : kLine, borderRadius: BorderRadius.circular(999)),
        );
      })),
    ]);
  }

  Widget _card(PromoBanner p) {
    return GestureDetector(
      onTap: p.action == null ? null : () => widget.onAction(p.action!),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(colors: p.colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          boxShadow: [BoxShadow(color: p.colors.last.withValues(alpha: 0.30), blurRadius: 14, offset: const Offset(0, 6))],
        ),
        child: Row(children: [
          Expanded(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16.5)),
            const SizedBox(height: 4),
            Text(p.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.25)),
            if (p.action != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
                child: Text('Lihat', style: TextStyle(color: p.colors.last, fontWeight: FontWeight.w800, fontSize: 12)),
              ),
            ],
          ])),
          const SizedBox(width: 10),
          Text(p.emoji, style: const TextStyle(fontSize: 44)),
        ]),
      ),
    );
  }
}

// One-time welcome/promo popup (Shopee-style).
Future<void> showPromoPopup(BuildContext context, PromoBanner p) async {
  await showDialog(
    context: context,
    barrierDismissible: true,
    builder: (dctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(28),
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(22, 30, 22, 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(colors: p.colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(p.emoji, style: const TextStyle(fontSize: 54)),
            const SizedBox(height: 14),
            Text(p.title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 21)),
            const SizedBox(height: 8),
            Text(p.subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.45)),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: p.colors.last, minimumSize: const Size.fromHeight(48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              onPressed: () => Navigator.pop(dctx),
              child: const Text('Mulai Belanja', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
            )),
          ]),
        ),
        Positioned(right: -6, top: -6, child: GestureDetector(
          onTap: () => Navigator.pop(dctx),
          child: Container(width: 30, height: 30, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const Icon(Icons.close, size: 18, color: kInk)),
        )),
      ]),
    ),
  );
}

// ================= admin: manage promo banners =================
class AdminPromosScreen extends StatefulWidget {
  final String adminPass;
  const AdminPromosScreen({super.key, required this.adminPass});
  @override
  State<AdminPromosScreen> createState() => _AdminPromosScreenState();
}

class _AdminPromosScreenState extends State<AdminPromosScreen> {
  List<Map<String, dynamic>> _promos = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = await Api.adminPromos(widget.adminPass);
      if (!mounted) return;
      setState(() {
        _promos = p;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : 'Gagal memuat promo.';
        _loading = false;
      });
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));

  void _edit(Map<String, dynamic>? promo) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PromoEditSheet(adminPass: widget.adminPass, promo: promo, onSaved: _load),
    );
  }

  Future<void> _delete(Map<String, dynamic> p) async {
    final ok = await showDialog<bool>(context: context, builder: (d) => AlertDialog(
      title: const Text('Hapus promo?'),
      content: Text('"${p['title']}" akan dihapus.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Batal')),
        TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Hapus', style: TextStyle(color: Color(0xFFC0432E), fontWeight: FontWeight.w700))),
      ],
    ));
    if (ok != true) return;
    try {
      await Api.adminDeletePromo(adminPass: widget.adminPass, id: int.tryParse('${p['id']}') ?? 0);
      await _load();
    } catch (e) {
      if (mounted) _snack(e is ApiException ? e.message : 'Gagal menghapus.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kGround,
      appBar: AppBar(
        backgroundColor: const Color(0xFF12543A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Kelola Promo', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kGreen,
        onPressed: () => _edit(null),
        icon: const Icon(Icons.add),
        label: const Text('Promo Baru', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kGreen))
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(30), child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('⚠️', style: TextStyle(fontSize: 40)),
                  const SizedBox(height: 10),
                  Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: kMuted)),
                  const SizedBox(height: 14),
                  FilledButton(style: FilledButton.styleFrom(backgroundColor: kGreen), onPressed: _load, child: const Text('Coba lagi')),
                ])))
              : _promos.isEmpty
                  ? const Center(child: EmptyView(emoji: '📣', text: 'Belum ada promo.\nTap “Promo Baru” untuk membuat.'))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
                      children: _promos.map(_card).toList(),
                    ),
    );
  }

  Widget _card(Map<String, dynamic> p) {
    final banner = PromoBanner.fromJson(p);
    final active = (p['active'] ?? 1).toString() != '0';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(16), border: Border.all(color: kLine)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          margin: const EdgeInsets.all(10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(colors: banner.colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(banner.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
              const SizedBox(height: 2),
              Text(banner.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
            ])),
            const SizedBox(width: 8),
            Text(banner.emoji, style: const TextStyle(fontSize: 30)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 8, 4),
          child: Row(children: [
            if (banner.isPopup) _tag('POPUP', kMango),
            if (banner.isPopup) const SizedBox(width: 6),
            _tag(active ? 'AKTIF' : 'NONAKTIF', active ? kGreen : kMuted),
            if (banner.action != null) ...[const SizedBox(width: 6), _tag(banner.action!, const Color(0xFF3A7BD5))],
            const Spacer(),
            TextButton.icon(onPressed: () => _edit(p), icon: const Icon(Icons.edit, size: 17), label: const Text('Ubah'), style: TextButton.styleFrom(foregroundColor: kGreenInk)),
            IconButton(onPressed: () => _delete(p), icon: const Icon(Icons.delete_outline, color: Color(0xFFC0432E))),
          ]),
        ),
      ]),
    );
  }

  Widget _tag(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
        child: Text(t, style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 10.5)),
      );
}

class _PromoEditSheet extends StatefulWidget {
  final String adminPass;
  final Map<String, dynamic>? promo;
  final VoidCallback onSaved;
  const _PromoEditSheet({required this.adminPass, required this.promo, required this.onSaved});
  @override
  State<_PromoEditSheet> createState() => _PromoEditSheetState();
}

class _PromoEditSheetState extends State<_PromoEditSheet> {
  late final TextEditingController _title = TextEditingController(text: widget.promo?['title']?.toString() ?? '');
  late final TextEditingController _subtitle = TextEditingController(text: widget.promo?['subtitle']?.toString() ?? '');
  late final TextEditingController _emoji = TextEditingController(text: widget.promo?['emoji']?.toString() ?? '🎉');
  late int _grad = _initGrad();
  late String _action = (widget.promo?['action']?.toString().isNotEmpty ?? false) ? widget.promo!['action'].toString() : '';
  late bool _isPopup = (widget.promo?['is_popup'] ?? 0).toString() == '1';
  late bool _active = (widget.promo?['active'] ?? 1).toString() != '0';
  bool _busy = false;

  int _initGrad() {
    final c1 = (widget.promo?['color1'] ?? '').toString().toUpperCase();
    for (int i = 0; i < kPromoGradients.length; i++) {
      if (kPromoGradients[i][0].toUpperCase() == c1) return i;
    }
    return 0;
  }

  List<String> get _categories => kCatOrder.where((c) => c != 'Semua').toList();
  // Keep the dropdown value valid even if the saved action isn't a known category.
  String get _validAction {
    final valid = ['', ..._categories.map((c) => 'cat:$c')];
    return valid.contains(_action) ? _action : '';
  }

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    _emoji.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(const SnackBar(content: Text('Isi judul promo')));
      return;
    }
    setState(() => _busy = true);
    try {
      await Api.adminSavePromo(adminPass: widget.adminPass, promo: {
        'id': int.tryParse('${widget.promo?['id'] ?? 0}') ?? 0,
        'title': _title.text.trim(),
        'subtitle': _subtitle.text.trim(),
        'emoji': _emoji.text.trim().isEmpty ? '🎉' : _emoji.text.trim(),
        'color1': kPromoGradients[_grad][0],
        'color2': kPromoGradients[_grad][1],
        'action': _action,
        'is_popup': _isPopup ? 1 : 0,
        'sort_order': int.tryParse('${widget.promo?['sort_order'] ?? 0}') ?? 0,
        'active': _active ? 1 : 0,
      });
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : 'Gagal menyimpan.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = [promoHex(kPromoGradients[_grad][0]), promoHex(kPromoGradients[_grad][1])];
    return Container(
      decoration: const BoxDecoration(color: kSurface, borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      padding: EdgeInsets.only(left: 18, right: 18, top: 8, bottom: MediaQuery.of(context).viewInsets.bottom + 18),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 2, bottom: 14), decoration: BoxDecoration(color: kLine, borderRadius: BorderRadius.circular(999)))),
          Text(widget.promo == null ? 'Promo Baru' : 'Ubah Promo', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          // live preview
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight)),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(_title.text.isEmpty ? 'Judul promo' : _title.text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 3),
                Text(_subtitle.text.isEmpty ? 'Deskripsi singkat…' : _subtitle.text, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ])),
              const SizedBox(width: 8),
              Text(_emoji.text.isEmpty ? '🎉' : _emoji.text, style: const TextStyle(fontSize: 34)),
            ]),
          ),
          const SizedBox(height: 14),
          _f('Judul', _title),
          const SizedBox(height: 10),
          _f('Deskripsi', _subtitle, lines: 2),
          const SizedBox(height: 10),
          _f('Emoji', _emoji),
          const SizedBox(height: 14),
          const Text('Warna', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kMuted)),
          const SizedBox(height: 8),
          Row(children: List.generate(kPromoGradients.length, (i) {
            final on = i == _grad;
            return GestureDetector(
              onTap: () => setState(() => _grad = i),
              child: Container(
                width: 46, height: 46, margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(colors: [promoHex(kPromoGradients[i][0]), promoHex(kPromoGradients[i][1])], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  border: Border.all(color: on ? kInk : Colors.transparent, width: 2.5),
                ),
                child: on ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
              ),
            );
          })),
          const SizedBox(height: 14),
          const Text('Tombol menuju', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kMuted)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _validAction,
            isExpanded: true,
            decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kLine)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kGreen, width: 1.5))),
            items: [
              const DropdownMenuItem(value: '', child: Text('Tidak ada (info saja)')),
              ..._categories.map((c) => DropdownMenuItem(value: 'cat:$c', child: Text('Kategori: $c'))),
            ],
            onChanged: (v) => setState(() => _action = v ?? ''),
          ),
          const SizedBox(height: 6),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeThumbColor: kGreen,
            value: _isPopup,
            onChanged: (v) => setState(() => _isPopup = v),
            title: const Text('Tampilkan sebagai popup pembuka', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
            subtitle: const Text('Muncul saat aplikasi dibuka', style: TextStyle(fontSize: 11.5, color: kMuted)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeThumbColor: kGreen,
            value: _active,
            onChanged: (v) => setState(() => _active = v),
            title: const Text('Aktif', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kGreen, minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Menyimpan…' : 'Simpan Promo', style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ]),
      ),
    );
  }

  Widget _f(String label, TextEditingController c, {int lines = 1}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kMuted)),
        const SizedBox(height: 6),
        TextField(
          controller: c, maxLines: lines,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            filled: true, fillColor: kGround, isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kLine)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kGreen, width: 1.5)),
          ),
        ),
      ]);
}
