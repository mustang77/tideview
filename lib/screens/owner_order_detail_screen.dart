import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../receipt.dart';
import '../receipt_bt.dart';
import '../store.dart';
import '../widgets.dart';

/// Detail pesanan untuk pemilik: perbarui status, timbang ulang per item,
/// tandai lunas, atau hapus pesanan.
class OwnerOrderDetailScreen extends StatelessWidget {
  const OwnerOrderDetailScreen({super.key, required this.order});

  final Order order;

  Future<void> _editItemQty(BuildContext context, OrderItem item) async {
    final controller = TextEditingController(
        text: item.qty == item.qty.roundToDouble()
            ? item.qty.toInt().toString()
            : item.qty.toString());
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.name),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Berat/jumlah aktual',
            suffixText: item.unit,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(context,
                double.tryParse(controller.text.replaceAll(',', '.'))),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (result != null && result > 0) {
      await store.updateItemQty(order, item, result);
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
          // Pilih lebar kertas struk (58/80 mm) — disimpan per perangkat.
          PopupMenuButton<int>(
            tooltip: 'Lebar kertas struk',
            icon: const Icon(Icons.receipt_long_outlined),
            initialValue: store.receiptWidth,
            onSelected: (v) async {
              await store.setReceiptWidth(v);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Struk memakai kertas $v mm')));
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                  value: 58, child: Text('Kertas 58 mm (umum)')),
              PopupMenuItem(value: 80, child: Text('Kertas 80 mm')),
            ],
          ),
          IconButton(
            tooltip: 'Cetak Struk',
            onPressed: () => showPrintSheet(context, order),
            icon: const Icon(Icons.print_outlined),
          ),
          IconButton(
            tooltip: 'Bagikan Struk (PDF)',
            onPressed: () => shareReceipt(order),
            icon: const Icon(Icons.share_outlined),
          ),
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
                            leading: const Icon(Icons.event),
                            title: Text(dateTimeText(order.scheduledAt)),
                            subtitle:
                                const Text('Rencana datang ke counter'),
                          ),
                          if (order.contents.isNotEmpty) ...[
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.checkroom),
                              title: Text(order.contents.join(', ')),
                              subtitle: const Text(
                                  'Isi cucian (deklarasi pelanggan)'),
                            ),
                          ],
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
                    const SectionTitle('Item Pesanan'),
                    Card(
                      child: Column(
                        children: [
                          for (var i = 0; i < order.items.length; i++) ...[
                            if (i > 0) const Divider(height: 1),
                            ListTile(
                              leading: Icon(
                                  serviceIcon(order.items[i].serviceId)),
                              title: Text(order.items[i].name),
                              subtitle: Text(
                                '${qtyText(order.items[i].qty, order.items[i].unit)}'
                                ' × ${rupiah(order.items[i].price)}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    rupiah(order.items[i].subtotal),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.scale, size: 18),
                                ],
                              ),
                              onTap: () =>
                                  _editItemQty(context, order.items[i]),
                            ),
                          ],
                          const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: DetailRow('Total', rupiah(order.total),
                                bold: true),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 4),
                      child: Text(
                        'Ketuk item untuk memperbarui berat/jumlah '
                        'setelah ditimbang.',
                        style: theme.textTheme.bodySmall,
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
                        label: Text('Tandai: ${statusLabel(next)}'),
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
