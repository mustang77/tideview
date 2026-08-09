import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../widgets.dart';

/// Detail + pelacakan pesanan untuk pelanggan.
class OrderDetailScreen extends StatelessWidget {
  const OrderDetailScreen(
      {super.key, required this.order, this.justCreated = false});

  final Order order;
  final bool justCreated;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('Pesanan ${order.id}')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (justCreated)
                    Card(
                      color: theme.colorScheme.primaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle,
                                color: theme.colorScheme.primary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Pesanan berhasil dibuat! Kami akan segera '
                                'memproses pesanan Anda.',
                                style: TextStyle(
                                    color: theme
                                        .colorScheme.onPrimaryContainer),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (justCreated) const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          order.serviceName,
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      StatusChip(order: order),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const SectionTitle('Status Pesanan'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: OrderTimeline(order: order),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const SectionTitle('Rincian Biaya'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          DetailRow(
                            '${order.serviceName} '
                            '(${qtyText(order.qty, order.unit)} × ${rupiah(order.pricePerUnit)})',
                            rupiah(order.subtotal),
                          ),
                          DetailRow(
                              'Antar jemput',
                              order.antarJemput
                                  ? rupiah(order.deliveryFee)
                                  : '-'),
                          const Divider(),
                          DetailRow('Total', rupiah(order.total), bold: true),
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              order.paid
                                  ? '✓ Sudah dibayar'
                                  : 'Bayar tunai/transfer saat cucian diterima',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: order.paid
                                    ? const Color(0xFF16A34A)
                                    : null,
                                fontWeight:
                                    order.paid ? FontWeight.w700 : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const SectionTitle('Info Penjemputan'),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.event),
                          title: Text(dateTimeText(order.scheduledAt)),
                          subtitle: Text(order.antarJemput
                              ? 'Jadwal penjemputan'
                              : 'Jadwal antar sendiri'),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.location_on_outlined),
                          title: Text(order.address),
                          subtitle: Text(
                              '${order.customerName} • ${order.phone}'),
                        ),
                        if (order.notes.isNotEmpty) ...[
                          const Divider(height: 1),
                          ListTile(
                            leading:
                                const Icon(Icons.sticky_note_2_outlined),
                            title: Text(order.notes),
                            subtitle: const Text('Catatan'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
