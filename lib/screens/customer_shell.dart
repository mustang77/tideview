import 'dart:async';

import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../widgets.dart';
import 'new_order_screen.dart';
import 'order_detail_screen.dart';
import 'owner_access.dart';

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
              child: switch (_index) {
                0 => const _HomeTab(),
                1 => const _OrdersTab(history: false),
                2 => const _OrdersTab(history: true),
                _ => const _ProfileTab(),
              },
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          tooltip: 'Buat Pesanan',
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const NewOrderScreen())),
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
              _NavIcon(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  label: 'Beranda',
                  selected: _index == 0,
                  onTap: () => setState(() => _index = 0)),
              _NavIcon(
                  icon: Icons.receipt_long_outlined,
                  activeIcon: Icons.receipt_long,
                  label: 'Pesanan',
                  selected: _index == 1,
                  onTap: () => setState(() => _index = 1)),
              const SizedBox(width: 72),
              _NavIcon(
                  icon: Icons.history_outlined,
                  activeIcon: Icons.history,
                  label: 'Riwayat',
                  selected: _index == 2,
                  onTap: () => setState(() => _index = 2)),
              _NavIcon(
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

/// Ikon navigasi bergaya garis tipis; berwarna saat aktif.
class _NavIcon extends StatelessWidget {
  const _NavIcon({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Tooltip(
          message: label,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(selected ? activeIcon : icon, size: 26, color: color),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
              ),
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
          child: Text(history ? 'Riwayat' : 'Pesanan Saya',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
        ),
        Expanded(
          child: orders.isEmpty
              ? EmptyState(
                  icon: history
                      ? Icons.history_outlined
                      : Icons.receipt_long_outlined,
                  message: history
                      ? 'Belum ada pesanan yang selesai.'
                      : 'Belum ada pesanan aktif.\nKetuk tombol + untuk memesan!',
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

// ---------------------------------------------------------------- Profil

class _ProfileTab extends StatefulWidget {
  const _ProfileTab();

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  late final _name = TextEditingController(text: store.profile.name);
  late final _phone = TextEditingController(text: store.profile.phone);
  late final _address = TextEditingController(text: store.profile.address);

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

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Profil Saya',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
              labelText: 'Nama', prefixIcon: Icon(Icons.person_outline)),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
              labelText: 'No. HP / WhatsApp',
              prefixIcon: Icon(Icons.phone_outlined)),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _address,
          maxLines: 2,
          decoration: const InputDecoration(
              labelText: 'Alamat',
              prefixIcon: Icon(Icons.location_on_outlined)),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () async {
            await store.saveProfile(
                _name.text.trim(), _phone.text.trim(), _address.text.trim());
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profil tersimpan')));
            }
          },
          icon: const Icon(Icons.save_outlined),
          label: const Text('Simpan Profil'),
        ),
        const SizedBox(height: 28),
        Card(
          child: ListTile(
            leading: Icon(Icons.logout,
                color: Theme.of(context).colorScheme.error),
            title: const Text('Keluar'),
            subtitle: const Text('Keluar dari akun di perangkat ini'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _confirmLogout(context),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text('H2O Laundry Parakan v1.0',
              style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }
}
