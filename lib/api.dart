import 'dart:convert';
import 'package:http/http.dart' as http;
import 'store.dart';

/// Base URL of the Paramall backend (single-file PHP API on the Webuzo host).
const String kApiBase = 'https://paramall.h2olaundry.com/api/index.php';

/// Thrown when the server replies with an error (or is unreachable).
class ApiException implements Exception {
  final String message;
  final int code;
  ApiException(this.message, [this.code = 0]);
  @override
  String toString() => message;
}

/// Result of register/login/me — the account plus its session token.
class AuthResult {
  final String token;
  final String name;
  final String phone;
  final String address;
  AuthResult({required this.token, required this.name, required this.phone, required this.address});
}

class Api {
  static Future<Map<String, dynamic>> _post(String action, Map<String, dynamic> body, {String? token}) async {
    late final http.Response res;
    try {
      res = await http
          .post(
            Uri.parse('$kApiBase?action=$action'),
            headers: {
              'Content-Type': 'application/json',
              if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'action': action, ...body}),
          )
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      throw ApiException('Tidak bisa terhubung ke server. Cek koneksi internet kamu.');
    }
    Map<String, dynamic> data;
    try {
      data = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException('Server sedang bermasalah (kode ${res.statusCode}).', res.statusCode);
    }
    if (data['ok'] != true) {
      throw ApiException((data['error'] ?? 'Terjadi kesalahan').toString(), res.statusCode);
    }
    return data;
  }

  static Future<AuthResult> register({required String name, required String phone, required String pin}) async {
    final d = await _post('register', {'name': name, 'phone': phone, 'pin': pin});
    return AuthResult(
      token: (d['token'] ?? '').toString(),
      name: (d['name'] ?? name).toString(),
      phone: (d['phone'] ?? phone).toString(),
      address: (d['address'] ?? '').toString(),
    );
  }

  static Future<AuthResult> login({required String phone, required String pin}) async {
    final d = await _post('login', {'phone': phone, 'pin': pin});
    return AuthResult(
      token: (d['token'] ?? '').toString(),
      name: (d['name'] ?? '').toString(),
      phone: (d['phone'] ?? phone).toString(),
      address: (d['address'] ?? '').toString(),
    );
  }

  static Future<AuthResult> me(String token) async {
    final d = await _post('me', {}, token: token);
    return AuthResult(
      token: token,
      name: (d['name'] ?? '').toString(),
      phone: (d['phone'] ?? '').toString(),
      address: (d['address'] ?? '').toString(),
    );
  }

  static Future<void> saveProfile({required String token, required String name, required String address}) async {
    await _post('save_profile', {'name': name, 'address': address}, token: token);
  }

  /// Sends an order to the server and returns its server-assigned id.
  static Future<String> placeOrder({required String token, required Order order, required String zone}) async {
    final d = await _post('place_order', {
      'items': order.items.map((e) => e.toJson()).toList(),
      'subtotal': order.subtotal,
      'ongkir': order.ongkir,
      'total': order.total,
      'addr': order.addr,
      'name': order.name,
      'phone': order.phone,
      'note': order.note,
      'pay': order.pay,
      'zone': zone,
    }, token: token);
    return (d['id'] ?? '').toString();
  }

  static Future<List<Order>> myOrders(String token) async {
    final d = await _post('my_orders', {}, token: token);
    return _parseOrders(d['orders']);
  }

  static Future<List<Order>> adminOrders(String adminPass) async {
    final d = await _post('admin_orders', {'admin_pass': adminPass});
    return _parseOrders(d['orders']);
  }

  static Future<void> setStatus({required String adminPass, required String id, required String status}) async {
    await _post('admin_set_status', {'admin_pass': adminPass, 'id': id, 'status': status});
  }

  // ---- Driver mode ----
  static Future<List<Order>> driverOrders(String driverPass) async {
    final d = await _post('driver_orders', {'driver_pass': driverPass});
    return _parseOrders(d['orders']);
  }

  static Future<void> driverSetStatus({required String driverPass, required String id, required String status}) async {
    await _post('driver_set_status', {'driver_pass': driverPass, 'id': id, 'status': status});
  }

  // ---- Push tokens (used once Firebase is set up) ----
  static Future<void> registerToken({required String token, required String deviceToken, required String platform}) async {
    await _post('register_token', {'device_token': deviceToken, 'platform': platform}, token: token);
  }

  static List<Order> _parseOrders(dynamic raw) {
    if (raw is! List) return [];
    return raw.whereType<Map<String, dynamic>>().map(Order.fromJson).toList();
  }
}
