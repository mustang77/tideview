import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../widgets.dart';
import 'order_detail_screen.dart';

/// Pilihan jenis cucian yang dideklarasikan pelanggan.
const laundryContents = [
  'Kaos',
  'Kemeja',
  'Celana',
  'Rok / Dress',
  'Jilbab',
  'Pakaian Dalam',
  'Handuk',
  'Sprei',
  'Jaket / Sweater',
  'Kaos Kaki',
  'Lainnya',
];

class NewOrderScreen extends StatefulWidget {
  const NewOrderScreen({super.key, this.initialService});

  final ServiceType? initialService;

  @override
  State<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends State<NewOrderScreen> {
  /// Berat minimal untuk item kiloan.
  static const double minKg = 3;

  /// Jumlah per item katalog (0 = tidak dipesan).
  final Map<String, double> _qty = {};

  final Set<String> _contents = {};
  bool _agree = false;

  late DateTime _date = DateTime.now();
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);

  late final _name = TextEditingController(text: store.profile.name);
  late final _phone = TextEditingController(text: store.profile.phone);
  final _notes = TextEditingController();

  @override
  void initState() {
    super.initState();
    final init = widget.initialService;
    if (init != null) _qty[init.id] = init.perKg ? minKg : 1;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _notes.dispose();
    super.dispose();
  }

  double _minOf(ServiceType s) => s.perKg ? minKg : 1;
  double _stepOf(ServiceType s) => s.perKg ? 0.1 : 1;

  double _round1(double v) => (v * 10).roundToDouble() / 10;

  void _change(ServiceType s, double delta) {
    setState(() {
      final current = _qty[s.id] ?? 0;
      if (current == 0 && delta > 0) {
        // Mulai langsung dari batas minimal (3 kg untuk kiloan).
        _qty[s.id] = _minOf(s);
        return;
      }
      final next = _round1(current + delta);
      if (next < _minOf(s)) {
        _qty.remove(s.id);
      } else {
        _qty[s.id] = next;
      }
    });
  }

  Future<void> _typeQty(ServiceType s) async {
    final current = _qty[s.id] ?? _minOf(s);
    final controller = TextEditingController(
        text: current == current.roundToDouble()
            ? current.toInt().toString()
            : current.toStringAsFixed(1));
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.name),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: s.perKg ? 'Perkiraan berat' : 'Jumlah',
            suffixText: s.unit,
            helperText: s.perKg ? 'Minimal $minKg kg' : null,
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
    if (result == null) return;
    setState(() {
      if (result < _minOf(s)) {
        _qty.remove(s.id);
        if (result > 0) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(s.perKg
                  ? 'Minimal ${qtyText(minKg, 'kg')} untuk item kiloan.'
                  : 'Jumlah tidak valid.')));
        }
      } else {
        _qty[s.id] = _round1(result);
      }
    });
  }

  List<OrderItem> get _items => [
        for (final s in store.services)
          if ((_qty[s.id] ?? 0) > 0)
            OrderItem(
              serviceId: s.id,
              name: s.name,
              unit: s.unit,
              price: s.price,
              qty: _qty[s.id]!,
            ),
      ];

  double get _total =>
      _items.fold(0, (sum, item) => sum + item.subtotal);

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: now,
      lastDate: now.add(const Duration(days: 14)),
      helpText: 'Kapan Anda datang ke laundry?',
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      helpText: 'Jam kedatangan',
    );
    if (picked != null) setState(() => _time = picked);
  }

  void _submit() {
    final name = _name.text.trim();
    final phone = _phone.text.trim();
    final items = _items;
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Pilih minimal satu item dulu ya.')));
      return;
    }
    if (_contents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Pilih isi cucian Anda dulu ya (bagian Isi Cucian).')));
      return;
    }
    if (!_agree) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Centang pernyataan isi cucian dulu sebelum memesan.')));
      return;
    }
    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Lengkapi nama dan no. HP dulu ya.')));
      return;
    }
    store.saveProfile(name, phone, store.profile.address);
    final order = store.createOrder(
      items: items,
      contents: _contents.toList(),
      name: name,
      phone: phone,
      scheduledAt: DateTime(
          _date.year, _date.month, _date.day, _time.hour, _time.minute),
      notes: _notes.text.trim(),
    );
    Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => OrderDetailScreen(order: order, justCreated: true)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = _items;
    return Scaffold(
      appBar: AppBar(title: const Text('Buat Pesanan')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                const SectionTitle('Pilih Item'),
                Card(
                  child: Column(
                    children: [
                      for (var i = 0; i < store.services.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        _ItemRow(
                          service: store.services[i],
                          qty: _qty[store.services[i].id] ?? 0,
                          onAdd: () => _change(
                              store.services[i], _stepOf(store.services[i])),
                          onRemove: () => _change(
                              store.services[i], -_stepOf(store.services[i])),
                          onTypeQty: () => _typeQty(store.services[i]),
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: Text(
                    'Item kiloan minimal ${qtyText(minKg, 'kg')} dan bersifat '
                    'perkiraan — berat final ditimbang di counter. '
                    'Ketuk angka untuk mengetik berat.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 16),
                const SectionTitle('Isi Cucian'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pilih jenis pakaian yang Anda cuci. Sebutkan '
                          'jumlah/detail tambahan di kolom catatan.',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final c in laundryContents)
                              FilterChip(
                                label: Text(c),
                                selected: _contents.contains(c),
                                onSelected: (v) => setState(() {
                                  if (v) {
                                    _contents.add(c);
                                  } else {
                                    _contents.remove(c);
                                  }
                                }),
                              ),
                          ],
                        ),
                        const Divider(height: 24),
                        CheckboxListTile(
                          value: _agree,
                          onChanged: (v) =>
                              setState(() => _agree = v ?? false),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Saya memastikan daftar isi cucian di atas sudah '
                            'benar. Barang yang tidak dicantumkan menjadi '
                            'tanggung jawab saya bila hilang.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const SectionTitle('Rencana Datang ke Laundry'),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.event),
                        title: Text(shortDate(_date)),
                        subtitle: const Text('Tanggal'),
                        trailing: const Icon(Icons.edit_outlined, size: 20),
                        onTap: _pickDate,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.schedule),
                        title: Text(_time.format(context)),
                        subtitle: const Text('Jam'),
                        trailing: const Icon(Icons.edit_outlined, size: 20),
                        onTap: _pickTime,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const SectionTitle('Data Pemesan'),
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                      labelText: 'Nama',
                      prefixIcon: Icon(Icons.person_outline)),
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
                  controller: _notes,
                  maxLines: 2,
                  decoration: const InputDecoration(
                      labelText: 'Catatan (opsional)',
                      hintText: 'Contoh: 5 kemeja, 3 celana; pisahkan putih',
                      prefixIcon: Icon(Icons.sticky_note_2_outlined)),
                ),
                if (items.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const SectionTitle('Ringkasan'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          for (final item in items)
                            DetailRow(
                              '${item.name} (${qtyText(item.qty, item.unit)} × ${rupiah(item.price)})',
                              rupiah(item.subtotal),
                            ),
                          const Divider(),
                          DetailRow('Total Estimasi', rupiah(_total),
                              bold: true),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 90),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: theme.dividerColor)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Estimasi', style: theme.textTheme.bodySmall),
                    Text(
                      rupiah(_total),
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.primary),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.check),
                label: const Text('Buat Pesanan'),
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.service,
    required this.qty,
    required this.onAdd,
    required this.onRemove,
    required this.onTypeQty,
  });

  final ServiceType service;
  final double qty;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final VoidCallback onTypeQty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = qty > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              serviceIcon(service.id),
              size: 22,
              color: selected
                  ? Colors.white
                  : theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(service.name,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(
                  '${rupiah(service.price)}/${service.unit}'
                  '${service.perKg ? ' • min 3 kg' : ''}'
                  ' • ${service.estimasiHari} hari',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (selected) ...[
            IconButton.filledTonal(
              tooltip: 'Kurangi ${service.name}',
              visualDensity: VisualDensity.compact,
              onPressed: onRemove,
              icon: const Icon(Icons.remove, size: 18),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onTypeQty,
              child: Container(
                width: 60,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  qtyText(qty, service.unit),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                    decorationStyle: TextDecorationStyle.dotted,
                    decorationColor: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
          ],
          IconButton.filled(
            tooltip: 'Tambah ${service.name}',
            visualDensity: VisualDensity.compact,
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 18),
          ),
        ],
      ),
    );
  }
}
