import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:url_launcher/url_launcher.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../widgets.dart';
import 'admin_screen.dart';
import 'owner_order_detail_screen.dart';
import 'promo.dart';

class OwnerShell extends StatefulWidget {
  const OwnerShell({super.key});

  @override
  State<OwnerShell> createState() => _OwnerShellState();
}

class _OwnerShellState extends State<OwnerShell> {
  int _index = 0;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    store.refresh();
    _poll = Timer.periodic(
        const Duration(seconds: 20), (_) => store.refresh());
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
                0 => const _DashboardTab(),
                1 => const _OwnerOrdersTab(),
                2 => const _CustomersTab(),
                3 => const _ReportTab(),
                _ => const _PricingTab(),
              },
            ),
          ),
        ),
        bottomNavigationBar: BottomAppBar(
          color: Colors.white,
          elevation: 12,
          height: 62,
          padding: EdgeInsets.zero,
          child: Row(
            children: [
              NavIcon(
                  icon: Icons.dashboard_outlined,
                  activeIcon: Icons.dashboard,
                  label: 'Dashboard',
                  selected: _index == 0,
                  onTap: () => setState(() => _index = 0)),
              NavIcon(
                  icon: Icons.receipt_long_outlined,
                  activeIcon: Icons.receipt_long,
                  label: 'Pesanan',
                  selected: _index == 1,
                  onTap: () => setState(() => _index = 1)),
              NavIcon(
                  icon: Icons.people_outline,
                  activeIcon: Icons.people,
                  label: 'Pelanggan',
                  selected: _index == 2,
                  onTap: () => setState(() => _index = 2)),
              NavIcon(
                  icon: Icons.bar_chart_outlined,
                  activeIcon: Icons.bar_chart,
                  label: 'Laporan',
                  selected: _index == 3,
                  onTap: () => setState(() => _index = 3)),
              NavIcon(
                  icon: Icons.sell_outlined,
                  activeIcon: Icons.sell,
                  label: 'Harga',
                  selected: _index == 4,
                  onTap: () => setState(() => _index = 4)),
            ],
          ),
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
            o.status == OrderStatus.diterima ||
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
            const Expanded(child: BrandHeader()),
            IconButton.filledTonal(
              tooltip: 'Kelola Admin',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const AdminScreen())),
              icon: const Icon(Icons.manage_accounts_outlined),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: 'Keluar Mode Pemilik',
              onPressed: () => store.setRole(null),
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          '${store.currentAdmin?.name ?? 'Pemilik'} • ${fullDate(now)}',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        const ServerOfflineBanner(),
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
                label: 'Siap Diambil',
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
        const SizedBox(height: 20),
        Row(
          children: [
            const Expanded(child: SectionTitle('Info & Promo')),
            FilledButton.tonalIcon(
              onPressed: store.online
                  ? () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const PromoComposeScreen()))
                  : null,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Buat Promo'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (!store.online)
          const EmptyState(
              icon: Icons.campaign_outlined,
              message: 'Fitur promo membutuhkan server (atur di '
                  'Kelola Admin > Server).')
        else if (store.posts.isEmpty)
          const EmptyState(
              icon: Icons.campaign_outlined,
              message: 'Belum ada promo. Buat promo pertama untuk '
                  'pelanggan Anda!')
        else
          for (final p in store.posts) PromoCard(post: p, isOwner: true),
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
                    label: Text(statusLabel(s)),
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

// -------------------------------------------------------------- Item & Harga

class _PricingTab extends StatelessWidget {
  const _PricingTab();

  /// Dialog tambah/ubah item. [service] null berarti membuat item baru.
  Future<void> _editService(BuildContext context,
      {ServiceType? service}) async {
    final name = TextEditingController(text: service?.name ?? '');
    final price = TextEditingController(
        text: service == null ? '' : service.price.round().toString());
    final hari = TextEditingController(
        text: (service?.estimasiHari ?? 2).toString());
    final desc = TextEditingController(text: service?.description ?? '');
    var unit = service?.unit ?? 'pcs';

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(service == null ? 'Tambah Item' : 'Ubah Item'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  autofocus: service == null,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                      labelText: 'Nama item',
                      hintText: 'Contoh: Jaket, Gorden, Boneka'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: price,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Harga', prefixText: 'Rp '),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: unit,
                  decoration: const InputDecoration(labelText: 'Satuan'),
                  items: const [
                    DropdownMenuItem(value: 'pcs', child: Text('per pcs')),
                    DropdownMenuItem(value: 'kg', child: Text('per kg')),
                    DropdownMenuItem(
                        value: 'pasang', child: Text('per pasang')),
                  ],
                  onChanged: (v) => setState(() => unit = v ?? 'pcs'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: hari,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Estimasi pengerjaan (hari)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: desc,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                      labelText: 'Deskripsi (opsional)',
                      hintText: 'Tampil saat pelanggan memesan'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Batal')),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;
    final nm = name.text.trim();
    final pr = double.tryParse(
        price.text.replaceAll('.', '').replaceAll(',', ''));
    final hr = int.tryParse(hari.text) ?? 2;
    if (nm.isEmpty || pr == null || pr <= 0) return;
    if (service == null) {
      await store.addService(
          name: nm,
          unit: unit,
          price: pr,
          estimasiHari: hr,
          description: desc.text.trim());
    } else {
      await store.updateService(service,
          name: nm,
          unit: unit,
          price: pr,
          estimasiHari: hr,
          description: desc.text.trim());
    }
  }

  Future<void> _confirmDelete(BuildContext context, ServiceType s) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus item?'),
        content: Text('"${s.name}" akan dihapus dari daftar. '
            'Pesanan lama tidak berubah.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (yes == true) await store.deleteService(s);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Item & Harga',
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  Text('Ketuk item untuk mengubah, atau tambah item baru.',
                      style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: () => _editService(context),
              icon: const Icon(Icons.add),
              label: const Text('Tambah'),
            ),
          ],
        ),
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
                  IconButton(
                    tooltip: 'Hapus ${s.name}',
                    onPressed: () => _confirmDelete(context, s),
                    icon: const Icon(Icons.delete_outline, size: 20),
                  ),
                ],
              ),
              onTap: () => _editService(context, service: s),
            ),
          ),
      ],
    );
  }
}

// -------------------------------------------------------------- Pelanggan

class _CustomersTab extends StatelessWidget {
  const _CustomersTab();

  Future<void> _broadcast(BuildContext context) async {
    final customers = store.customers;
    final message = TextEditingController(
        text: 'Halo pelanggan setia H2O Laundry Parakan! ');
    final sent = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Broadcast WhatsApp'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: message,
              autofocus: true,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Isi pesan',
                hintText: 'Contoh: promo cuci 5 kg gratis 1 kg minggu ini!',
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'WhatsApp akan terbuka dengan pesan ini — pilih penerima '
                'atau daftar broadcast Anda di sana.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final numbers =
                  customers.map((c) => waPhone(c.phone)).join(', ');
              await Clipboard.setData(ClipboardData(text: numbers));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(
                        '${customers.length} nomor pelanggan disalin')));
              }
            },
            child: const Text('Salin Nomor'),
          ),
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal')),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, message.text.trim()),
            icon: const Icon(Icons.send, size: 18),
            label: const Text('Buka WhatsApp'),
          ),
        ],
      ),
    );
    if (sent == null || sent.isEmpty) return;
    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(sent)}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _chat(CustomerSummary c) async {
    final text = Uri.encodeComponent('Halo ${c.name}, ini H2O Laundry Parakan. ');
    final uri = Uri.parse('https://wa.me/${waPhone(c.phone)}?text=$text');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customers = store.customers;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pelanggan',
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  Text('${customers.length} pelanggan dari riwayat pesanan',
                      style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed:
                  customers.isEmpty ? null : () => _broadcast(context),
              icon: const Icon(Icons.campaign_outlined),
              label: const Text('Broadcast'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (customers.isEmpty)
          const EmptyState(
              icon: Icons.people_outline,
              message: 'Belum ada pelanggan.\nPelanggan muncul otomatis '
                  'dari pesanan yang masuk.')
        else
          for (final c in customers)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(21),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    c.name.isEmpty ? '?' : c.name[0].toUpperCase(),
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onPrimaryContainer),
                  ),
                ),
                title: Text(c.name,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                  '${c.phone}\n${c.orderCount} pesanan • ${rupiah(c.totalSpent)}'
                  ' • terakhir ${shortDate(c.lastOrderAt)}',
                  style: theme.textTheme.bodySmall,
                ),
                isThreeLine: true,
                trailing: IconButton.filledTonal(
                  tooltip: 'Chat WhatsApp ${c.name}',
                  onPressed: () => _chat(c),
                  icon: const Icon(Icons.chat_outlined, size: 20),
                ),
              ),
            ),
      ],
    );
  }
}
