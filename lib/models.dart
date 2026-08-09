/// Model data untuk aplikasi H2O Laundry Parakan.
library;

/// Alur pesanan layanan di gerai (pelanggan datang ke counter):
/// menunggu diantar → diterima → diproses → siap diambil → selesai.
enum OrderStatus { menunggu, diterima, diproses, siap, selesai }

OrderStatus statusFromName(String s) {
  // Data lama memakai nama 'dijemput' untuk status kedua.
  if (s == 'dijemput') return OrderStatus.diterima;
  return OrderStatus.values.byName(s);
}

String statusLabel(OrderStatus status) {
  switch (status) {
    case OrderStatus.menunggu:
      return 'Menunggu Diantar';
    case OrderStatus.diterima:
      return 'Diterima di Laundry';
    case OrderStatus.diproses:
      return 'Sedang Diproses';
    case OrderStatus.siap:
      return 'Siap Diambil';
    case OrderStatus.selesai:
      return 'Selesai';
  }
}

/// Item katalog layanan/cucian. Pemilik bisa menambah, mengubah,
/// dan menghapus item lewat tab "Item & Harga".
class ServiceType {
  ServiceType({
    required this.id,
    required this.name,
    required this.unit,
    required this.price,
    this.description = '',
    this.estimasiHari = 2,
  });

  final String id;
  String name;

  /// Satuan tagihan: 'kg', 'pcs', atau 'pasang'.
  String unit;
  double price;
  String description;
  int estimasiHari;

  bool get perKg => unit == 'kg';

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'unit': unit,
        'price': price,
        'description': description,
        'estimasiHari': estimasiHari,
      };

  factory ServiceType.fromMap(Map<String, dynamic> m) => ServiceType(
        id: m['id'] as String,
        name: m['name'] as String,
        unit: m['unit'] as String,
        price: (m['price'] as num).toDouble(),
        description: m['description'] as String? ?? '',
        estimasiHari: m['estimasiHari'] as int? ?? 2,
      );
}

class StatusEntry {
  StatusEntry(this.status, this.at);

  final OrderStatus status;
  final DateTime at;

  Map<String, dynamic> toMap() =>
      {'status': status.name, 'at': at.toIso8601String()};

  factory StatusEntry.fromMap(Map<String, dynamic> m) => StatusEntry(
        statusFromName(m['status'] as String),
        DateTime.parse(m['at'] as String),
      );
}

/// Satu baris item dalam pesanan, mis. "Baju Atasan × 3".
class OrderItem {
  OrderItem({
    required this.serviceId,
    required this.name,
    required this.unit,
    required this.price,
    required this.qty,
  });

  final String serviceId;
  final String name;
  final String unit;
  final double price;

  /// Jumlah/berat; untuk item kiloan ini perkiraan yang bisa
  /// diperbarui pemilik setelah ditimbang di counter.
  double qty;

  double get subtotal => price * qty;

  Map<String, dynamic> toMap() => {
        'serviceId': serviceId,
        'name': name,
        'unit': unit,
        'price': price,
        'qty': qty,
      };

  factory OrderItem.fromMap(Map<String, dynamic> m) => OrderItem(
        serviceId: m['serviceId'] as String,
        name: m['name'] as String,
        unit: m['unit'] as String,
        price: (m['price'] as num).toDouble(),
        qty: (m['qty'] as num).toDouble(),
      );
}

class Order {
  Order({
    required this.id,
    required this.customerName,
    required this.phone,
    required this.items,
    required this.contents,
    required this.scheduledAt,
    required this.notes,
    required this.status,
    required this.history,
    required this.paid,
    required this.createdAt,
  });

  final String id;
  final String customerName;
  final String phone;
  final List<OrderItem> items;

  /// Jenis pakaian yang dicuci, dideklarasikan pelanggan saat memesan
  /// (mis. Kaos, Kemeja, Handuk). Item di luar daftar ini menjadi
  /// tanggung jawab pelanggan bila hilang.
  final List<String> contents;

  /// Rencana pelanggan datang mengantar cucian ke counter.
  final DateTime scheduledAt;
  final String notes;
  OrderStatus status;
  final List<StatusEntry> history;
  bool paid;
  final DateTime createdAt;

  double get total =>
      items.fold(0, (sum, item) => sum + item.subtotal);
  bool get selesai => status == OrderStatus.selesai;
  String get statusText => statusLabel(status);

  /// Ringkasan singkat isi pesanan, mis. "Baju Atasan ×3 +2 item".
  String get itemsBrief {
    if (items.isEmpty) return '-';
    final first = items.first;
    final more = items.length - 1;
    final qty = first.qty == first.qty.roundToDouble()
        ? first.qty.toInt().toString()
        : first.qty.toStringAsFixed(1).replaceAll('.', ',');
    return more > 0
        ? '${first.name} ×$qty  +$more item'
        : '${first.name} ×$qty ${first.unit}';
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'customerName': customerName,
        'phone': phone,
        'items': items.map((e) => e.toMap()).toList(),
        'contents': contents,
        'scheduledAt': scheduledAt.toIso8601String(),
        'notes': notes,
        'status': status.name,
        'history': history.map((e) => e.toMap()).toList(),
        'paid': paid,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Order.fromMap(Map<String, dynamic> m) {
    // Migrasi data lama: pesanan satu-layanan menjadi satu item.
    final items = m['items'] != null
        ? (m['items'] as List)
            .map((e) =>
                OrderItem.fromMap((e as Map).cast<String, dynamic>()))
            .toList()
        : [
            OrderItem(
              serviceId: m['serviceId'] as String? ?? '',
              name: m['serviceName'] as String? ?? 'Layanan',
              unit: m['unit'] as String? ?? 'kg',
              price: (m['pricePerUnit'] as num? ?? 0).toDouble(),
              qty: (m['qty'] as num? ?? 1).toDouble(),
            ),
          ];
    return Order(
      id: m['id'] as String,
      customerName: m['customerName'] as String,
      phone: m['phone'] as String,
      items: items,
      contents:
          (m['contents'] as List? ?? []).map((e) => e as String).toList(),
      scheduledAt: DateTime.parse(m['scheduledAt'] as String),
      notes: m['notes'] as String? ?? '',
      status: statusFromName(m['status'] as String),
      history: (m['history'] as List)
          .map((e) =>
              StatusEntry.fromMap((e as Map).cast<String, dynamic>()))
          .toList(),
      paid: m['paid'] as bool? ?? false,
      createdAt: DateTime.parse(m['createdAt'] as String),
    );
  }
}

class CustomerProfile {
  CustomerProfile({this.name = '', this.phone = '', this.address = ''});

  String name;
  String phone;
  String address;

  bool get isEmpty => name.isEmpty && phone.isEmpty && address.isEmpty;

  Map<String, dynamic> toMap() =>
      {'name': name, 'phone': phone, 'address': address};

  factory CustomerProfile.fromMap(Map<String, dynamic> m) => CustomerProfile(
        name: m['name'] as String? ?? '',
        phone: m['phone'] as String? ?? '',
        address: m['address'] as String? ?? '',
      );
}

List<ServiceType> defaultServices() => [
      ServiceType(
        id: 'cuci_setrika',
        name: 'Cuci + Setrika',
        unit: 'kg',
        price: 7000,
        description: 'Cuci bersih, wangi, dan disetrika rapi',
        estimasiHari: 2,
      ),
      ServiceType(
        id: 'cuci_kering',
        name: 'Cuci Kering',
        unit: 'kg',
        price: 5000,
        description: 'Cuci dan keringkan, lipat tanpa setrika',
        estimasiHari: 2,
      ),
      ServiceType(
        id: 'setrika',
        name: 'Setrika Saja',
        unit: 'kg',
        price: 4000,
        description: 'Pakaian bersih Anda disetrika rapi',
        estimasiHari: 1,
      ),
      ServiceType(
        id: 'express',
        name: 'Express 1 Hari',
        unit: 'kg',
        price: 12000,
        description: 'Cuci + setrika kilat, selesai 24 jam',
        estimasiHari: 1,
      ),
      ServiceType(
        id: 'baju_atasan',
        name: 'Baju Atasan',
        unit: 'pcs',
        price: 7000,
        description: 'Kemeja, kaos, blus — cuci & setrika per potong',
        estimasiHari: 2,
      ),
      ServiceType(
        id: 'baju_bawahan',
        name: 'Baju Bawahan',
        unit: 'pcs',
        price: 8000,
        description: 'Celana, rok — cuci & setrika per potong',
        estimasiHari: 2,
      ),
      ServiceType(
        id: 'selimut',
        name: 'Selimut',
        unit: 'pcs',
        price: 20000,
        description: 'Cuci selimut bersih dan wangi',
        estimasiHari: 3,
      ),
      ServiceType(
        id: 'bedcover',
        name: 'Bed Cover',
        unit: 'pcs',
        price: 25000,
        description: 'Cuci bed cover atau sprei tebal',
        estimasiHari: 3,
      ),
      ServiceType(
        id: 'sepatu',
        name: 'Cuci Sepatu',
        unit: 'pasang',
        price: 30000,
        description: 'Deep clean sepatu sampai seperti baru',
        estimasiHari: 3,
      ),
    ];
