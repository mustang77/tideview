import 'dart:async';

import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../widgets.dart';
import 'new_order_screen.dart';
import 'order_detail_screen.dart';
import 'owner_access.dart';
import 'promo.dart';

class CustomerShell extends StatefulWidget {
  const CustomerShell({super.key});

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  int _index = 0;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    store.refresh();
    _poll = Timer.periodic(
        const Duration(seconds: 30), (_) => store.refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              // Sengaja TANPA const: instance const dianggap identik oleh
              // Flutter sehingga tab tidak ikut rebuild saat data store
              // berubah (mis. jumlah reaksi promo).
              child: switch (_index) {
                0 => _HomeTab(),
                1 => _OrdersTab(history: false),
                2 => _KomunitasTab(),
                _ => _ProfileTab(),
              },
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          tooltip: 'Buat Postingan',
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const PromoComposeScreen())),
          shape: const CircleBorder(),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          child: const Icon(Icons.add, size: 30),
        ),
        floatingActionButtonLocation:
            FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: BottomAppBar(
          shape: const CircularNotchedRectangle(),
          notchMargin: 8,
          color: Colors.white,
          elevation: 12,
          height: 62,
          padding: EdgeInsets.zero,
          child: Row(
            children: [
              NavIcon(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  label: 'Beranda',
                  selected: _index == 0,
                  onTap: () => setState(() => _index = 0)),
              NavIcon(
                  icon: Icons.receipt_long_outlined,
                  activeIcon: Icons.receipt_long,
                  label: 'Pesanan',
                  selected: _index == 1,
                  onTap: () => setState(() => _index = 1)),
              const SizedBox(width: 72),
              NavIcon(
                  icon: Icons.groups_outlined,
                  activeIcon: Icons.groups,
                  label: 'Komunitas',
                  selected: _index == 2,
                  onTap: () => setState(() => _index = 2)),
              NavIcon(
                  icon: Icons.person_outline,
                  activeIcon: Icons.person,
                  label: 'Profil',
                  selected: _index == 3,
                  onTap: () => setState(() => _index = 3)),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Beranda

class _HomeTab extends StatefulWidget {
  const _HomeTab();

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  final _secretTaps = SecretTapCounter();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = store.profile.name;
    Order? active;
    for (final o in store.orders) {
      if (!o.selesai) {
        active = o;
        break;
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        BrandHeader(
          onLogoTap: () {
            if (_secretTaps.registerTap(context)) enterOwnerMode(context);
          },
        ),
        const SizedBox(height: 18),
        const ServerOfflineBanner(),
        Text(
          name.isEmpty ? 'Halo! 👋' : 'Halo, ${name.split(' ').first}! 👋',
          style: theme.textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text('Mau cuci apa hari ini?',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 16),
        if (active != null) ...[
          _ActiveOrderCard(order: active),
          const SizedBox(height: 20),
        ] else ...[
          _PromoBanner(theme: theme),
          const SizedBox(height: 20),
        ],
        const SectionTitle('Layanan Kami'),
        GridView.count(
          crossAxisCount: MediaQuery.sizeOf(context).width > 560 ? 3 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.15,
          children: [
            for (final s in store.services) _ServiceCard(service: s),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: Icon(Icons.storefront,
                color: theme.colorScheme.primary),
            title: const Text('Langsung di Counter',
                style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text(
                'Antar dan ambil cucian Anda langsung di counter H2O Laundry Parakan.'),
          ),
        ),
        ...(() {
          final promos =
              store.posts.where((p) => p.byAdmin).toList();
          if (promos.isEmpty) return const <Widget>[];
          return <Widget>[
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(child: SectionTitle('Info & Promo')),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const PromoFeedScreen())),
                  child: const Text('Lihat Semua'),
                ),
              ],
            ),
            // Reels video (bila ada), lalu hanya promo terbaru —
            // selengkapnya di layar feed & tab Komunitas.
            const ReelsStrip(),
            PromoCard(post: promos.first),
          ];
        })(),
      ],
    );
  }
}

class _PromoBanner extends StatelessWidget {
  const _PromoBanner({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF06B6D4), Color(0xFF0E7490)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cucian numpuk?',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pesan sekarang, bawa ke counter, kami kerjakan cepat.',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13),
                ),
              ],
            ),
          ),
          const Icon(Icons.local_laundry_service,
              color: Colors.white, size: 48),
        ],
      ),
    );
  }
}

class _ActiveOrderCard extends StatelessWidget {
  const _ActiveOrderCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress =
        (order.status.index + 1) / OrderStatus.values.length;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => OrderDetailScreen(order: order))),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Pesanan Aktif • ${order.id}',
                        style: theme.textTheme.bodySmall),
                  ),
                  StatusChip(order: order),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                order.itemsBrief,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  color: statusColor(order.status),
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 8),
              Text('Ketuk untuk lacak pesanan',
                  style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.service});

  final ServiceType service;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => NewOrderScreen(initialService: service))),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(serviceIcon(service.id),
                    size: 22, color: theme.colorScheme.onPrimaryContainer),
              ),
              const Spacer(),
              Text(service.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13.5)),
              const SizedBox(height: 2),
              Text(
                '${rupiah(service.price)}/${service.unit}',
                style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5),
              ),
              Text('Estimasi ${service.estimasiHari} hari',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Pesanan

class _OrdersTab extends StatelessWidget {
  const _OrdersTab({required this.history});

  final bool history;

  @override
  Widget build(BuildContext context) {
    final orders =
        store.orders.where((o) => history ? o.selesai : !o.selesai).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(history ? 'Riwayat' : 'Pesanan Saya',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
              ),
              if (!history)
                FilledButton.tonalIcon(
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const NewOrderScreen())),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Buat Pesanan'),
                ),
            ],
          ),
        ),
        Expanded(
          child: orders.isEmpty
              ? EmptyState(
                  icon: history
                      ? Icons.history_outlined
                      : Icons.receipt_long_outlined,
                  message: history
                      ? 'Belum ada pesanan yang selesai.'
                      : 'Belum ada pesanan aktif.\nKetuk "Buat Pesanan" untuk memesan!',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: orders.length,
                  itemBuilder: (context, i) => OrderCard(
                    order: orders[i],
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) =>
                              OrderDetailScreen(order: orders[i])),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

// -------------------------------------------------------------- Komunitas

/// Tab Komunitas: feed semua postingan (promo resmi + kiriman
/// pelanggan). Foto tampil langsung, video dibuka di layar Reels,
/// tombol + di tengah untuk menambah foto/video — gaya wca_app.
class _KomunitasTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 2),
          child: Text('Komunitas',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Bagikan momen cucianmu — ketuk + untuk menambah foto '
            'atau video.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: !store.online
              ? const EmptyState(
                  icon: Icons.groups_outlined,
                  message: 'Komunitas membutuhkan koneksi ke server.')
              : RefreshIndicator(
                  onRefresh: () async => store.refresh(),
                  child: store.posts.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 100),
                            EmptyState(
                                icon: Icons.groups_outlined,
                                message:
                                    'Belum ada postingan. Jadilah yang '
                                    'pertama — ketuk tombol +!'),
                          ],
                        )
                      : ListView.builder(
                          padding:
                              const EdgeInsets.fromLTRB(16, 4, 16, 80),
                          itemCount: store.posts.length + 1,
                          itemBuilder: (context, i) => i == 0
                              ? const ReelsStrip()
                              : PromoCard(post: store.posts[i - 1]),
                        ),
                ),
        ),
      ],
    );
  }
}

/// Riwayat pesanan selesai — dipindah dari bilah navigasi ke menu
/// pengaturan di Profil.
class RiwayatScreen extends StatelessWidget {
  const RiwayatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Pesanan')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) => _OrdersTab(history: true),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Profil

class _ProfileTab extends StatefulWidget {
  const _ProfileTab();

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  Future<void> _confirmLogout(BuildContext context) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar?'),
        content: const Text('Anda akan keluar dari akun pelanggan. '
            'Riwayat pesanan tetap tersimpan di perangkat ini.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (yes == true) await store.setRole(null);
  }

  /// Lembar ubah profil. Mode server: no. HP terkunci karena menjadi
  /// identitas akun di server.
  Future<void> _editProfile(BuildContext context) async {
    final name = TextEditingController(text: store.profile.name);
    final phone = TextEditingController(text: store.profile.phone);
    final address = TextEditingController(text: store.profile.address);
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheet) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, 20 + MediaQuery.of(sheet).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Ubah Profil',
                textAlign: TextAlign.center,
                style: Theme.of(sheet)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 18),
            TextField(
              controller: name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                  labelText: 'Nama',
                  prefixIcon: Icon(Icons.person_outline)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              readOnly: store.online,
              decoration: InputDecoration(
                labelText: 'No. HP / WhatsApp',
                prefixIcon: const Icon(Icons.phone_outlined),
                helperText: store.online
                    ? 'Nomor terhubung ke akun dan tidak bisa diubah'
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: address,
              maxLines: 2,
              decoration: const InputDecoration(
                  labelText: 'Alamat',
                  prefixIcon: Icon(Icons.location_on_outlined)),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => Navigator.pop(sheet, true),
              icon: const Icon(Icons.save_outlined),
              label: const Text('Simpan'),
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      await store.saveProfile(
          name.text.trim(), phone.text.trim(), address.text.trim());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profil tersimpan')));
      }
    }
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    return parts.take(2).map((w) => w[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = store.profile;
    final orders = store.orders;
    final active = store.activeOrders.length;
    final spent =
        orders.fold<double>(0, (sum, o) => sum + o.total);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Profil Saya',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        // Kartu profil bergradasi gaya wca_app.
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF06B6D4), Color(0xFF0B4F6C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.white24,
                    child: Text(
                      _initials(p.name),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.name.isEmpty ? 'Pelanggan' : p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          p.phone.isEmpty
                              ? 'Nomor belum diisi'
                              : '+${waPhone(p.phone)}',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Pelanggan H2O',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Ubah Profil',
                    onPressed: () => _editProfile(context),
                    icon: const Icon(Icons.edit_outlined,
                        color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    _HeaderStat(label: 'Pesanan', value: '${orders.length}'),
                    _statDivider(),
                    _HeaderStat(label: 'Aktif', value: '$active'),
                    _statDivider(),
                    _HeaderStat(label: 'Total Belanja', value: rupiah(spent)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.history_outlined),
                title: const Text('Riwayat Pesanan'),
                subtitle: const Text('Pesanan yang sudah selesai'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const RiwayatScreen())),
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Ubah Profil'),
                subtitle: const Text('Nama, no. HP, dan alamat'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _editProfile(context),
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: Icon(Icons.logout, color: theme.colorScheme.error),
                title: Text('Keluar',
                    style: TextStyle(color: theme.colorScheme.error)),
                subtitle: const Text('Keluar dari akun di perangkat ini'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _confirmLogout(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text('H2O Laundry Parakan v1.0',
              style: theme.textTheme.bodySmall),
        ),
      ],
    );
  }

  Widget _statDivider() => Container(
        width: 1,
        height: 30,
        color: Colors.white24,
      );
}

/// Satu angka statistik di kartu profil (teks putih di atas gradasi).
class _HeaderStat extends StatelessWidget {
  const _HeaderStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
