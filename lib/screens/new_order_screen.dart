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
  const NewOrderScreen(
      {super.key, this.initialService, this.delivery = false});

  final ServiceType? initialService;

  /// Buka langsung dengan Antar-Jemput terpilih (dari kartu di beranda).
  final bool delivery;

  @override
  State<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends State<NewOrderScreen> {
  /// Berat minimal untuk item kiloan.
  static const double minKg = 3;

  /// Jumlah per item katalog (0 = tidak dipesan).
  final Map<String, double> _qty = {};

  /// Jumlah per jenis cucian yang dideklarasikan (0 = tidak dipilih).
  final Map<String, int> _contents = {};
  bool _agree = false;

  late DateTime _date = DateTime.now();
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);

  /// Antar-jemput (kurir) atau datang sendiri ke counter.
  late bool _delivery = widget.delivery;

  late final _name = TextEditingController(text: store.profile.name);
  late final _phone = TextEditingController(text: store.profile.phone);
  late final _address = TextEditingController(text: store.profile.address);
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
    _address.dispose();
    _notes.dispose();
    super.dispose();
  }

  double get _kg => DeliveryRules.kgOf(_items);

  void _setDelivery(bool v) {
    setState(() {
      _delivery = v;
      // Jam jemput hanya slot per jam 09.00-15.00; jam counter bebas.
      if (v && !DeliveryRules.hourOk(_time.hour)) {
        _time = const TimeOfDay(hour: DeliveryRules.startHour, minute: 0);
      }
      if (v) _time = TimeOfDay(hour: _time.hour, minute: 0);
    });
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
              price: s.priceFor(_delivery),
              qty: _qty[s.id]!,
            ),
      ];

  double get _total =>
      _items.fold<double>(0, (sum, item) => sum + item.subtotal) +
      (_delivery ? store.deliveryFee : 0);

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: now,
      lastDate: now.add(const Duration(days: 14)),
      helpText: _delivery
          ? 'Tanggal kurir menjemput'
          : 'Kapan Anda datang ke laundry?',
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    if (_delivery) {
      // Slot per jam di jendela jemput.
      final picked = await showModalBottomSheet<int>(
        context: context,
        showDragHandle: true,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text('Jam jemput (${DeliveryRules.hoursText})',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final h in DeliveryRules.slots)
                    ChoiceChip(
                      label: Text('${h.toString().padLeft(2, '0')}.00'),
                      selected: _time.hour == h,
                      onSelected: (_) => Navigator.pop(ctx, h),
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      );
      if (picked != null) {
        setState(() => _time = TimeOfDay(hour: picked, minute: 0));
      }
      return;
    }
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      helpText: 'Jam kedatangan',
    );
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _submit() async {
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
    final address = _address.text.trim();
    if (_delivery) {
      final problem = DeliveryRules.problem(
          items: items, hour: _time.hour, address: address);
      if (problem != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(problem)));
        return;
      }
    }
    await store.saveProfile(
        name, phone, _delivery ? address : store.profile.address);
    final order = await store.createOrder(
      items: items,
      contents: [
        for (final e in _contents.entries)
          if (e.value > 0) '${e.key} ×${e.value}',
      ],
      name: name,
      phone: phone,
      scheduledAt: DateTime(
          _date.year, _date.month, _date.day, _time.hour, _time.minute),
      notes: _notes.text.trim(),
      delivery: _delivery,
      address: _delivery ? address : '',
    );
    if (!mounted) return;
    if (order == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Tidak bisa terhubung ke server. '
              'Periksa koneksi lalu coba lagi.')));
      return;
    }
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
                          delivery: _delivery,
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
                          'Pilih jenis pakaian dan jumlahnya. Detail '
                          'tambahan bisa ditulis di kolom catatan.',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final c in laundryContents)
                              _ContentCounter(
                                label: c,
                                count: _contents[c] ?? 0,
                                onAdd: () => setState(() => _contents[c] =
                                    (_contents[c] ?? 0) + 1),
                                onRemove: () => setState(() {
                                  final next = (_contents[c] ?? 0) - 1;
                                  if (next <= 0) {
                                    _contents.remove(c);
                                  } else {
                                    _contents[c] = next;
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
                const SectionTitle('Cara Pengantaran'),
                Card(
                  child: RadioGroup<bool>(
                    groupValue: _delivery,
                    onChanged: (v) => _setDelivery(v ?? false),
                    child: Column(
                      children: [
                        const RadioListTile<bool>(
                          value: false,
                          secondary: Icon(Icons.storefront),
                          title: Text('Antar sendiri ke counter',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                          subtitle:
                              Text('Bawa cucian ke H2O Laundry Parakan'),
                        ),
                        const Divider(height: 1),
                        RadioListTile<bool>(
                          value: true,
                          secondary: const Icon(Icons.delivery_dining),
                          title: const Text('Antar-Jemput ke rumah',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(
                              'Kurir menjemput & mengantar kembali. Jam '
                              'jemput ${DeliveryRules.hoursText}, minimal '
                              '${DeliveryRules.minKg.toInt()} kg cucian '
                              'kiloan. Ongkos '
                              '${store.deliveryFee > 0 ? rupiah(store.deliveryFee) : 'gratis'}.'),
                        ),
                        if (_delivery) ...[
                          const Divider(height: 1),
                          Padding(
                            padding:
                                const EdgeInsets.fromLTRB(16, 12, 16, 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextField(
                                  controller: _address,
                                  maxLines: 2,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  decoration: const InputDecoration(
                                    labelText: 'Alamat jemput & antar',
                                    hintText:
                                        'Jl. / dusun, RT/RW, patokan rumah',
                                    prefixIcon:
                                        Icon(Icons.location_on_outlined),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _KgMeter(kg: _kg),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SectionTitle(_delivery
                    ? 'Jadwal Jemput'
                    : 'Rencana Datang ke Laundry'),
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
                        title: Text(_delivery
                            ? '${_time.hour.toString().padLeft(2, '0')}.00'
                            : _time.format(context)),
                        subtitle: Text(_delivery
                            ? 'Jam jemput (${DeliveryRules.hoursText})'
                            : 'Jam'),
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
                          if (_delivery)
                            DetailRow(
                                'Ongkos antar-jemput',
                                store.deliveryFee > 0
                                    ? rupiah(store.deliveryFee)
                                    : 'Gratis'),
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

/// Indikator berat kiloan vs syarat minimal antar-jemput.
class _KgMeter extends StatelessWidget {
  const _KgMeter({required this.kg});
  final double kg;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ok = kg >= DeliveryRules.minKg;
    final color = ok ? const Color(0xFF16A34A) : theme.colorScheme.error;
    return Row(
      children: [
        Icon(ok ? Icons.check_circle : Icons.info_outline,
            size: 18, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            ok
                ? 'Cucian kiloan ${qtyText(kg, 'kg')} — memenuhi syarat '
                    'antar-jemput.'
                : 'Cucian kiloan baru ${qtyText(kg, 'kg')}; antar-jemput '
                    'minimal ${DeliveryRules.minKg.toInt()} kg. Tambah '
                    'berat di bagian Pilih Item.',
            style: theme.textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.service,
    required this.qty,
    required this.delivery,
    required this.onAdd,
    required this.onRemove,
    required this.onTypeQty,
  });

  final ServiceType service;
  final double qty;

  /// Mode antar-jemput: tampilkan harga antar-jemput layanan ini.
  final bool delivery;
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
                  '${rupiah(service.priceFor(delivery))}/${service.unit}'
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

/// Chip penghitung untuk deklarasi isi cucian: belum dipilih tampil
/// sebagai "Kaos +", setelah dipilih menjadi "− Kaos 3 +".
class _ContentCounter extends StatelessWidget {
  const _ContentCounter({
    required this.label,
    required this.count,
    required this.onAdd,
    required this.onRemove,
  });

  final String label;
  final int count;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = count > 0;
    return Container(
      decoration: BoxDecoration(
        color: selected
            ? theme.colorScheme.primaryContainer
            : Colors.transparent,
        border: Border.all(
          color: selected
              ? theme.colorScheme.primary
              : theme.dividerColor,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selected)
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onRemove,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
                child: Icon(Icons.remove,
                    size: 16, color: theme.colorScheme.primary),
              ),
            ),
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onAdd,
            child: Padding(
              padding: EdgeInsets.fromLTRB(selected ? 2 : 12, 8, 2, 8),
              child: Text(
                selected ? '$label $count' : label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onAdd,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 8, 10, 8),
              child: Icon(Icons.add,
                  size: 16,
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
