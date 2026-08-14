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
      String? custPin,
      Duration? timeout}) async {
    final r = await http
        .post(Uri.parse('$baseUrl$path'),
            headers: _headers(
                adminId: adminId,
                adminPin: adminPin,
                custPhone: custPhone,
                custPin: custPin),
            body: jsonEncode(body))
        .timeout(timeout ?? _timeout);
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
      {String? adminId,
      String? adminPin,
      String? custPhone,
      String? custPin}) async {
    final r = await http
        .delete(Uri.parse('$baseUrl$path'),
            headers: _headers(
                adminId: adminId,
                adminPin: adminPin,
                custPhone: custPhone,
                custPin: custPin))
        .timeout(_timeout);
    _decode(r);
  }

  // ---- Pesanan ----

  Future<Map<String, dynamic>> createOrder(Map<String, dynamic> order,
          {String? custPhone, String? custPin}) =>
      _post('/api/orders', order, custPhone: custPhone, custPin: custPin);

  // ---- Akun pelanggan ----

  Future<Map<String, dynamic>> customerRegister(
          String name, String phone, String pin,
          {String? idToken, String? otp}) =>
      _post('/api/customer/register', {
        'name': name,
        'phone': phone,
        'pin': pin,
        'idToken': ?idToken,
        'otp': ?otp,
      });

  /// Minta kode verifikasi WhatsApp. sent=false artinya gateway WA
  /// belum dikonfigurasi di server (daftar tanpa OTP).
  Future<Map<String, dynamic>> requestOtp(String phone) =>
      _post('/api/otp/request', {'phone': phone});

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

  // ---- Info & Promo ----

  Future<Map<String, dynamic>> createPost(
          {required String caption,
          String bgStyle = '',
          String link = '',
          String? imageData,
          String? imageExt,
          String? videoData,
          String? videoExt,
          String? adminId,
          String? adminPin,
          String? custPhone,
          String? custPin}) =>
      _post('/api/posts', {
        'caption': caption,
        'bgStyle': bgStyle,
        if (link.isNotEmpty) 'link': link,
        'imageData': ?imageData,
        'imageExt': ?imageExt,
        'videoData': ?videoData,
        'videoExt': ?videoExt,
      },
          adminId: adminId,
          adminPin: adminPin,
          custPhone: custPhone,
          custPin: custPin,
          // Unggah video besar butuh waktu jauh lebih lama.
          timeout: const Duration(minutes: 5));

  Future<void> deletePost(String id,
          {String? adminId,
          String? adminPin,
          String? custPhone,
          String? custPin}) =>
      _delete('/api/posts/$id',
          adminId: adminId,
          adminPin: adminPin,
          custPhone: custPhone,
          custPin: custPin);

  /// Beri/ubah reaksi emoji; emoji kosong = hapus reaksi.
  Future<Map<String, dynamic>> reactPost(String id, String emoji,
          {String? custPhone, String? custPin}) =>
      _post('/api/posts/$id/react', {'emoji': emoji},
          custPhone: custPhone, custPin: custPin);

  Future<Map<String, dynamic>> addPostComment(String id, String text,
          {String replyTo = '',
          String? adminId,
          String? adminPin,
          String? custPhone,
          String? custPin}) =>
      _post('/api/posts/$id/comments', {
        'text': text,
        if (replyTo.isNotEmpty) 'replyTo': replyTo,
      },
          adminId: adminId,
          adminPin: adminPin,
          custPhone: custPhone,
          custPin: custPin);

  Future<void> deletePostComment(String id, String cid,
          {String? adminId,
          String? adminPin,
          String? custPhone,
          String? custPin}) =>
      _delete('/api/posts/$id/comments/$cid',
          adminId: adminId,
          adminPin: adminPin,
          custPhone: custPhone,
          custPin: custPin);

  // ---- Profil sosial ----

  Future<Map<String, dynamic>> uploadProfilePhoto(
          {required String imageData,
          required String imageExt,
          String? custPhone,
          String? custPin}) =>
      _post('/api/customer/photo',
          {'imageData': imageData, 'imageExt': imageExt},
          custPhone: custPhone,
          custPin: custPin,
          timeout: const Duration(minutes: 2));

  Future<Map<String, dynamic>> getUser(String uid,
      {String? custPhone, String? custPin}) async {
    final r = await http
        .get(Uri.parse('$baseUrl/api/users/$uid'),
            headers: _headers(custPhone: custPhone, custPin: custPin))
        .timeout(_timeout);
    return (_decode(r) as Map).cast<String, dynamic>();
  }

  /// Daftar pengikut (followers=true) atau mengikuti (false).
  Future<Map<String, dynamic>> getFollowList(String uid, bool followers,
      {String? custPhone, String? custPin}) async {
    final path = followers ? 'followers' : 'following';
    final r = await http
        .get(Uri.parse('$baseUrl/api/users/$uid/$path'),
            headers: _headers(custPhone: custPhone, custPin: custPin))
        .timeout(_timeout);
    return (_decode(r) as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> setPrivacy(bool private,
          {String? custPhone, String? custPin}) =>
      _post('/api/customer/privacy', {'private': private},
          custPhone: custPhone, custPin: custPin);

  Future<Map<String, dynamic>> followUser(String uid,
          {String? custPhone, String? custPin}) =>
      _post('/api/users/$uid/follow', {},
          custPhone: custPhone, custPin: custPin);

  Future<Map<String, dynamic>> bookmarkPost(String id,
          {String? custPhone, String? custPin}) =>
      _post('/api/posts/$id/bookmark', {},
          custPhone: custPhone, custPin: custPin);

  // ---- Layanan Pelanggan (chat) ----

  Future<Map<String, dynamic>> sendChat(String text,
          {String? custPhone, String? custPin}) =>
      _post('/api/chat', {'text': text},
          custPhone: custPhone, custPin: custPin);

  Future<Map<String, dynamic>> markChatRead(
          {String? custPhone, String? custPin}) =>
      _post('/api/chat/read', {}, custPhone: custPhone, custPin: custPin);

  Future<Map<String, dynamic>> adminSendChat(String phone, String text,
          {String? adminId, String? adminPin}) =>
      _post('/api/chat/$phone', {'text': text},
          adminId: adminId, adminPin: adminPin);

  Future<Map<String, dynamic>> adminMarkChatRead(String phone,
          {String? adminId, String? adminPin}) =>
      _post('/api/chat/$phone/read', {},
          adminId: adminId, adminPin: adminPin);

  // ---- Berita (hiburan) ----

  Future<Map<String, dynamic>> getNews() async {
    final r = await http
        .get(Uri.parse('$baseUrl/api/news'))
        .timeout(const Duration(seconds: 30));
    return (_decode(r) as Map).cast<String, dynamic>();
  }

  // ---- Video Musik Indonesia (YouTube via server) ----

  Future<Map<String, dynamic>> getMusikVideo() async {
    final r = await http
        .get(Uri.parse('$baseUrl/api/musikvideo'))
        .timeout(const Duration(seconds: 30));
    return (_decode(r) as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> searchMusikVideo(String q) async {
    final r = await http
        .get(Uri.parse('$baseUrl/api/musikvideo/search'
            '?q=${Uri.encodeQueryComponent(q)}'))
        .timeout(const Duration(seconds: 30));
    return (_decode(r) as Map).cast<String, dynamic>();
  }

  // ---- Musik Indonesia (netlabel CC via server) ----

  Future<Map<String, dynamic>> getMusikIndonesia() async {
    // Muat pertama bisa lama: server merangkai katalog archive.org.
    final r = await http
        .get(Uri.parse('$baseUrl/api/musik-id'))
        .timeout(const Duration(seconds: 45));
    return (_decode(r) as Map).cast<String, dynamic>();
  }

  // ---- Ramalan Zodiak (hiburan) ----

  Future<Map<String, dynamic>> getZodiac(String sign) async {
    final r = await http
        .get(Uri.parse('$baseUrl/api/zodiac/$sign'))
        .timeout(_timeout);
    return (_decode(r) as Map).cast<String, dynamic>();
  }

  // ---- Info toko (Tentang) ----

  Future<Map<String, dynamic>> updateAbout(Map<String, dynamic> about,
          {String? adminId, String? adminPin}) =>
      _post('/api/about', about, adminId: adminId, adminPin: adminPin);

  // ---- Hiburan ----

  Future<Map<String, dynamic>> createHiburan(
          {required String title,
          required String emoji,
          required String url,
          String? adminId,
          String? adminPin}) =>
      _post('/api/hiburan', {'title': title, 'emoji': emoji, 'url': url},
          adminId: adminId, adminPin: adminPin);

  Future<void> deleteHiburan(String id,
          {String? adminId, String? adminPin}) =>
      _delete('/api/hiburan/$id', adminId: adminId, adminPin: adminPin);

  // ---- Notifikasi ----

  Future<Map<String, dynamic>> markNotifsRead(
          {String? custPhone, String? custPin}) =>
      _post('/api/notifs/read', {},
          custPhone: custPhone, custPin: custPin);

  Future<void> deleteNotif(String id,
          {String? custPhone, String? custPin}) =>
      _delete('/api/notifs/$id', custPhone: custPhone, custPin: custPin);

  Future<void> clearNotifs({String? custPhone, String? custPin}) =>
      _delete('/api/notifs', custPhone: custPhone, custPin: custPin);

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
          {String phone = '', String? adminId, String? adminPin}) =>
      _post('/api/admins', {'name': name, 'pin': pin, 'phone': phone},
          adminId: adminId, adminPin: adminPin);

  Future<Map<String, dynamic>> updateAdmin(String id,
          {String? name,
          String? pin,
          String? phone,
          String? adminId,
          String? adminPin}) =>
      _put('/api/admins/$id', {
        if (name != null && name.isNotEmpty) 'name': name,
        if (pin != null && pin.isNotEmpty) 'pin': pin,
        'phone': ?phone,
      }, adminId: adminId, adminPin: adminPin);

  Future<void> deleteAdmin(String id,
          {String? adminId, String? adminPin}) =>
      _delete('/api/admins/$id', adminId: adminId, adminPin: adminPin);
}
