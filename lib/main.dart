import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

void main() => runApp(const ParamallApp());

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

// ---------- model ----------
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
    final scheme = ColorScheme.fromSeed(seedColor: kGreen, primary: kGreen);
    return MaterialApp(
      title: 'Paramall',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
        scaffoldBackgroundColor: kGround,
        fontFamily: 'Roboto',
      ),
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
  final Map<int, int> _cart = {}; // product index -> qty

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await loadCatalog();
      if (!mounted) return;
      setState(() {
        _products = p;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get cartCount => _cart.values.fold(0, (a, b) => a + b);
  int get subtotal => _cart.entries.fold(0, (a, e) => a + _products[e.key].price * e.value);
  int get ongkir => (subtotal >= 100000 || subtotal == 0) ? 0 : 10000;

  void _setQty(int i, int v) {
    setState(() {
      if (v <= 0) {
        _cart.remove(i);
      } else {
        _cart[i] = v;
      }
    });
  }

  void _addToCart(int i, int qty) {
    _setQty(i, (_cart[i] ?? 0) + qty);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Ditambahkan ke keranjang'), duration: Duration(milliseconds: 1200)));
  }

  void _openSheet(int i) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProductSheet(product: _products[i], onAdd: (qty) => _addToCart(i, qty)),
    );
  }

  void _goTab(int i) => setState(() => _tab = i);

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: kGreen)));
    }
    final pages = [
      ShopPage(products: _products, cart: _cart, onAdd: (i) => _addToCart(i, 1), onOpen: _openSheet),
      CategoryPage(products: _products),
      CartPage(products: _products, cart: _cart, onQty: _setQty, subtotal: subtotal, ongkir: ongkir),
      const _Soon(title: 'Pesanan', emoji: '🧾', note: 'Riwayat & lacak pesanan menyusul di tahap berikutnya.'),
      const _Soon(title: 'Saya', emoji: '😊', note: 'Profil & login menyusul di tahap berikutnya.'),
    ];
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: kSurface,
          indicatorColor: kGreenSoft,
          labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        ),
        child: NavigationBar(
          height: 64,
          selectedIndex: _tab,
          onDestinationSelected: _goTab,
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
      ),
    );
  }
}

// ---------- shared bits ----------
Widget productImage(Product p, {double emojiSize = 40}) {
  final emoji = kCatEmoji[p.cat] ?? '🛍️';
  Widget fallback() => Center(child: Text(emoji, style: TextStyle(fontSize: emojiSize)));
  if (p.imageUrl.isEmpty) return fallback();
  return Image.network(
    p.imageUrl,
    fit: BoxFit.contain,
    errorBuilder: (_, __, ___) => fallback(),
    loadingBuilder: (_, child, prog) => prog == null ? child : fallback(),
  );
}

// ---------- shop ----------
class ShopPage extends StatefulWidget {
  final List<Product> products;
  final Map<int, int> cart;
  final void Function(int index) onAdd;
  final void Function(int index) onOpen;
  const ShopPage({super.key, required this.products, required this.cart, required this.onAdd, required this.onOpen});
  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  String _cat = 'Semua';
  String _search = '';

  List<int> get _visible {
    final term = _search.trim().toLowerCase();
    final out = <int>[];
    for (int i = 0; i < widget.products.length; i++) {
      final p = widget.products[i];
      if ((_cat == 'Semua' || p.cat == _cat) && (term.isEmpty || p.name.toLowerCase().contains(term))) {
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
              crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.66,
            ),
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
        Row(children: [
          Container(width: 34, height: 34, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
              child: const Center(child: Text('🛒', style: TextStyle(fontSize: 18)))),
          const SizedBox(width: 10),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('Paramall', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
            Text('Belanja Alfamart & Indomaret — kami yang antar',
                style: TextStyle(color: Colors.white70, fontSize: 11)),
          ])),
        ]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(13)),
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: const InputDecoration(
              icon: Icon(Icons.search, size: 20, color: kMuted),
              hintText: 'Cari Indomie, beras, minyak…',
              border: InputBorder.none,
            ),
          ),
        ),
      ]),
    );
  }

  Widget _quickMenu() {
    final items = [
      ['🍚', 'Sembako', const Color(0xFFE3F0E9)],
      ['🍜', 'Makanan\nInstan', const Color(0xFFFBEAD1)],
      ['🥤', 'Minuman', const Color(0xFFE3EDF6)],
      ['🛵', 'Lacak\nPesanan', const Color(0xFFEEE6F4)],
      ['💬', 'Bantuan', const Color(0xFFE7F2EB)],
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 2),
      child: Row(
        children: items.map((it) {
          return Expanded(
            child: InkWell(
              onTap: () {
                final label = (it[1] as String).replaceAll('\n', ' ');
                if (label == 'Sembako') setState(() => _cat = 'Sembako');
                else if (label == 'Makanan Instan') setState(() => _cat = 'Makanan Instan');
                else if (label == 'Minuman') setState(() => _cat = 'Minuman');
                else {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(const SnackBar(content: Text('Fitur ini menyusul di tahap berikutnya')));
                }
              },
              borderRadius: BorderRadius.circular(12),
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

  Widget _catChips() {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
        children: _cats.map((c) {
          final on = c == _cat;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _cat = c),
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
          Text('Pilih barangnya, tim Paramall beli di Alfamart / Indomaret & antar ke rumah.',
              style: TextStyle(fontSize: 12, color: kMuted)),
        ])),
      ]),
    );
  }
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
              Positioned.fill(child: ClipRRect(borderRadius: BorderRadius.circular(12),
                  child: Container(color: kTile, child: productImage(product)))),
              if (product.discounted)
                Positioned(top: 6, left: 6, child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(color: kMango, borderRadius: BorderRadius.circular(999)),
                  child: const Text('Hemat', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF3A2400))))),
            ]),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 34,
            child: Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.25)),
          ),
          const SizedBox(height: 6),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              if (product.discounted)
                Text(rupiah(product.priceOriginal!),
                    style: const TextStyle(fontSize: 11, color: kMuted, decoration: TextDecoration.lineThrough)),
              Text(rupiah(product.price), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            ])),
            GestureDetector(
              onTap: onAdd,
              child: Container(width: 34, height: 34, decoration: BoxDecoration(color: kGreenSoft, borderRadius: BorderRadius.circular(11)),
                  child: const Icon(Icons.add, size: 20, color: kGreenInk)),
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
          Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 10, bottom: 4),
              decoration: BoxDecoration(color: kLine, borderRadius: BorderRadius.circular(999))),
          Container(margin: const EdgeInsets.fromLTRB(16, 6, 16, 0), height: 180,
              decoration: BoxDecoration(color: kTile, borderRadius: BorderRadius.circular(16)),
              child: productImage(p, emojiSize: 80)),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(p.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, height: 1.35)),
              const SizedBox(height: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: kGreenSoft, borderRadius: BorderRadius.circular(999)),
                  child: Text(p.cat, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: kGreenInk))),
              const SizedBox(height: 12),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(rupiah(p.price), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                if (p.discounted) ...[
                  const SizedBox(width: 8),
                  Text(rupiah(p.priceOriginal!),
                      style: const TextStyle(fontSize: 14, color: kMuted, decoration: TextDecoration.lineThrough)),
                ],
              ]),
              const SizedBox(height: 18),
              Row(children: [
                _stepBtn(Icons.remove, () => setState(() => qty = qty > 1 ? qty - 1 : 1)),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text('$qty', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                _stepBtn(Icons.add, () => setState(() => qty++)),
                const SizedBox(width: 12),
                Expanded(child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: kGreen, padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
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
        onTap: onTap,
        child: Container(width: 34, height: 34, decoration: BoxDecoration(color: kTile, borderRadius: BorderRadius.circular(10)),
            child: Icon(ic, size: 18, color: kInk)),
      );
}

// ---------- categories ----------
class CategoryPage extends StatelessWidget {
  final List<Product> products;
  const CategoryPage({super.key, required this.products});
  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final p in products) {
      counts[p.cat] = (counts[p.cat] ?? 0) + 1;
    }
    final cats = kCatOrder.where((c) => c != 'Semua' && (counts[c] ?? 0) > 0).toList();
    return _Scaffolded(
      title: 'Kategori',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: cats.map((c) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(16), border: Border.all(color: kLine)),
            child: Row(children: [
              Container(width: 46, height: 46, decoration: BoxDecoration(color: kGreenSoft, borderRadius: BorderRadius.circular(13)),
                  child: Center(child: Text(kCatEmoji[c] ?? '🛍️', style: const TextStyle(fontSize: 24)))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(c, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                Text('${counts[c]} produk', style: const TextStyle(color: kMuted, fontSize: 11.5)),
              ])),
              const Icon(Icons.chevron_right, color: kMuted),
            ]),
          );
        }).toList(),
      ),
    );
  }
}

// ---------- cart ----------
class CartPage extends StatelessWidget {
  final List<Product> products;
  final Map<int, int> cart;
  final void Function(int index, int qty) onQty;
  final int subtotal;
  final int ongkir;
  const CartPage({super.key, required this.products, required this.cart, required this.onQty, required this.subtotal, required this.ongkir});

  @override
  Widget build(BuildContext context) {
    final entries = cart.entries.toList();
    return _Scaffolded(
      title: 'Keranjang',
      child: entries.isEmpty
          ? const _Empty(emoji: '🛒', text: 'Keranjang masih kosong.\nYuk pilih barang di Toko.')
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
                      Container(width: 64, height: 64, decoration: BoxDecoration(color: kTile, borderRadius: BorderRadius.circular(12)),
                          child: productImage(p, emojiSize: 28)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(rupiah(p.price), style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 6),
                        Row(children: [
                          _cartStep(Icons.remove, () => onQty(e.key, e.value - 1)),
                          Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text('${e.value}', style: const TextStyle(fontWeight: FontWeight.w700))),
                          _cartStep(Icons.add, () => onQty(e.key, e.value + 1)),
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
                    _sline('Subtotal', rupiah(subtotal)),
                    _sline(ongkir == 0 ? 'Ongkir (gratis)' : 'Ongkir', rupiah(ongkir)),
                    const Divider(height: 18),
                    _sline('Total', rupiah(subtotal + ongkir), bold: true),
                  ]),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: kGreen, minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  onPressed: () {
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(const SnackBar(content: Text('Checkout menyusul di tahap berikutnya')));
                  },
                  child: Text('Checkout · ${rupiah(subtotal + ongkir)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                ),
              ],
            ),
    );
  }

  Widget _cartStep(IconData ic, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(width: 28, height: 28, decoration: BoxDecoration(color: kTile, borderRadius: BorderRadius.circular(9), border: Border.all(color: kLine)),
            child: Icon(ic, size: 16, color: kInk)),
      );

  Widget _sline(String a, String b, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(a, style: TextStyle(color: bold ? kInk : kMuted, fontWeight: bold ? FontWeight.w800 : FontWeight.w500, fontSize: bold ? 16 : 13.5)),
          Text(b, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600, fontSize: bold ? 17 : 13.5)),
        ]),
      );
}

// ---------- scaffolding helpers ----------
class _Scaffolded extends StatelessWidget {
  final String title;
  final Widget child;
  const _Scaffolded({required this.title, required this.child});
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 14, 16, 14),
        decoration: const BoxDecoration(color: kGreen, borderRadius: BorderRadius.vertical(bottom: Radius.circular(20))),
        child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
      ),
      Expanded(child: child),
    ]);
  }
}

class _Empty extends StatelessWidget {
  final String emoji;
  final String text;
  const _Empty({required this.emoji, required this.text});
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

class _Soon extends StatelessWidget {
  final String title;
  final String emoji;
  final String note;
  const _Soon({required this.title, required this.emoji, required this.note});
  @override
  Widget build(BuildContext context) => _Scaffolded(title: title, child: _Empty(emoji: emoji, text: note));
}
