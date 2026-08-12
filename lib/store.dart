import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Simple on-device persistence for profile + orders (localStorage equivalent).
class Profile {
  String name;
  String phone;
  String address;
  Profile({this.name = '', this.phone = '', this.address = ''});

  Map<String, dynamic> toJson() => {'name': name, 'phone': phone, 'address': address};
  factory Profile.fromJson(Map<String, dynamic> j) =>
      Profile(name: j['name'] ?? '', phone: j['phone'] ?? '', address: j['address'] ?? '');
}

class OrderItem {
  final String name;
  final int price;
  final int qty;
  OrderItem({required this.name, required this.price, required this.qty});
  int get sum => price * qty;
  Map<String, dynamic> toJson() => {'name': name, 'price': price, 'qty': qty};
  factory OrderItem.fromJson(Map<String, dynamic> j) =>
      OrderItem(name: j['name'], price: j['price'], qty: j['qty']);
}

class Order {
  final String id;
  final DateTime at;
  final String name, phone, addr, note, pay;
  final List<OrderItem> items;
  final int subtotal, ongkir, total;
  Order({
    required this.id, required this.at, required this.name, required this.phone,
    required this.addr, required this.note, required this.pay, required this.items,
    required this.subtotal, required this.ongkir, required this.total,
  });

  int get count => items.fold(0, (a, b) => a + b.qty);

  Map<String, dynamic> toJson() => {
        'id': id, 'at': at.toIso8601String(), 'name': name, 'phone': phone,
        'addr': addr, 'note': note, 'pay': pay,
        'items': items.map((e) => e.toJson()).toList(),
        'subtotal': subtotal, 'ongkir': ongkir, 'total': total,
      };
  factory Order.fromJson(Map<String, dynamic> j) => Order(
        id: j['id'], at: DateTime.parse(j['at']), name: j['name'], phone: j['phone'],
        addr: j['addr'], note: j['note'] ?? '', pay: j['pay'],
        items: (j['items'] as List).map((e) => OrderItem.fromJson(e)).toList(),
        subtotal: j['subtotal'], ongkir: j['ongkir'], total: j['total'],
      );
}

class Store {
  static const _kProfile = 'paramall_profile';
  static const _kOrders = 'paramall_orders';

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

  static Future<void> addOrder(Order o) async {
    final sp = await SharedPreferences.getInstance();
    final list = await getOrders();
    list.insert(0, o);
    final trimmed = list.take(50).toList();
    await sp.setString(_kOrders, jsonEncode(trimmed.map((e) => e.toJson()).toList()));
  }
}
