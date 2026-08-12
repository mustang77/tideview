import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

String hashPin(String pin) => sha256.convert(utf8.encode('paramall::$pin')).toString();

/// Simple on-device persistence for account + orders (localStorage equivalent).
class Profile {
  String name;
  String phone;
  String address;
  String pinHash;
  Profile({this.name = '', this.phone = '', this.address = '', this.pinHash = ''});

  Map<String, dynamic> toJson() => {'name': name, 'phone': phone, 'address': address, 'pinHash': pinHash};
  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        name: j['name'] ?? '', phone: j['phone'] ?? '', address: j['address'] ?? '', pinHash: j['pinHash'] ?? '',
      );
  bool get hasAccount => phone.isNotEmpty && pinHash.isNotEmpty;
}

int _toInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.round();
  return int.tryParse('${v ?? ''}') ?? 0;
}

DateTime _toDate(dynamic v) => DateTime.tryParse('${v ?? ''}')?.toLocal() ?? DateTime.now();

class OrderItem {
  final String name;
  final int price;
  final int qty;
  OrderItem({required this.name, required this.price, required this.qty});
  int get sum => price * qty;
  Map<String, dynamic> toJson() => {'name': name, 'price': price, 'qty': qty};
  factory OrderItem.fromJson(Map<String, dynamic> j) =>
      OrderItem(name: (j['name'] ?? '').toString(), price: _toInt(j['price']), qty: _toInt(j['qty']));
}

class Order {
  final String id;
  final DateTime at;
  final String name, phone, addr, note, pay;
  final List<OrderItem> items;
  final int subtotal, ongkir, total;
  final String status; // 'Diterima' | 'Diproses' | 'Diantar' | 'Selesai'
  Order({
    required this.id, required this.at, required this.name, required this.phone,
    required this.addr, required this.note, required this.pay, required this.items,
    required this.subtotal, required this.ongkir, required this.total,
    this.status = 'Diterima',
  });

  int get count => items.fold(0, (a, b) => a + b.qty);

  Map<String, dynamic> toJson() => {
        'id': id, 'at': at.toIso8601String(), 'name': name, 'phone': phone,
        'addr': addr, 'note': note, 'pay': pay,
        'items': items.map((e) => e.toJson()).toList(),
        'subtotal': subtotal, 'ongkir': ongkir, 'total': total, 'status': status,
      };
  // Works for both our local cache and the server's JSON (same shape).
  factory Order.fromJson(Map<String, dynamic> j) => Order(
        id: (j['id'] ?? '').toString(), at: _toDate(j['at']),
        name: (j['name'] ?? '').toString(), phone: (j['phone'] ?? '').toString(),
        addr: (j['addr'] ?? '').toString(), note: (j['note'] ?? '').toString(), pay: (j['pay'] ?? '').toString(),
        items: ((j['items'] as List?) ?? const []).map((e) => OrderItem.fromJson(e as Map<String, dynamic>)).toList(),
        subtotal: _toInt(j['subtotal']), ongkir: _toInt(j['ongkir']), total: _toInt(j['total']),
        status: (j['status'] ?? 'Diterima').toString(),
      );
}

class Store {
  static const _kProfile = 'paramall_profile';
  static const _kOrders = 'paramall_orders';
  static const _kSession = 'paramall_session';
  static const _kToken = 'paramall_token';

  static Future<bool> loggedIn() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_kSession) ?? false;
  }

  static Future<void> setLoggedIn(bool v) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_kSession, v);
  }

  /// Session token from the backend (empty = logged out).
  static Future<String> getToken() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kToken) ?? '';
  }

  static Future<void> setToken(String t) async {
    final sp = await SharedPreferences.getInstance();
    if (t.isEmpty) {
      await sp.remove(_kToken);
    } else {
      await sp.setString(_kToken, t);
    }
  }

  static Future<Profile> getProfile() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kProfile);
    if (raw == null) return Profile();
    try {
      return Profile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return Profile();
    }
  }

  static Future<void> saveProfile(Profile p) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kProfile, jsonEncode(p.toJson()));
  }

  static Future<List<Order>> getOrders() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_kOrders);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).map((e) => Order.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Replace the local cache with the given (server) orders.
  static Future<void> saveOrders(List<Order> orders) async {
    final sp = await SharedPreferences.getInstance();
    final trimmed = orders.take(100).toList();
    await sp.setString(_kOrders, jsonEncode(trimmed.map((e) => e.toJson()).toList()));
  }
}
