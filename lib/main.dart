import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:url_launcher/url_launcher.dart';
import 'store.dart';

void main() => runApp(const ParamallApp());

// ---------- config ----------
const String kWaNumber = ''; // isi nomor WhatsApp penjual, contoh: '628123456789'
const int kOngkir = 10000;
const int kFreeOngkirMin = 100000;

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
  'Semua', 'Sembako', 'Makanan Instan', 'Minuman', 'Snack', 'Perawatan', 'Rumah Tangga', 'Bayi', 'Lainnya',
];
const Map<String, String> kCatEmoji = {
  'Sembako': '🍚', 'Makanan Instan': '🍜', 'Minuman': '🥤', 'Snack': '🍪',
  'Perawatan': '🧴', 'Rumah Tangga': '🧻', 'Bayi': '🍼', 'Lainnya': '🛍️',
};
final List<List<String>> _catRules = [
  ['Makanan Instan', r'\b(indomie|mie|mi instan|sedaap|bihun|bubur instan)\b'],
  ['Minuman', r'(teh|kopi|susu|jus|juice|minuman|air mineral|aqua|isotonik|soda|sari|nutriboost|pocari|kratingdaeng|le mineral|sprite|coca|fanta|floridina|koffie)'],
  ['Sembako', r'(beras|minyak goreng|gula|telur|tepung|kecap|saus|sambal|garam|margarin|mentega|santan)'],
  ['Snack', r'(keripik|biskuit|wafer|coklat|cokelat|permen|snack|chiki|tortilla|mentos|roti|kacang|astor|oreo)'],
  ['Perawatan', r'(sabun mandi|shampoo|sampo|pasta gigi|sikat gigi|odol|deodorant|lotion|handbody|pembalut|kapas)'],
  ['Rumah Tangga', r'(tisu|tissue|detergen|deterjen|pewangi|pembersih|sabun cuci|pengharum|kamper|baterai)'],
  ['Bayi', r'(popok|diaper|mamypoko|sweety|merries|baby|bayi)'],
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
}

Future<List<Product>> loadCatalog() async {
  final raw = await rootBundle.loadString('assets/catalog.json');
  final data = jsonDecode(raw) as List<dynamic>;
  return data
      .map((e) => Product.fromJson(e as Map<String, dynamic>))
      .where((p) => p.name.isNotEmpty && p.price > 0)
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
      theme: ThemeData(colorScheme: scheme, useMaterial3: true, scaffoldBackgroundColor: kGround, fontFamily: 'Roboto'),
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
  List<Product> _products = [];
  final Map<int, int> _cart = {};
  String _shopCat = 'Semua';
  Profile _profile = Profile();
  List<Order> _orders = [];
  bool _session = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await loadCatalog();
      final prof = await Store.getProfile();
      final ords = await Store.getOrders();
      final sess = await Store.loggedIn();
      if (!mounted) return;
      setState(() {
        _products = p;
        _profile = prof;
        _orders = ords;
        _session = sess && prof.hasAccount;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get cartCount => _cart.values.fold(0, (a, b) => a + b);
  int get subtotal => _cart.entries.fold(0, (a, e) => a + _products[e.key].price * e.value);
  int get ongkir => (subtotal >= kFreeOngkirMin || subtotal == 0) ? 0 : kOngkir;

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
    Navigator.push(context, MaterialPageRoute(builder: (_) {
      return CheckoutPage(
        products: _products,
        cart: Map<int, int>.from(_cart),
        profile: _profile,
        subtotal: subtotal,
        ongkir: ongkir,
        onPlaced: _placeOrder,
      );
    }));
  }

  Future<void> _placeOrder(Order o) async {
    _profile = Profile(name: o.name, phone: o.phone, address: o.addr);
    await Store.saveProfile(_profile);
    await Store.addOrder(o);
    if (!mounted) return;
    setState(() {
      _orders.insert(0, o);
      _cart.clear();
    });
  }

  void _openTracking(Order o, {bool justPlaced = false}) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => TrackingPage(order: o, justPlaced: justPlaced)));
  }

  void _saveProfile(Profile p) async {
    setState(() => _profile = p);
    await Store.saveProfile(p);
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Data tersimpan')));
    }
  }

  Future<void> _onAuthed(Profile p) async {
    await Store.saveProfile(p);
    await Store.setLoggedIn(true);
    if (!mounted) return;
    setState(() {
      _profile = p;
      _session = true;
      _tab = 0;
    });
  }

  void _logout() async {
    await Store.setLoggedIn(false);
    if (!mounted) return;
    setState(() {
      _session = false;
      _tab = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: kGreen)));
    }
    if (!_session) {
      return LoginLanding(account: _profile, onAuthed: _onAuthed);
    }
    final pages = [
      ShopPage(products: _products, cart: _cart, activeCat: _shopCat, onCat: _setCat,
          onAdd: (i) => _addToCart(i, 1), onOpen: _openSheet, onGoOrders: () => setState(() => _tab = 3)),
      CategoryPage(products: _products, onPick: _setCat),
      CartPage(products: _products, cart: _cart, onQty: _setQty, subtotal: subtotal, ongkir: ongkir, onCheckout: _openCheckout),
      OrdersPage(orders: _orders, onOpen: (o) => _openTracking(o)),
      ProfilePage(profile: _profile, onSave: _saveProfile, onGoOrders: () => setState(() => _tab = 3), onLogout: _logout),
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
// them (Alfamart's CDN sends no CORS headers). img.php lives at the site root.
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
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(a, style: TextStyle(color: bold ? kInk : kMuted, fontWeight: bold ? FontWeight.w800 : FontWeight.w500, fontSize: bold ? 16 : 13.5)),
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
  const ShopPage({super.key, required this.products, required this.cart, required this.activeCat,
      required this.onCat, required this.onAdd, required this.onOpen, required this.onGoOrders});
  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  String _search = '';

  List<int> get _visible {
    final term = _search.trim().toLowerCase();
    final out = <int>[];
    for (int i = 0; i < widget.products.length; i++) {
      final p = widget.products[i];
      if ((widget.activeCat == 'Semua' || p.cat == widget.activeCat) && (term.isEmpty || p.name.toLowerCase().contains(term))) {
        out.add(i);
      }
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
        SliverToBoxAdapter(child: _promo()),
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

  Widget _header() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 12, 16, 14),
      decoration: const BoxDecoration(color: kGreen, borderRadius: BorderRadius.vertical(bottom: Radius.circular(20))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: const [
          _LogoBox(),
          SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('Paramall', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
            Text('Belanja Alfamart & Indomaret — kami yang antar', style: TextStyle(color: Colors.white70, fontSize: 11)),
          ])),
        ]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(13)),
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: const InputDecoration(
                icon: Icon(Icons.search, size: 20, color: kMuted), hintText: 'Cari Indomie, beras, minyak…', border: InputBorder.none),
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
    if (kWaNumber.isNotEmpty) {
      launchUrl(Uri.parse('https://wa.me/$kWaNumber?text=${Uri.encodeComponent('Halo Paramall, saya mau tanya.')}'),
          mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Bantuan: hubungi tim Paramall lewat WhatsApp (nomor menyusul).')));
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

  Widget _promo() {
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
          Text('Pilih barangnya, tim Paramall beli di Alfamart / Indomaret & antar ke rumah.', style: TextStyle(fontSize: 12, color: kMuted)),
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
                  child: const Text('Hemat', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF3A2400))))),
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
                  child: const Text('Masukkan Keranjang', style: TextStyle(fontWeight: FontWeight.w800)),
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
  final int ongkir;
  final Future<void> Function(Order) onPlaced;
  const CheckoutPage({super.key, required this.products, required this.cart, required this.profile, required this.subtotal, required this.ongkir, required this.onPlaced});
  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  late final TextEditingController _name = TextEditingController(text: widget.profile.name);
  late final TextEditingController _phone = TextEditingController(text: widget.profile.phone);
  late final TextEditingController _addr = TextEditingController(text: widget.profile.address);
  final TextEditingController _note = TextEditingController();
  String _pay = 'COD';
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _addr.dispose();
    _note.dispose();
    super.dispose();
  }

  int get total => widget.subtotal + widget.ongkir;

  String _payLabel(String p) => p == 'COD' ? 'Bayar di Tempat (COD)' : p == 'Transfer' ? 'Transfer Bank' : 'QRIS';

  String _orderId() {
    final d = DateTime.now();
    String p(int n) => n.toString().padLeft(2, '0');
    return 'PM${p(d.year % 100)}${p(d.month)}${p(d.day)}-${p(d.hour)}${p(d.minute)}${p(d.second)}';
  }

  Future<void> _place() async {
    if (_name.text.trim().isEmpty || _phone.text.trim().isEmpty || _addr.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Lengkapi nama, HP, dan alamat dulu')));
      return;
    }
    setState(() => _busy = true);
    final items = widget.cart.entries.map((e) => OrderItem(name: widget.products[e.key].name, price: widget.products[e.key].price, qty: e.value)).toList();
    final order = Order(
      id: _orderId(), at: DateTime.now(),
      name: _name.text.trim(), phone: _phone.text.trim(), addr: _addr.text.trim(), note: _note.text.trim(), pay: _pay,
      items: items, subtotal: widget.subtotal, ongkir: widget.ongkir, total: total,
    );
    await widget.onPlaced(order);
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => TrackingPage(order: order, justPlaced: true)));
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
              const Text('Metode Pembayaran', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 10),
              _payTile('COD', '💵', 'Bayar di Tempat (COD)', 'Bayar tunai saat barang diantar'),
              _payTile('Transfer', '🏦', 'Transfer Bank', 'Info rekening dikirim setelah pesan'),
              _payTile('QRIS', '📱', 'QRIS', 'Scan & bayar (menyusul)'),
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
                  moneyRow(widget.ongkir == 0 ? 'Ongkir (gratis)' : 'Ongkir', rupiah(widget.ongkir)),
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
  ['Sedang dibelanjakan', 'Tim belanja di Alfamart/Indomaret'],
  ['Driver mengantar', 'Driver dalam perjalanan ke rumahmu'],
  ['Pesanan selesai', 'Barang sudah diterima. Terima kasih!'],
];
const List<int> _stageAt = [0, 20, 60, 130]; // detik (demo)

class TrackingPage extends StatefulWidget {
  final Order order;
  final bool justPlaced;
  const TrackingPage({super.key, required this.order, this.justPlaced = false});
  @override
  State<TrackingPage> createState() => _TrackingPageState();
}

class _TrackingPageState extends State<TrackingPage> {
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  int get _stage {
    final el = DateTime.now().difference(widget.order.at).inSeconds;
    int s = 0;
    for (int i = 0; i < _stageAt.length; i++) {
      if (el >= _stageAt[i]) s = i;
    }
    return s;
  }

  _Driver get _driver {
    int sum = 0;
    for (final c in widget.order.id.codeUnits) {
      sum += c;
    }
    return _drivers[sum % _drivers.length];
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
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
class OrdersPage extends StatelessWidget {
  final List<Order> orders;
  final void Function(Order) onOpen;
  const OrdersPage({super.key, required this.orders, required this.onOpen});
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const GreenHeader(title: 'Pesanan Saya'),
      Expanded(
        child: orders.isEmpty
            ? const EmptyView(emoji: '🧾', text: 'Belum ada pesanan.\nYuk mulai belanja di Toko.')
            : ListView(
                padding: const EdgeInsets.all(16),
                children: orders.map((o) {
                  return GestureDetector(
                    onTap: () => onOpen(o),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: kLine)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text('#${o.id}', style: const TextStyle(color: kMuted, fontSize: 12.5)),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3), decoration: BoxDecoration(color: kGreenSoft, borderRadius: BorderRadius.circular(999)), child: const Text('Lacak ›', style: TextStyle(color: kGreenInk, fontWeight: FontWeight.w700, fontSize: 11))),
                        ]),
                        const SizedBox(height: 6),
                        Text('${o.count} barang • ${shortDate(o.at)}', style: const TextStyle(fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(rupiah(o.total), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      ]),
                    ),
                  );
                }).toList(),
              ),
      ),
    ]);
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
  late final TextEditingController _name = TextEditingController(text: widget.profile.name);
  late final TextEditingController _phone = TextEditingController(text: widget.profile.phone);
  late final TextEditingController _addr = TextEditingController(text: widget.profile.address);

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _addr.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.profile.name.isNotEmpty ? widget.profile.name.trim()[0].toUpperCase() : '😊';
    return Column(children: [
      const GreenHeader(title: 'Saya'),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(children: [
              Container(width: 56, height: 56, decoration: const BoxDecoration(color: kGreen, shape: BoxShape.circle), child: Center(child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)))),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(widget.profile.name.isEmpty ? 'Tamu' : widget.profile.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                Text(widget.profile.phone.isEmpty ? 'Belum ada nomor HP' : widget.profile.phone, style: const TextStyle(color: kMuted, fontSize: 12.5)),
              ])),
            ]),
            const SizedBox(height: 18),
            const Text('Data Saya', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 10),
            _field('Nama', _name),
            _field('Nomor HP / WhatsApp', _phone, keyboard: TextInputType.phone),
            _field('Alamat', _addr, lines: 3),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: kGreen, minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              onPressed: () => widget.onSave(Profile(name: _name.text.trim(), phone: _phone.text.trim(), address: _addr.text.trim(), pinHash: widget.profile.pinHash)),
              child: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), side: const BorderSide(color: kLine), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              onPressed: widget.onGoOrders,
              child: const Text('Lihat Pesanan Saya', style: TextStyle(fontWeight: FontWeight.w700, color: kInk)),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: widget.onLogout,
              child: const Text('Keluar', style: TextStyle(fontWeight: FontWeight.w700, color: kMuted)),
            ),
          ],
        ),
      ),
    ]);
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
  final Future<void> Function(Profile) onAuthed;
  const LoginLanding({super.key, required this.account, required this.onAuthed});

  void _go(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => MasukScreen(account: account, onAuthed: onAuthed)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kLoginBg,
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
              child: Text('Belanja Alfamart & Indomaret.\nKami yang belanja & antar ke rumah.', textAlign: TextAlign.center,
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
  final Future<void> Function(Profile) onAuthed;
  const MasukScreen({super.key, required this.account, required this.onAuthed});
  @override
  State<MasukScreen> createState() => _MasukScreenState();
}

class _MasukScreenState extends State<MasukScreen> {
  late final TextEditingController _phone = TextEditingController(text: widget.account.phone);
  final TextEditingController _pin = TextEditingController();

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
    final acc = widget.account;
    if (!acc.hasAccount || acc.phone != phone || acc.pinHash != hashPin(pin)) {
      _snack('Nomor HP atau PIN salah. Belum punya akun? Daftar dulu.');
      return;
    }
    await widget.onAuthed(acc);
    if (mounted) Navigator.popUntil(context, (r) => r.isFirst);
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
          TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: _authField('No. HP / WhatsApp', Icons.phone_outlined)),
          const SizedBox(height: 14),
          TextField(controller: _pin, keyboardType: TextInputType.number, obscureText: true, decoration: _authField('PIN', Icons.lock_outline)),
          const SizedBox(height: 22),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF12543A), minimumSize: const Size.fromHeight(54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28))),
            onPressed: _submit,
            icon: const Icon(Icons.login, size: 20),
            label: const Text('Masuk', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ),
          const SizedBox(height: 18),
          Center(child: GestureDetector(
            onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => DaftarScreen(onAuthed: widget.onAuthed))),
            child: const Text('Belum punya akun? Daftar', style: TextStyle(color: kGreen, fontWeight: FontWeight.w700, fontSize: 15)),
          )),
          const SizedBox(height: 16),
          const Text('Akunmu tersimpan di perangkat ini.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF9AA8A1), fontSize: 12.5)),
        ],
      ),
    );
  }
}

class DaftarScreen extends StatefulWidget {
  final Future<void> Function(Profile) onAuthed;
  const DaftarScreen({super.key, required this.onAuthed});
  @override
  State<DaftarScreen> createState() => _DaftarScreenState();
}

class _DaftarScreenState extends State<DaftarScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _pin = TextEditingController();
  final _pin2 = TextEditingController();

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
    await widget.onAuthed(Profile(name: name, phone: phone, pinHash: hashPin(pin)));
    if (mounted) Navigator.popUntil(context, (r) => r.isFirst);
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
          TextField(controller: _name, textCapitalization: TextCapitalization.words, decoration: _authField('Nama', Icons.person_outline)),
          const SizedBox(height: 14),
          TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: _authField('No. HP / WhatsApp', Icons.phone_outlined)),
          const SizedBox(height: 14),
          TextField(controller: _pin, keyboardType: TextInputType.number, obscureText: true, decoration: _authField('Buat PIN (min. 4 angka)', Icons.lock_outline)),
          const SizedBox(height: 14),
          TextField(controller: _pin2, keyboardType: TextInputType.number, obscureText: true, decoration: _authField('Ulangi PIN', Icons.lock_outline)),
          const SizedBox(height: 22),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF12543A), minimumSize: const Size.fromHeight(54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28))),
            onPressed: _submit,
            icon: const Icon(Icons.check, size: 20),
            label: const Text('Daftar & Masuk', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ),
          const SizedBox(height: 18),
          Center(child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Text('Sudah punya akun? Masuk', style: TextStyle(color: kGreen, fontWeight: FontWeight.w700, fontSize: 15)),
          )),
        ],
      ),
    );
  }
}
