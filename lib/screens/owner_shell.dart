import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../widgets.dart';
import 'owner_order_detail_screen.dart';

class OwnerShell extends StatefulWidget {
  const OwnerShell({super.key});

  @override
  State<OwnerShell> createState() => _OwnerShellState();
}

class _OwnerShellState extends State<OwnerShell> {
  int _index = 0;

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
                0 => const _DashboardTab(),
                1 => const _OwnerOrdersTab(),
                2 => const _ReportTab(),
                _ => const _PricingTab(),
              },
            ),
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: 'Dashboard'),
            NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long),
                label: 'Pesanan'),
            NavigationDestination(
                icon: Icon(Icons.bar_chart_outlined),
                selectedIcon: Icon(Icons.bar_chart),
                label: 'Laporan'),
            NavigationDestination(
                icon: Icon(Icons.sell_outlined),
                selectedIcon: Icon(Icons.sell),
                label: 'Harga'),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------- Dashboard

class _DashboardTab extends StatelessWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final baru = store.orders
        .where((o) => o.status == OrderStatus.menunggu)
        .length;
    final proses = store.orders
        .where((o) =>
            o.status == OrderStatus.dijemput ||
            o.status == OrderStatus.diproses)
        .length;
    final siap =
        store.orders.where((o) => o.status == OrderStatus.siap).length;
    final active = store.activeOrders
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Dashboard',
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  Text(fullDate(now), style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            IconButton.filledTonal(
              tooltip: 'Ganti Mode',
              onPressed: () => store.setRole(null),
              icon: const Icon(Icons.swap_horiz),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: MediaQuery.sizeOf(context).width > 560 ? 4 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            StatTile(
                label: 'Pesanan Baru',
                value: '$baru',
                icon: Icons.fiber_new,
                color: statusColor(OrderStatus.menunggu)),
            StatTile(
                label: 'Sedang Diproses',
                value: '$proses',
                icon: Icons.local_laundry_service,
                color: statusColor(OrderStatus.diproses)),
            StatTile(
                label: 'Siap Diantar',
                value: '$siap',
                icon: Icons.inventory_2,
                color: statusColor(OrderStatus.siap)),
            StatTile(
                label: 'Pendapatan Hari Ini',
                value: rupiah(store.incomeOn(now)),
                icon: Icons.payments,
                color: const Color(0xFF16A34A)),
          ],
        ),
        const SizedBox(height: 20),
        SectionTitle('Perlu Ditindak (${active.length})'),
        if (active.isEmpty)
          const EmptyState(
              icon: Icons.task_alt,
              message: 'Semua pesanan sudah selesai. Mantap! 🎉')
        else
          for (final o in active)
            OrderCard(
              order: o,
              showCustomer: true,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => OwnerOrderDetailScreen(order: o))),
            ),
      ],
    );
  }
}

// -------------------------------------------------------------- Pesanan

class _OwnerOrdersTab extends StatefulWidget {
  const _OwnerOrdersTab();

  @override
  State<_OwnerOrdersTab> createState() => _OwnerOrdersTabState();
}

class _OwnerOrdersTabState extends State<_OwnerOrdersTab> {
  OrderStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final orders = store.orders
        .where((o) => _filter == null || o.status == _filter)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text('Semua Pesanan',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: const Text('Semua'),
                  selected: _filter == null,
                  onSelected: (_) => setState(() => _filter = null),
                ),
              ),
              for (final s in OrderStatus.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(statusLabel(s, antarJemput: true)),
                    selected: _filter == s,
                    onSelected: (_) => setState(
                        () => _filter = _filter == s ? null : s),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: orders.isEmpty
              ? const EmptyState(
                  icon: Icons.receipt_long_outlined,
                  message: 'Tidak ada pesanan dengan status ini.')
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: orders.length,
                  itemBuilder: (context, i) => OrderCard(
                    order: orders[i],
                    showCustomer: true,
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => OwnerOrderDetailScreen(
                                order: orders[i]))),
                  ),
                ),
        ),
      ],
    );
  }
}

// -------------------------------------------------------------- Laporan

class _ReportTab extends StatelessWidget {
  const _ReportTab();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final days = [
      for (var i = 6; i >= 0; i--) now.subtract(Duration(days: i))
    ];
    final incomes = [for (final d in days) store.incomeOn(d)];
    final maxIncome =
        incomes.fold<double>(0, (m, v) => v > m ? v : m);
    final weekTotal = incomes.fold<double>(0, (a, b) => a + b);
    final monthTotal = store.incomeInMonth(now);
    final selesaiCount = store.orders.where((o) => o.selesai).length;
    final belumBayar = store.orders.where((o) => !o.paid).length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Laporan',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: MediaQuery.sizeOf(context).width > 560 ? 4 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            StatTile(
                label: 'Pendapatan Bulan ${monthName(now)}',
                value: rupiah(monthTotal),
                icon: Icons.calendar_month,
                color: theme.colorScheme.primary),
            StatTile(
                label: 'Pendapatan 7 Hari',
                value: rupiah(weekTotal),
                icon: Icons.date_range,
                color: const Color(0xFF16A34A)),
            StatTile(
                label: 'Pesanan Selesai',
                value: '$selesaiCount',
                icon: Icons.task_alt,
                color: const Color(0xFF0D9488)),
            StatTile(
                label: 'Belum Dibayar',
                value: '$belumBayar',
                icon: Icons.hourglass_bottom,
                color: const Color(0xFFD97706)),
          ],
        ),
        const SizedBox(height: 20),
        const SectionTitle('Pendapatan 7 Hari Terakhir'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                for (var i = 0; i < days.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 78,
                          child: Text(
                            sameDay(days[i], now)
                                ? 'Hari ini'
                                : '${dayName(days[i]).substring(0, 3)}, ${days[i].day} ${monthShort(days[i])}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: maxIncome == 0
                                  ? 0
                                  : incomes[i] / maxIncome,
                              minHeight: 10,
                              color: theme.colorScheme.primary,
                              backgroundColor: theme.colorScheme.surfaceContainerHighest,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 86,
                          child: Text(
                            rupiah(incomes[i]),
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Pendapatan dihitung dari pesanan yang sudah selesai dan lunas.',
          style: theme.textTheme.bodySmall?.copyWith(
              color: theme.disabledColor),
        ),
      ],
    );
  }
}

// -------------------------------------------------------------- Harga

class _PricingTab extends StatelessWidget {
  const _PricingTab();

  Future<void> _editPrice(BuildContext context, ServiceType s) async {
    final controller =
        TextEditingController(text: s.price.round().toString());
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.name),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Harga per ${s.unit}',
            prefixText: 'Rp ',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(
                  controller.text.replaceAll('.', '').replaceAll(',', ''));
              Navigator.pop(context, v);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (result != null && result > 0) {
      await store.updateServicePrice(s, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Daftar Harga',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Ketuk layanan untuk mengubah harga.',
            style: theme.textTheme.bodySmall),
        const SizedBox(height: 16),
        for (final s in store.services)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(serviceIcon(s.id),
                    color: theme.colorScheme.onPrimaryContainer),
              ),
              title: Text(s.name,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('Estimasi ${s.estimasiHari} hari'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${rupiah(s.price)}/${s.unit}',
                    style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.edit_outlined, size: 18),
                ],
              ),
              onTap: () => _editPrice(context, s),
            ),
          ),
      ],
    );
  }
}
