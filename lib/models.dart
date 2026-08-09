/// Model data untuk aplikasi LaundryKu.
library;

/// Urutan status mengikuti alur pesanan dari dibuat sampai selesai.
enum OrderStatus { menunggu, dijemput, diproses, siap, selesai }

/// Label status yang menyesuaikan apakah pesanan pakai antar-jemput
/// atau pelanggan antar/ambil sendiri.
String statusLabel(OrderStatus status, {required bool antarJemput}) {
  switch (status) {
    case OrderStatus.menunggu:
      return antarJemput ? 'Menunggu Penjemputan' : 'Menunggu Diantar';
    case OrderStatus.dijemput:
      return antarJemput ? 'Dijemput Kurir' : 'Diterima di Laundry';
    case OrderStatus.diproses:
      return 'Sedang Diproses';
    case OrderStatus.siap:
      return antarJemput ? 'Siap Diantar' : 'Siap Diambil';
    case OrderStatus.selesai:
      return 'Selesai';
  }
}

class ServiceType {
  ServiceType({
    required this.id,
    required this.name,
    required this.unit,
    required this.price,
    required this.description,
    required this.estimasiHari,
  });

  final String id;
  final String name;

  /// Satuan tagihan: 'kg', 'pcs', atau 'pasang'.
  final String unit;
  double price;
  final String description;
  final int estimasiHari;

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
        OrderStatus.values.byName(m['status'] as String),
        DateTime.parse(m['at'] as String),
      );
}

class Order {
  Order({
    required this.id,
    required this.customerName,
    required this.phone,
    required this.address,
    required this.serviceId,
    required this.serviceName,
    required this.unit,
    required this.pricePerUnit,
    required this.qty,
    required this.antarJemput,
    required this.deliveryFee,
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
  final String address;
  final String serviceId;
  final String serviceName;
  final String unit;
  final double pricePerUnit;

  /// Berat/jumlah. Saat dibuat pelanggan ini perkiraan;
  /// pemilik bisa memperbarui setelah ditimbang ulang.
  double qty;
  final bool antarJemput;
  final double deliveryFee;
  final DateTime scheduledAt;
  final String notes;
  OrderStatus status;
  final List<StatusEntry> history;
  bool paid;
  final DateTime createdAt;

  double get subtotal => pricePerUnit * qty;
  double get total => subtotal + deliveryFee;
  bool get selesai => status == OrderStatus.selesai;

  String get statusText => statusLabel(status, antarJemput: antarJemput);

  Map<String, dynamic> toMap() => {
        'id': id,
        'customerName': customerName,
        'phone': phone,
        'address': address,
        'serviceId': serviceId,
        'serviceName': serviceName,
        'unit': unit,
        'pricePerUnit': pricePerUnit,
        'qty': qty,
        'antarJemput': antarJemput,
        'deliveryFee': deliveryFee,
        'scheduledAt': scheduledAt.toIso8601String(),
        'notes': notes,
        'status': status.name,
        'history': history.map((e) => e.toMap()).toList(),
        'paid': paid,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Order.fromMap(Map<String, dynamic> m) => Order(
        id: m['id'] as String,
        customerName: m['customerName'] as String,
        phone: m['phone'] as String,
        address: m['address'] as String,
        serviceId: m['serviceId'] as String,
        serviceName: m['serviceName'] as String,
        unit: m['unit'] as String,
        pricePerUnit: (m['pricePerUnit'] as num).toDouble(),
        qty: (m['qty'] as num).toDouble(),
        antarJemput: m['antarJemput'] as bool,
        deliveryFee: (m['deliveryFee'] as num).toDouble(),
        scheduledAt: DateTime.parse(m['scheduledAt'] as String),
        notes: m['notes'] as String? ?? '',
        status: OrderStatus.values.byName(m['status'] as String),
        history: (m['history'] as List)
            .map((e) => StatusEntry.fromMap((e as Map).cast<String, dynamic>()))
            .toList(),
        paid: m['paid'] as bool? ?? false,
        createdAt: DateTime.parse(m['createdAt'] as String),
      );
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
        id: 'bedcover',
        name: 'Bed Cover / Selimut',
        unit: 'pcs',
        price: 25000,
        description: 'Cuci bed cover, selimut, atau sprei tebal',
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
