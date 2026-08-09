import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Sumber data tunggal aplikasi. Semua data disimpan lokal
/// (SharedPreferences) sebagai satu blob JSON sehingga aplikasi
/// berfungsi penuh tanpa backend — mode pelanggan dan pemilik
/// membaca data yang sama.
class LaundryStore extends ChangeNotifier {
  static const _storageKey = 'laundryku_state_v1';
  static const double biayaAntarJemput = 5000;

  final List<Order> orders = [];
  final List<ServiceType> services = [];
  CustomerProfile profile = CustomerProfile();

  /// 'customer' | 'owner' | null (belum memilih mode).
  String? role;

  bool _loaded = false;
  SharedPreferences? _prefs;

  Future<void> init() async {
    if (_loaded) return;
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_storageKey);
    if (raw != null) {
      try {
        final m = (jsonDecode(raw) as Map).cast<String, dynamic>();
        orders
          ..clear()
          ..addAll((m['orders'] as List? ?? [])
              .map((e) => Order.fromMap((e as Map).cast<String, dynamic>())));
        services
          ..clear()
          ..addAll((m['services'] as List? ?? []).map((e) =>
              ServiceType.fromMap((e as Map).cast<String, dynamic>())));
        profile = CustomerProfile.fromMap(
            ((m['profile'] as Map?) ?? {}).cast<String, dynamic>());
        role = m['role'] as String?;
      } catch (_) {
        // Data korup: mulai bersih daripada crash saat startup.
        orders.clear();
        services.clear();
      }
    }
    if (services.isEmpty) services.addAll(defaultServices());
    _loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    notifyListeners();
    final m = {
      'orders': orders.map((o) => o.toMap()).toList(),
      'services': services.map((s) => s.toMap()).toList(),
      'profile': profile.toMap(),
      'role': role,
    };
    await _prefs?.setString(_storageKey, jsonEncode(m));
  }

  ServiceType? serviceById(String id) {
    for (final s in services) {
      if (s.id == id) return s;
    }
    return null;
  }

  // ---- Mode / profil ----

  Future<void> setRole(String? value) async {
    role = value;
    await _save();
  }

  Future<void> saveProfile(String name, String phone, String address) async {
    profile
      ..name = name
      ..phone = phone
      ..address = address;
    await _save();
  }

  // ---- Pesanan ----

  Order createOrder({
    required ServiceType service,
    required double qty,
    required bool antarJemput,
    required String name,
    required String phone,
    required String address,
    required DateTime scheduledAt,
    required String notes,
  }) {
    final now = DateTime.now();
    final code = 'LK${now.year % 100}${now.month.toString().padLeft(2, '0')}'
        '-${(now.millisecondsSinceEpoch % 10000).toString().padLeft(4, '0')}';
    final order = Order(
      id: code,
      customerName: name,
      phone: phone,
      address: address,
      serviceId: service.id,
      serviceName: service.name,
      unit: service.unit,
      pricePerUnit: service.price,
      qty: qty,
      antarJemput: antarJemput,
      deliveryFee: antarJemput ? biayaAntarJemput : 0,
      scheduledAt: scheduledAt,
      notes: notes,
      status: OrderStatus.menunggu,
      history: [StatusEntry(OrderStatus.menunggu, now)],
      paid: false,
      createdAt: now,
    );
    orders.insert(0, order);
    _save();
    return order;
  }

  /// Majukan pesanan ke status berikutnya (dipakai mode pemilik).
  Future<void> advanceStatus(Order order) async {
    final i = order.status.index;
    if (i >= OrderStatus.values.length - 1) return;
    order.status = OrderStatus.values[i + 1];
    order.history.add(StatusEntry(order.status, DateTime.now()));
    await _save();
  }

  Future<void> setPaid(Order order, bool value) async {
    order.paid = value;
    await _save();
  }

  /// Perbarui berat/jumlah setelah ditimbang ulang di laundry.
  Future<void> updateQty(Order order, double qty) async {
    order.qty = qty;
    await _save();
  }

  Future<void> deleteOrder(Order order) async {
    orders.remove(order);
    await _save();
  }

  Future<void> updateServicePrice(ServiceType service, double price) async {
    service.price = price;
    await _save();
  }

  // ---- Ringkasan untuk dashboard/laporan pemilik ----

  List<Order> get activeOrders => orders.where((o) => !o.selesai).toList();

  DateTime? completedAt(Order o) {
    for (final e in o.history.reversed) {
      if (e.status == OrderStatus.selesai) return e.at;
    }
    return null;
  }

  /// Pendapatan (pesanan lunas & selesai) pada satu hari.
  double incomeOn(DateTime day) {
    var sum = 0.0;
    for (final o in orders) {
      if (!o.paid || !o.selesai) continue;
      final at = completedAt(o);
      if (at != null &&
          at.year == day.year &&
          at.month == day.month &&
          at.day == day.day) {
        sum += o.total;
      }
    }
    return sum;
  }

  double incomeInMonth(DateTime month) {
    var sum = 0.0;
    for (final o in orders) {
      if (!o.paid || !o.selesai) continue;
      final at = completedAt(o);
      if (at != null && at.year == month.year && at.month == month.month) {
        sum += o.total;
      }
    }
    return sum;
  }
}

final store = LaundryStore();
