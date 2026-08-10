import 'dart:convert';

import 'package:http/http.dart' as http;

/// URL server bawaan, bisa ditanam saat build:
/// flutter build apk --dart-define=API_URL=https://domain-anda.com
const kDefaultApiUrl = String.fromEnvironment('API_URL', defaultValue: '');

class ApiException implements Exception {
  ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Klien REST API server H2O Laundry (lihat folder server/).
class ApiClient {
  ApiClient(String baseUrl)
      : baseUrl = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');

  final String baseUrl;
  static const _timeout = Duration(seconds: 10);

  Map<String, String> _headers(
          {String? adminId,
          String? adminPin,
          String? custPhone,
          String? custPin}) =>
      {
        'Content-Type': 'application/json',
        'x-admin-id': ?adminId,
        'x-admin-pin': ?adminPin,
        'x-cust-phone': ?custPhone,
        'x-cust-pin': ?custPin,
      };

  dynamic _decode(http.Response r) {
    if (r.statusCode >= 200 && r.statusCode < 300) {
      return jsonDecode(utf8.decode(r.bodyBytes));
    }
    String message = r.body;
    try {
      message = (jsonDecode(r.body) as Map)['error'] as String? ?? r.body;
    } catch (_) {}
    throw ApiException(r.statusCode, message);
  }

  Future<Map<String, dynamic>> health() async {
    final r = await http
        .get(Uri.parse('$baseUrl/api/health'))
        .timeout(_timeout);
    return (_decode(r) as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> state(
      {String? adminId,
      String? adminPin,
      String? custPhone,
      String? custPin}) async {
    final r = await http
        .get(Uri.parse('$baseUrl/api/state'),
            headers: _headers(
                adminId: adminId,
                adminPin: adminPin,
                custPhone: custPhone,
                custPin: custPin))
        .timeout(_timeout);
    return (_decode(r) as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body,
      {String? adminId,
      String? adminPin,
      String? custPhone,
      String? custPin}) async {
    final r = await http
        .post(Uri.parse('$baseUrl$path'),
            headers: _headers(
                adminId: adminId,
                adminPin: adminPin,
                custPhone: custPhone,
                custPin: custPin),
            body: jsonEncode(body))
        .timeout(_timeout);
    return (_decode(r) as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> _put(String path, Map<String, dynamic> body,
      {String? adminId, String? adminPin}) async {
    final r = await http
        .put(Uri.parse('$baseUrl$path'),
            headers: _headers(adminId: adminId, adminPin: adminPin),
            body: jsonEncode(body))
        .timeout(_timeout);
    return (_decode(r) as Map).cast<String, dynamic>();
  }

  Future<void> _delete(String path,
      {String? adminId, String? adminPin}) async {
    final r = await http
        .delete(Uri.parse('$baseUrl$path'),
            headers: _headers(adminId: adminId, adminPin: adminPin))
        .timeout(_timeout);
    _decode(r);
  }

  // ---- Pesanan ----

  Future<Map<String, dynamic>> createOrder(Map<String, dynamic> order,
          {String? custPhone, String? custPin}) =>
      _post('/api/orders', order, custPhone: custPhone, custPin: custPin);

  // ---- Akun pelanggan ----

  Future<Map<String, dynamic>> customerRegister(
          String name, String phone, String pin, {String? idToken}) =>
      _post('/api/customer/register', {
        'name': name,
        'phone': phone,
        'pin': pin,
        'idToken': ?idToken,
      });

  Future<Map<String, dynamic>> customerLogin(String phone, String pin) =>
      _post('/api/customer/login', {'phone': phone, 'pin': pin});

  Future<Map<String, dynamic>> advanceOrder(String id,
          {String? adminId, String? adminPin}) =>
      _post('/api/orders/$id/advance', {},
          adminId: adminId, adminPin: adminPin);

  Future<Map<String, dynamic>> setOrderPaid(String id, bool paid,
          {String? adminId, String? adminPin}) =>
      _post('/api/orders/$id/paid', {'paid': paid},
          adminId: adminId, adminPin: adminPin);

  Future<Map<String, dynamic>> setItemQty(String id, int index, double qty,
          {String? adminId, String? adminPin}) =>
      _post('/api/orders/$id/item-qty', {'index': index, 'qty': qty},
          adminId: adminId, adminPin: adminPin);

  Future<void> deleteOrder(String id, {String? adminId, String? adminPin}) =>
      _delete('/api/orders/$id', adminId: adminId, adminPin: adminPin);

  // ---- Katalog ----

  Future<Map<String, dynamic>> createService(Map<String, dynamic> s,
          {String? adminId, String? adminPin}) =>
      _post('/api/services', s, adminId: adminId, adminPin: adminPin);

  Future<Map<String, dynamic>> updateService(
          String id, Map<String, dynamic> s,
          {String? adminId, String? adminPin}) =>
      _put('/api/services/$id', s, adminId: adminId, adminPin: adminPin);

  Future<void> deleteService(String id,
          {String? adminId, String? adminPin}) =>
      _delete('/api/services/$id', adminId: adminId, adminPin: adminPin);

  // ---- Admin ----

  Future<Map<String, dynamic>> adminLogin(String id, String pin) =>
      _post('/api/admin/login', {'id': id, 'pin': pin});

  Future<Map<String, dynamic>> createAdmin(String name, String pin,
          {String? adminId, String? adminPin}) =>
      _post('/api/admins', {'name': name, 'pin': pin},
          adminId: adminId, adminPin: adminPin);

  Future<Map<String, dynamic>> updateAdmin(String id,
          {String? name,
          String? pin,
          String? adminId,
          String? adminPin}) =>
      _put('/api/admins/$id', {
        if (name != null && name.isNotEmpty) 'name': name,
        if (pin != null && pin.isNotEmpty) 'pin': pin,
      }, adminId: adminId, adminPin: adminPin);

  Future<void> deleteAdmin(String id,
          {String? adminId, String? adminPin}) =>
      _delete('/api/admins/$id', adminId: adminId, adminPin: adminPin);
}
