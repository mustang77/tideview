import 'dart:async' show unawaited;
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'models.dart';

/// Sumber data tunggal aplikasi, dengan dua mode:
///
/// - **Mode server** (apiUrl terisi): server menjadi sumber kebenaran.
///   Pesanan pelanggan dari HP mana pun langsung tampil di counter,
///   dan status yang diubah admin tampil di HP pelanggan. Data terakhir
///   tetap disimpan lokal sebagai cache saat offline.
/// - **Mode lokal** (apiUrl kosong): semua data di perangkat, tanpa
///   server — perilaku lama, tetap berfungsi penuh.
class LaundryStore extends ChangeNotifier {
  static const _storageKey = 'laundryku_state_v1';
  static const _apiUrlKey = 'h2o_api_url';

  final List<Order> orders = [];
  final List<ServiceType> services = [];
  final List<AdminUser> admins = [];

  /// Feed Info & Promo dari server (kosong di mode lokal).
  final List<PromoPost> posts = [];

  /// Notifikasi pelanggan dari server, terbaru dulu.
  final List<AppNotif> notifs = [];

  /// Ubin Hiburan dari server (dikelola admin).
  final List<HiburanTile> hiburan = [];

  int get unreadNotifs => notifs.where((n) => !n.read).length;
  CustomerProfile profile = CustomerProfile();

  /// 'customer' | 'owner' | null (belum memilih mode).
  String? role;

  /// Admin yang sedang masuk di Mode Pemilik.
  String? currentAdminId;
  String? _adminPin;

  /// PIN akun pelanggan (mode server) untuk autentikasi pesanan.
  String? _custPin;

  /// URL server (kosong = mode lokal).
  String apiUrl = '';

  /// false bila panggilan server terakhir gagal (tampilkan banner offline).
  bool serverOk = true;

  bool get online => apiUrl.isNotEmpty;
  ApiClient? get api => online ? ApiClient(apiUrl) : null;

  AdminUser? get currentAdmin {
    for (final a in admins) {
      if (a.id == currentAdminId) return a;
    }
    return null;
  }

  bool _loaded = false;
  SharedPreferences? _prefs;

  Future<void> init() async {
    if (_loaded) return;
    _prefs = await SharedPreferences.getInstance();
    apiUrl = _prefs!.getString(_apiUrlKey) ?? kDefaultApiUrl;
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
        admins
          ..clear()
          ..addAll((m['admins'] as List? ?? []).map((e) =>
              AdminUser.fromMap((e as Map).cast<String, dynamic>())));
        profile = CustomerProfile.fromMap(
            ((m['profile'] as Map?) ?? {}).cast<String, dynamic>());
        role = m['role'] as String?;
        currentAdminId = m['currentAdminId'] as String?;
        _adminPin = m['adminPin'] as String?;
        _custPin = m['custPin'] as String?;
      } catch (_) {
        // Data korup: mulai bersih daripada crash saat startup.
        orders.clear();
        services.clear();
      }
    }
    if (services.isEmpty && !online) services.addAll(defaultServices());
    _loaded = true;
    notifyListeners();
    // Segarkan dari server TANPA menunggu: aplikasi langsung tampil
    // dari cache lokal, data server menyusul (banner offline muncul
    // bila server tidak terjangkau). Menunggu di sini membuat layar
    // putih selamanya kalau server mati.
    if (online) unawaited(refresh());
  }

  Future<void> _save() async {
    notifyListeners();
    final m = {
      'orders': orders.map((o) => o.toMap()).toList(),
      'services': services.map((s) => s.toMap()).toList(),
      'admins': admins.map((a) => a.toMap()).toList(),
      'profile': profile.toMap(),
      'role': role,
      'currentAdminId': currentAdminId,
      'adminPin': _adminPin,
      'custPin': _custPin,
    };
    await _prefs?.setString(_storageKey, jsonEncode(m));
  }

  ServiceType? serviceById(String id) {
    for (final s in services) {
      if (s.id == id) return s;
    }
    return null;
  }

  // ---- Server ----

  Future<void> setApiUrl(String url) async {
    apiUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    await _prefs?.setString(_apiUrlKey, apiUrl);
    serverOk = true;
    if (online) {
      await refresh();
    } else {
      if (services.isEmpty) services.addAll(defaultServices());
      await _save();
    }
  }

  /// Ambil data terbaru dari server (katalog, admin, dan pesanan —
  /// semua pesanan untuk pemilik, atau pesanan milik no. HP pelanggan).
  Future<bool> refresh() async {
    final a = api;
    if (a == null) return true;
    try {
      final Map<String, dynamic> m;
      try {
        m = await a.state(
          adminId: role == 'owner' ? currentAdminId : null,
          adminPin: role == 'owner' ? _adminPin : null,
          custPhone:
              role == 'customer' && _custPin != null ? profile.phone : null,
          custPin: role == 'customer' ? _custPin : null,
        );
      } on ApiException catch (e) {
        // Sesi pelanggan tidak valid (mis. PIN diganti): keluar paksa.
        if (e.statusCode == 401 && role == 'customer') {
          _custPin = null;
          role = null;
          await _save();
          return false;
        }
        rethrow;
      }
      services
        ..clear()
        ..addAll((m['services'] as List).map(
            (e) => ServiceType.fromMap((e as Map).cast<String, dynamic>())));
      admins
        ..clear()
        ..addAll((m['adminNames'] as List).map((e) => AdminUser(
              id: (e as Map)['id'] as String,
              name: e['name'] as String,
              pin: '',
            )));
      orders
        ..clear()
        ..addAll((m['orders'] as List).map(
            (e) => Order.fromMap((e as Map).cast<String, dynamic>())));
      posts
        ..clear()
        ..addAll((m['posts'] as List? ?? []).map(
            (e) => PromoPost.fromMap((e as Map).cast<String, dynamic>())));
      notifs
        ..clear()
        ..addAll((m['notifs'] as List? ?? []).map(
            (e) => AppNotif.fromMap((e as Map).cast<String, dynamic>())));
      hiburan
        ..clear()
        ..addAll((m['hiburan'] as List? ?? []).map(
            (e) => HiburanTile.fromMap((e as Map).cast<String, dynamic>())));
      serverOk = true;
      await _save();
      return true;
    } catch (_) {
      serverOk = false;
      notifyListeners();
      return false;
    }
  }

  /// Salin kondisi terbaru dari server ke objek pesanan yang sama,
  /// supaya layar detail yang memegang referensinya ikut terbarui.
  void _applyOrder(Order order, Map<String, dynamic> m) {
    final fresh = Order.fromMap(m);
    order.status = fresh.status;
    order.paid = fresh.paid;
    order.history
      ..clear()
      ..addAll(fresh.history);
    for (var i = 0;
        i < order.items.length && i < fresh.items.length;
        i++) {
      order.items[i].qty = fresh.items[i].qty;
    }
  }

  // ---- Info & Promo ----

  /// URL penuh media server (foto promo) dari jalur relatifnya.
  String mediaUrl(String path) =>
      path.isEmpty || path.startsWith('http') ? path : '$apiUrl$path';

  void _replacePost(PromoPost old, Map<String, dynamic> m) {
    final fresh = PromoPost.fromMap(m);
    // Cari berdasarkan id, bukan instance: polling refresh bisa saja
    // mengganti isi daftar saat permintaan masih berjalan.
    final i = posts.indexWhere((x) => x.id == fresh.id);
    if (i >= 0) {
      posts[i] = fresh;
    }
    notifyListeners();
  }

  /// Buat pos promo baru (admin). Mengembalikan pesan error, null = sukses.
  Future<String?> createPromo(
      {required String caption,
      String bgStyle = '',
      String link = '',
      String? imageBase64,
      String? imageExt,
      String? videoBase64,
      String? videoExt}) async {
    final a = api;
    if (a == null) return 'Fitur promo membutuhkan server.';
    final asOwner = role == 'owner';
    if (!asOwner && _custPin == null) {
      return 'Silakan keluar lalu masuk lagi dengan PIN untuk memposting.';
    }
    try {
      final m = await a.createPost(
          caption: caption,
          bgStyle: bgStyle,
          link: link,
          imageData: imageBase64,
          imageExt: imageExt,
          videoData: videoBase64,
          videoExt: videoExt,
          adminId: asOwner ? currentAdminId : null,
          adminPin: asOwner ? _adminPin : null,
          custPhone: asOwner ? null : profile.phone,
          custPin: asOwner ? null : _custPin);
      posts.insert(0, PromoPost.fromMap(m));
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Tidak bisa terhubung ke server. Coba lagi.';
    }
  }

  Future<void> deletePromo(PromoPost p) async {
    final a = api;
    if (a == null) return;
    try {
      final asOwner = role == 'owner';
      await a.deletePost(p.id,
          adminId: asOwner ? currentAdminId : null,
          adminPin: asOwner ? _adminPin : null,
          custPhone: asOwner ? null : profile.phone,
          custPin: asOwner ? null : _custPin);
      posts.removeWhere((x) => x.id == p.id);
      notifyListeners();
    } catch (_) {
      serverOk = false;
      notifyListeners();
    }
  }

  /// Beri reaksi emoji (pelanggan). Emoji sama dengan reaksi saat ini
  /// = hapus reaksi. Optimistis: UI berubah dulu, dikembalikan bila
  /// server menolak.
  Future<String?> reactPromo(PromoPost p, String emoji) async {
    final a = api;
    if (a == null) return 'Fitur promo membutuhkan server.';
    if (_custPin == null) {
      // Sesi pelanggan lama (dibuat sebelum mode server aktif) tidak
      // punya PIN server — harus masuk ulang.
      return 'Silakan keluar lalu masuk lagi dengan PIN untuk '
          'memberi reaksi.';
    }
    final prevMine = p.myReaction;
    final prevCount = p.reactionCount;
    final removing = prevMine == emoji || emoji.isEmpty;
    p.myReaction = removing ? '' : emoji;
    p.reactionCount = prevCount +
        (removing ? -1 : (prevMine.isEmpty ? 1 : 0));
    notifyListeners();
    try {
      final m = await a.reactPost(p.id, removing ? '' : emoji,
          custPhone: profile.phone, custPin: _custPin);
      _replacePost(p, m);
      return null;
    } on ApiException catch (e) {
      p.myReaction = prevMine;
      p.reactionCount = prevCount;
      notifyListeners();
      return e.message;
    } catch (_) {
      p.myReaction = prevMine;
      p.reactionCount = prevCount;
      notifyListeners();
      return 'Tidak bisa terhubung ke server. Coba lagi.';
    }
  }

  /// Tambah komentar (atau balasan bila [replyTo] diisi) sebagai
  /// pelanggan atau admin. Mengembalikan pesan error, null = sukses.
  Future<String?> addPromoComment(PromoPost p, String text,
      {String replyTo = ''}) async {
    final a = api;
    if (a == null) return 'Fitur promo membutuhkan server.';
    try {
      final asOwner = role == 'owner';
      final m = await a.addPostComment(p.id, text,
          replyTo: replyTo,
          adminId: asOwner ? currentAdminId : null,
          adminPin: asOwner ? _adminPin : null,
          custPhone: asOwner ? null : profile.phone,
          custPin: asOwner ? null : _custPin);
      _replacePost(p, m);
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Tidak bisa terhubung ke server. Coba lagi.';
    }
  }

  Future<void> deletePromoComment(PromoPost p, PromoComment c) async {
    final a = api;
    if (a == null) return;
    try {
      final asOwner = role == 'owner';
      await a.deletePostComment(p.id, c.id,
          adminId: asOwner ? currentAdminId : null,
          adminPin: asOwner ? _adminPin : null,
          custPhone: asOwner ? null : profile.phone,
          custPin: asOwner ? null : _custPin);
      for (final post in posts) {
        if (post.id == p.id) {
          post.comments.removeWhere((x) => x.id == c.id);
        }
      }
      notifyListeners();
    } catch (_) {
      serverOk = false;
      notifyListeners();
    }
  }

  /// Tambah ubin Hiburan (admin). Mengembalikan pesan error/null.
  Future<String?> addHiburan(
      String title, String emoji, String url) async {
    final a = api;
    if (a == null) return 'Fitur ini membutuhkan server.';
    try {
      final m = await a.createHiburan(
          title: title,
          emoji: emoji,
          url: url,
          adminId: currentAdminId,
          adminPin: _adminPin);
      hiburan.add(HiburanTile.fromMap(m));
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Tidak bisa terhubung ke server. Coba lagi.';
    }
  }

  Future<void> deleteHiburan(HiburanTile t) async {
    final a = api;
    if (a == null) return;
    try {
      await a.deleteHiburan(t.id,
          adminId: currentAdminId, adminPin: _adminPin);
      hiburan.removeWhere((x) => x.id == t.id);
      notifyListeners();
    } catch (_) {
      serverOk = false;
      notifyListeners();
    }
  }

  /// Tandai semua notifikasi terbaca (dipanggil saat layar
  /// notifikasi dibuka).
  Future<void> markNotifsRead() async {
    if (unreadNotifs == 0) return;
    for (final n in notifs) {
      n.read = true;
    }
    notifyListeners();
    final a = api;
    if (a == null || _custPin == null) return;
    try {
      await a.markNotifsRead(
          custPhone: profile.phone, custPin: _custPin);
    } catch (_) {}
  }

  // ---- Mode / profil ----

  Future<void> setRole(String? value) async {
    role = value;
    if (value != 'owner') {
      currentAdminId = null;
      _adminPin = null;
    }
    if (value != 'customer') _custPin = null;
    await _save();
    if (online && value != null) await refresh();
  }

  /// Daftar akun pelanggan baru di server. Mengembalikan pesan error
  /// (null bila sukses). errorCode 409 = nomor sudah terdaftar.
  Future<String?> registerCustomer(String name, String phone, String pin,
      {String? idToken}) async {
    final a = api;
    if (a == null) {
      await saveProfile(name, phone, profile.address);
      await setRole('customer');
      return null;
    }
    try {
      final m =
          await a.customerRegister(name, phone, pin, idToken: idToken);
      profile
        ..name = m['name'] as String
        ..phone = m['phone'] as String;
      _custPin = pin;
      await setRole('customer');
      return null;
    } on ApiException catch (e) {
      return e.statusCode == 409 ? 'SUDAH_TERDAFTAR' : e.message;
    } catch (_) {
      return 'Tidak bisa terhubung ke server. Coba lagi.';
    }
  }

  /// Masuk dengan akun pelanggan yang sudah ada.
  Future<String?> loginCustomer(String phone, String pin) async {
    final a = api;
    if (a == null) return null;
    try {
      final m = await a.customerLogin(phone, pin);
      profile
        ..name = m['name'] as String
        ..phone = m['phone'] as String;
      _custPin = pin;
      await setRole('customer');
      return null;
    } on ApiException catch (e) {
      return e.statusCode == 401 ? 'Nomor atau PIN salah.' : e.message;
    } catch (_) {
      return 'Tidak bisa terhubung ke server. Coba lagi.';
    }
  }

  /// Masuk Mode Pemilik sebagai admin tertentu (PIN sudah diverifikasi
  /// oleh pemanggil — lokal dibandingkan, server via /api/admin/login).
  Future<void> loginOwner(AdminUser? admin, {String? pin}) async {
    currentAdminId = admin?.id;
    _adminPin = pin;
    role = 'owner';
    await _save();
    if (online) await refresh();
  }

  Future<void> saveProfile(String name, String phone, String address) async {
    profile
      ..name = name
      ..phone = phone
      ..address = address;
    await _save();
  }

  // ---- Pesanan ----

  /// Buat pesanan baru. Mode server: dikirim ke server (ID dibuat
  /// server); null bila server tidak terjangkau.
  Future<Order?> createOrder({
    required List<OrderItem> items,
    required String name,
    required String phone,
    required DateTime scheduledAt,
    required String notes,
    List<String> contents = const [],
  }) async {
    final a = api;
    if (a != null) {
      try {
        final m = await a.createOrder({
          'items': items.map((e) => e.toMap()).toList(),
          'contents': contents,
          'scheduledAt': scheduledAt.toIso8601String(),
          'notes': notes,
        }, custPhone: profile.phone, custPin: _custPin);
        final order = Order.fromMap(m);
        orders.insert(0, order);
        serverOk = true;
        await _save();
        return order;
      } catch (_) {
        serverOk = false;
        notifyListeners();
        return null;
      }
    }

    final now = DateTime.now();
    final code =
        'H2O-${now.year % 100}${now.month.toString().padLeft(2, '0')}'
        '-${(now.millisecondsSinceEpoch % 10000).toString().padLeft(4, '0')}';
    final order = Order(
      id: code,
      customerName: name,
      phone: phone,
      items: items,
      contents: contents,
      scheduledAt: scheduledAt,
      notes: notes,
      status: OrderStatus.menunggu,
      history: [StatusEntry(OrderStatus.menunggu, now)],
      paid: false,
      createdAt: now,
    );
    orders.insert(0, order);
    await _save();
    return order;
  }

  /// Majukan pesanan ke status berikutnya (dipakai mode pemilik).
  Future<void> advanceStatus(Order order) async {
    final a = api;
    if (a != null) {
      try {
        final m = await a.advanceOrder(order.id,
            adminId: currentAdminId, adminPin: _adminPin);
        _applyOrder(order, m);
        serverOk = true;
        await _save();
      } catch (_) {
        serverOk = false;
        notifyListeners();
      }
      return;
    }
    final i = order.status.index;
    if (i >= OrderStatus.values.length - 1) return;
    order.status = OrderStatus.values[i + 1];
    order.history.add(
        StatusEntry(order.status, DateTime.now(), by: currentAdmin?.name));
    await _save();
  }

  Future<void> setPaid(Order order, bool value) async {
    final a = api;
    if (a != null) {
      try {
        final m = await a.setOrderPaid(order.id, value,
            adminId: currentAdminId, adminPin: _adminPin);
        _applyOrder(order, m);
        serverOk = true;
        await _save();
      } catch (_) {
        serverOk = false;
        notifyListeners();
      }
      return;
    }
    order.paid = value;
    await _save();
  }

  /// Perbarui berat/jumlah satu item setelah ditimbang di counter.
  Future<void> updateItemQty(Order order, OrderItem item, double qty) async {
    final a = api;
    if (a != null) {
      try {
        final m = await a.setItemQty(order.id, order.items.indexOf(item), qty,
            adminId: currentAdminId, adminPin: _adminPin);
        _applyOrder(order, m);
        serverOk = true;
        await _save();
      } catch (_) {
        serverOk = false;
        notifyListeners();
      }
      return;
    }
    item.qty = qty;
    await _save();
  }

  Future<void> deleteOrder(Order order) async {
    final a = api;
    if (a != null) {
      try {
        await a.deleteOrder(order.id,
            adminId: currentAdminId, adminPin: _adminPin);
        serverOk = true;
      } catch (_) {
        serverOk = false;
        notifyListeners();
        return;
      }
    }
    orders.remove(order);
    await _save();
  }

  // ---- Katalog item (dikelola pemilik) ----

  Future<ServiceType?> addService({
    required String name,
    required String unit,
    required double price,
    int estimasiHari = 2,
    String description = '',
  }) async {
    final a = api;
    if (a != null) {
      try {
        final m = await a.createService({
          'name': name,
          'unit': unit,
          'price': price,
          'estimasiHari': estimasiHari,
          'description': description,
        }, adminId: currentAdminId, adminPin: _adminPin);
        final s = ServiceType.fromMap(m);
        services.add(s);
        serverOk = true;
        await _save();
        return s;
      } catch (_) {
        serverOk = false;
        notifyListeners();
        return null;
      }
    }
    final s = ServiceType(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      unit: unit,
      price: price,
      estimasiHari: estimasiHari,
      description: description,
    );
    services.add(s);
    await _save();
    return s;
  }

  Future<void> updateService(
    ServiceType service, {
    String? name,
    String? unit,
    double? price,
    int? estimasiHari,
    String? description,
  }) async {
    final a = api;
    if (a != null) {
      try {
        final m = await a.updateService(service.id, {
          if (name != null && name.isNotEmpty) 'name': name,
          'unit': ?unit,
          if (price != null && price > 0) 'price': price,
          if (estimasiHari != null && estimasiHari > 0)
            'estimasiHari': estimasiHari,
          'description': ?description,
        }, adminId: currentAdminId, adminPin: _adminPin);
        final fresh = ServiceType.fromMap(m);
        service
          ..name = fresh.name
          ..unit = fresh.unit
          ..price = fresh.price
          ..estimasiHari = fresh.estimasiHari
          ..description = fresh.description;
        serverOk = true;
        await _save();
      } catch (_) {
        serverOk = false;
        notifyListeners();
      }
      return;
    }
    if (name != null && name.isNotEmpty) service.name = name;
    if (unit != null) service.unit = unit;
    if (price != null && price > 0) service.price = price;
    if (estimasiHari != null && estimasiHari > 0) {
      service.estimasiHari = estimasiHari;
    }
    if (description != null) service.description = description;
    await _save();
  }

  Future<void> deleteService(ServiceType service) async {
    final a = api;
    if (a != null) {
      try {
        await a.deleteService(service.id,
            adminId: currentAdminId, adminPin: _adminPin);
        serverOk = true;
      } catch (_) {
        serverOk = false;
        notifyListeners();
        return;
      }
    }
    services.remove(service);
    await _save();
  }

  // ---- Admin (Mode Pemilik) ----

  Future<AdminUser?> addAdmin(String name, String pin) async {
    final a = api;
    AdminUser? created;
    if (a != null) {
      try {
        final m = await a.createAdmin(name, pin,
            adminId: currentAdminId, adminPin: _adminPin);
        created =
            AdminUser(id: m['id'] as String, name: m['name'] as String, pin: '');
        serverOk = true;
      } catch (_) {
        serverOk = false;
        notifyListeners();
        return null;
      }
    } else {
      created = AdminUser(
        id: 'admin_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        pin: pin,
      );
    }
    admins.add(created);
    // Admin pertama yang dibuat dari sesi pemilik terbuka langsung
    // menjadi admin aktif, supaya operasi berikutnya tetap sah.
    if (role == 'owner' && currentAdminId == null) {
      currentAdminId = created.id;
      _adminPin = pin;
    }
    await _save();
    return created;
  }

  Future<void> updateAdmin(AdminUser admin, {String? name, String? pin}) async {
    final a = api;
    if (a != null) {
      try {
        await a.updateAdmin(admin.id,
            name: name,
            pin: pin,
            adminId: currentAdminId,
            adminPin: _adminPin);
        serverOk = true;
      } catch (_) {
        serverOk = false;
        notifyListeners();
        return;
      }
    }
    if (name != null && name.isNotEmpty) admin.name = name;
    if (pin != null && pin.isNotEmpty) {
      if (api == null) admin.pin = pin;
      if (admin.id == currentAdminId) _adminPin = pin;
    }
    await _save();
  }

  Future<void> deleteAdmin(AdminUser admin) async {
    final a = api;
    if (a != null) {
      try {
        await a.deleteAdmin(admin.id,
            adminId: currentAdminId, adminPin: _adminPin);
        serverOk = true;
      } catch (_) {
        serverOk = false;
        notifyListeners();
        return;
      }
    }
    admins.remove(admin);
    if (currentAdminId == admin.id) {
      currentAdminId = null;
      _adminPin = null;
    }
    await _save();
  }

  // ---- Ringkasan untuk dashboard/laporan pemilik ----

  List<Order> get activeOrders => orders.where((o) => !o.selesai).toList();

  /// Daftar pelanggan unik (berdasarkan no. HP) dari riwayat pesanan,
  /// terbaru di atas. Dipakai admin untuk kontak dan broadcast.
  List<CustomerSummary> get customers {
    final byPhone = <String, List<Order>>{};
    for (final o in orders) {
      final key = o.phone.replaceAll(RegExp(r'[^0-9]'), '');
      if (key.isEmpty) continue;
      byPhone.putIfAbsent(key, () => []).add(o);
    }
    final result = <CustomerSummary>[];
    for (final list in byPhone.values) {
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      result.add(CustomerSummary(
        name: list.first.customerName,
        phone: list.first.phone,
        orderCount: list.length,
        totalSpent: list.fold(0, (sum, o) => sum + o.total),
        lastOrderAt: list.first.createdAt,
      ));
    }
    result.sort((a, b) => b.lastOrderAt.compareTo(a.lastOrderAt));
    return result;
  }

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

/// Ringkasan satu pelanggan, diagregasi dari riwayat pesanan.
class CustomerSummary {
  CustomerSummary({
    required this.name,
    required this.phone,
    required this.orderCount,
    required this.totalSpent,
    required this.lastOrderAt,
  });

  final String name;
  final String phone;
  final int orderCount;
  final double totalSpent;
  final DateTime lastOrderAt;
}

final store = LaundryStore();
