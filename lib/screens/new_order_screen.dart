import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../widgets.dart';
import 'order_detail_screen.dart';

class NewOrderScreen extends StatefulWidget {
  const NewOrderScreen({super.key, required this.initialService});

  final ServiceType initialService;

  @override
  State<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends State<NewOrderScreen> {
  late ServiceType _service = widget.initialService;
  double _qty = 1;
  bool _antarJemput = true;
  late DateTime _date = DateTime.now();
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);

  late final _name = TextEditingController(text: store.profile.name);
  late final _phone = TextEditingController(text: store.profile.phone);
  late final _address = TextEditingController(text: store.profile.address);
  final _notes = TextEditingController();

  double get _step => _service.perKg ? 0.5 : 1;
  double get _minQty => 1;
  double get _subtotal => _service.price * _qty;
  double get _ongkir => _antarJemput ? LaundryStore.biayaAntarJemput : 0;
  double get _total => _subtotal + _ongkir;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _changeService(ServiceType s) {
    setState(() {
      _service = s;
      _qty = _minQty;
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: now,
      lastDate: now.add(const Duration(days: 14)),
      helpText: 'Pilih tanggal penjemputan',
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      helpText: 'Pilih jam penjemputan',
    );
    if (picked != null) setState(() => _time = picked);
  }

  void _submit() {
    final name = _name.text.trim();
    final phone = _phone.text.trim();
    final address = _address.text.trim();
    if (name.isEmpty || phone.isEmpty || address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Lengkapi nama, no. HP, dan alamat dulu ya.')));
      return;
    }
    store.saveProfile(name, phone, address);
    final order = store.createOrder(
      service: _service,
      qty: _qty,
      antarJemput: _antarJemput,
      name: name,
      phone: phone,
      address: address,
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
    return Scaffold(
      appBar: AppBar(title: const Text('Buat Pesanan')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                const SectionTitle('Pilih Layanan'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in store.services)
                      ChoiceChip(
                        avatar: Icon(serviceIcon(s.id), size: 18),
                        label: Text(s.name),
                        selected: s.id == _service.id,
                        onSelected: (_) => _changeService(s),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_service.description,
                            style: theme.textTheme.bodyMedium),
                        const SizedBox(height: 4),
                        Text(
                          '${rupiah(_service.price)}/${_service.unit} • '
                          'Estimasi ${_service.estimasiHari} hari',
                          style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SectionTitle(_service.perKg
                    ? 'Perkiraan Berat'
                    : 'Jumlah (${_service.unit})'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            qtyText(_qty, _service.unit),
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w800),
                          ),
                        ),
                        IconButton.filledTonal(
                          tooltip: 'Kurangi',
                          onPressed: _qty > _minQty
                              ? () => setState(() => _qty -= _step)
                              : null,
                          icon: const Icon(Icons.remove),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          tooltip: 'Tambah',
                          onPressed: () => setState(() => _qty += _step),
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_service.perKg)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 4),
                    child: Text(
                      'Berat final ditimbang ulang saat cucian diterima.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                const SizedBox(height: 16),
                const SectionTitle('Penjemputan'),
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: _antarJemput,
                        onChanged: (v) => setState(() => _antarJemput = v),
                        title: const Text('Antar Jemput'),
                        subtitle: Text(_antarJemput
                            ? 'Kurir jemput & antar (+${rupiah(LaundryStore.biayaAntarJemput)})'
                            : 'Saya antar & ambil sendiri ke laundry'),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.event),
                        title: Text(shortDate(_date)),
                        subtitle: Text(_antarJemput
                            ? 'Tanggal penjemputan'
                            : 'Tanggal antar ke laundry'),
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
                  controller: _address,
                  maxLines: 2,
                  decoration: const InputDecoration(
                      labelText: 'Alamat lengkap',
                      prefixIcon: Icon(Icons.location_on_outlined)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notes,
                  maxLines: 2,
                  decoration: const InputDecoration(
                      labelText: 'Catatan (opsional)',
                      hintText: 'Contoh: pisahkan baju putih',
                      prefixIcon: Icon(Icons.sticky_note_2_outlined)),
                ),
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
