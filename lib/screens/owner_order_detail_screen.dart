import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../widgets.dart';

/// Detail pesanan untuk pemilik: perbarui status, timbang ulang,
/// tandai lunas, atau hapus pesanan.
class OwnerOrderDetailScreen extends StatelessWidget {
  const OwnerOrderDetailScreen({super.key, required this.order});

  final Order order;

  Future<void> _editQty(BuildContext context) async {
    final controller = TextEditingController(
        text: order.qty == order.qty.roundToDouble()
            ? order.qty.toInt().toString()
            : order.qty.toString());
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Timbang Ulang'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Berat/jumlah aktual',
            suffixText: order.unit,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(
                context, double.tryParse(controller.text.replaceAll(',', '.'))),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (result != null && result > 0) {
      await store.updateQty(order, result);
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus pesanan?'),
        content: Text('Pesanan ${order.id} milik ${order.customerName} '
            'akan dihapus permanen.'),
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
    if (yes == true) {
      await store.deleteOrder(order);
      if (context.mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Pesanan ${order.id}'),
        actions: [
          IconButton(
            tooltip: 'Hapus pesanan',
            onPressed: () => _confirmDelete(context),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) {
            final next = order.status.index < OrderStatus.values.length - 1
                ? OrderStatus.values[order.status.index + 1]
                : null;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            order.customerName,
                            style: theme.textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        StatusChip(order: order),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.phone_outlined),
                            title: Text(order.phone),
                            subtitle: const Text('No. HP / WhatsApp'),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading:
                                const Icon(Icons.location_on_outlined),
                            title: Text(order.address),
                            subtitle: const Text('Alamat'),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.event),
                            title: Text(dateTimeText(order.scheduledAt)),
                            subtitle: Text(order.antarJemput
                                ? 'Jadwal penjemputan (antar jemput)'
                                : 'Pelanggan antar/ambil sendiri'),
                          ),
                          if (order.notes.isNotEmpty) ...[
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(
                                  Icons.sticky_note_2_outlined),
                              title: Text(order.notes),
                              subtitle: const Text('Catatan pelanggan'),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SectionTitle(
                      'Rincian',
                      trailing: TextButton.icon(
                        onPressed: () => _editQty(context),
                        icon: const Icon(Icons.scale, size: 18),
                        label: const Text('Timbang Ulang'),
                      ),
                    ),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            DetailRow('Layanan', order.serviceName),
                            DetailRow('Berat/Jumlah',
                                qtyText(order.qty, order.unit)),
                            DetailRow('Harga satuan',
                                '${rupiah(order.pricePerUnit)}/${order.unit}'),
                            DetailRow('Subtotal', rupiah(order.subtotal)),
                            DetailRow(
                                'Antar jemput',
                                order.antarJemput
                                    ? rupiah(order.deliveryFee)
                                    : '-'),
                            const Divider(),
                            DetailRow('Total', rupiah(order.total),
                                bold: true),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: SwitchListTile(
                        value: order.paid,
                        onChanged: (v) => store.setPaid(order, v),
                        secondary: Icon(
                          order.paid
                              ? Icons.check_circle
                              : Icons.payments_outlined,
                          color: order.paid
                              ? const Color(0xFF16A34A)
                              : null,
                        ),
                        title: Text(order.paid
                            ? 'Sudah Dibayar (Lunas)'
                            : 'Belum Dibayar'),
                        subtitle: const Text('Tandai status pembayaran'),
                      ),
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
                    if (next != null)
                      FilledButton.icon(
                        onPressed: () => store.advanceStatus(order),
                        icon: const Icon(Icons.arrow_forward),
                        label: Text(
                            'Tandai: ${statusLabel(next, antarJemput: order.antarJemput)}'),
                        style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                vertical: 16)),
                      )
                    else
                      Card(
                        color: const Color(0xFFDCFCE7),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              const Icon(Icons.task_alt,
                                  color: Color(0xFF16A34A)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  order.paid
                                      ? 'Pesanan selesai dan sudah lunas.'
                                      : 'Pesanan selesai. Jangan lupa tandai '
                                          'pembayaran jika sudah diterima.',
                                  style: const TextStyle(
                                      color: Color(0xFF14532D)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
