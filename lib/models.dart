/// Model data untuk aplikasi H2O Laundry Parakan.
library;

/// Alur pesanan layanan di gerai (pelanggan datang ke counter):
/// pesanan dibuat → diterima → diproses → siap diambil → selesai.
/// (Tanpa layanan antar-jemput — "menunggu" = menunggu pelanggan
/// membawa cuciannya ke counter.)
enum OrderStatus { menunggu, diterima, diproses, siap, selesai }

OrderStatus statusFromName(String s) {
  // Data lama memakai nama 'dijemput' untuk status kedua.
  if (s == 'dijemput') return OrderStatus.diterima;
  return OrderStatus.values.byName(s);
}

String statusLabel(OrderStatus status) {
  switch (status) {
    case OrderStatus.menunggu:
      return 'Pesanan Dibuat';
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
  StatusEntry(this.status, this.at, {this.by});

  final OrderStatus status;
  final DateTime at;

  /// Nama admin yang mengubah status ini (null bila tidak diketahui).
  final String? by;

  Map<String, dynamic> toMap() => {
        'status': status.name,
        'at': at.toIso8601String(),
        if (by != null) 'by': by,
      };

  factory StatusEntry.fromMap(Map<String, dynamic> m) => StatusEntry(
        statusFromName(m['status'] as String),
        DateTime.parse(m['at'] as String).toLocal(),
        by: m['by'] as String?,
      );
}

/// Admin yang boleh masuk Mode Pemilik. Selama belum ada admin
/// terdaftar, pintu 7-ketukan terbuka tanpa PIN.
class AdminUser {
  AdminUser({required this.id, required this.name, required this.pin});

  final String id;
  String name;
  String pin;

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'pin': pin};

  factory AdminUser.fromMap(Map<String, dynamic> m) => AdminUser(
        id: m['id'] as String,
        name: m['name'] as String,
        pin: m['pin'] as String,
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
      scheduledAt: DateTime.parse(m['scheduledAt'] as String).toLocal(),
      notes: m['notes'] as String? ?? '',
      status: statusFromName(m['status'] as String),
      history: (m['history'] as List)
          .map((e) =>
              StatusEntry.fromMap((e as Map).cast<String, dynamic>()))
          .toList(),
      paid: m['paid'] as bool? ?? false,
      createdAt: DateTime.parse(m['createdAt'] as String).toLocal(),
    );
  }
}

/// Komentar pada pos Info & Promo.
class PromoComment {
  PromoComment({
    required this.id,
    required this.name,
    required this.text,
    required this.at,
    this.byAdmin = false,
    this.mine = false,
    this.replyTo = '',
    this.replyToName = '',
  });

  final String id;
  final String name;
  final String text;
  final DateTime at;

  /// Komentar ditulis admin (ditandai lencana di UI).
  final bool byAdmin;

  /// Komentar milik pelanggan yang sedang masuk (boleh dihapus).
  final bool mine;

  /// Id komentar induk bila ini balasan ('' = komentar utama).
  final String replyTo;

  /// Nama penulis komentar yang dibalas.
  final String replyToName;

  factory PromoComment.fromMap(Map<String, dynamic> m) => PromoComment(
        id: m['id'] as String,
        name: m['name'] as String? ?? '',
        text: m['text'] as String? ?? '',
        at: DateTime.parse(m['at'] as String).toLocal(),
        byAdmin: m['byAdmin'] as bool? ?? false,
        mine: m['mine'] as bool? ?? false,
        replyTo: m['replyTo'] as String? ?? '',
        replyToName: m['replyToName'] as String? ?? '',
      );
}

/// Jumlah reaksi per emoji pada satu pos, terurut terbanyak.
class ReactionCount {
  ReactionCount(this.emoji, this.count);

  final String emoji;
  final int count;

  factory ReactionCount.fromMap(Map<String, dynamic> m) =>
      ReactionCount(m['emoji'] as String, (m['count'] as num).toInt());
}

/// Pos Info & Promo dari pemilik — feed gaya Mingle (wca_app):
/// teks dengan latar warna atau foto, disukai dan dikomentari pelanggan.
class PromoPost {
  PromoPost({
    required this.id,
    required this.authorName,
    this.byAdmin = true,
    this.mine = false,
    this.authorUid = '',
    this.authorPhoto = '',
    required this.caption,
    required this.bgStyle,
    required this.imageUrl,
    this.videoUrl = '',
    this.videoThumbUrl = '',
    required this.createdAt,
    this.linkUrl = '',
    this.linkTitle = '',
    this.linkHost = '',
    this.linkImage = '',
    required this.reactionCount,
    required this.myReaction,
    this.bookmarkedByMe = false,
    required this.reactions,
    required this.comments,
  });

  final String id;
  final String authorName;

  /// true = pos resmi H2O (admin); false = pos komunitas pelanggan.
  final bool byAdmin;

  /// true = pos milik pengguna yang sedang masuk (boleh dihapus).
  final bool mine;

  /// Uid buram penulis (untuk profil & ikuti); '' bila pos admin.
  final String authorUid;

  /// Foto profil penulis ('' bila belum ada).
  final String authorPhoto;
  final String caption;

  /// Kunci latar pos teks berwarna ('' = polos). Lihat PromoBg.
  final String bgStyle;

  /// Jalur foto relatif server ('/uploads/..'), '' bila tanpa foto.
  final String imageUrl;

  /// Jalur video reel relatif server ('' = bukan pos video).
  final String videoUrl;

  /// Thumbnail video buatan server (ffmpeg); '' bila tidak ada.
  final String videoThumbUrl;
  final DateTime createdAt;

  /// Tautan yang dilampirkan ('' = tanpa tautan). Kartu tautan
  /// menampilkan gambar unggulan + judul dan bisa diketuk.
  final String linkUrl;
  final String linkTitle;
  final String linkHost;

  /// Gambar unggulan tautan (og:image) yang di-cache server.
  final String linkImage;

  /// Total reaksi dan reaksi milik pengguna yang masuk ('' = belum).
  int reactionCount;
  String myReaction;

  /// Pos ini tersimpan (bookmark) oleh pengguna yang masuk.
  bool bookmarkedByMe;

  /// Ringkasan reaksi per emoji, terurut terbanyak.
  List<ReactionCount> reactions;
  final List<PromoComment> comments;

  factory PromoPost.fromMap(Map<String, dynamic> m) => PromoPost(
        id: m['id'] as String,
        authorName: m['authorName'] as String? ?? 'H2O Laundry',
        byAdmin: m['byAdmin'] as bool? ?? true,
        mine: m['mine'] as bool? ?? false,
        authorUid: m['authorUid'] as String? ?? '',
        authorPhoto: m['authorPhoto'] as String? ?? '',
        caption: m['caption'] as String? ?? '',
        bgStyle: m['bgStyle'] as String? ?? '',
        imageUrl: m['imageUrl'] as String? ?? '',
        videoUrl: m['videoUrl'] as String? ?? '',
        videoThumbUrl: m['videoThumbUrl'] as String? ?? '',
        createdAt: DateTime.parse(m['createdAt'] as String).toLocal(),
        linkUrl: m['linkUrl'] as String? ?? '',
        linkTitle: m['linkTitle'] as String? ?? '',
        linkHost: m['linkHost'] as String? ?? '',
        linkImage: m['linkImage'] as String? ?? '',
        reactionCount:
            (m['reactionCount'] as num? ?? m['likeCount'] as num? ?? 0)
                .toInt(),
        myReaction: m['myReaction'] as String? ??
            ((m['likedByMe'] as bool? ?? false) ? '❤️' : ''),
        bookmarkedByMe: m['bookmarkedByMe'] as bool? ?? false,
        reactions: (m['reactions'] as List? ?? [])
            .map((e) =>
                ReactionCount.fromMap((e as Map).cast<String, dynamic>()))
            .toList(),
        comments: (m['comments'] as List? ?? [])
            .map((e) =>
                PromoComment.fromMap((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}

/// Notifikasi dalam-aplikasi untuk pelanggan (status pesanan,
/// reaksi/komentar pada postingan, promo baru).
class AppNotif {
  AppNotif({
    required this.id,
    required this.type,
    required this.text,
    required this.at,
    required this.read,
    this.postId = '',
    this.orderId = '',
  });

  final String id;

  /// 'order' | 'react' | 'comment' | 'reply' | 'promo'
  final String type;
  final String text;
  final DateTime at;
  bool read;
  final String postId;
  final String orderId;

  factory AppNotif.fromMap(Map<String, dynamic> m) => AppNotif(
        id: m['id'] as String,
        type: m['type'] as String? ?? 'order',
        text: m['text'] as String? ?? '',
        at: DateTime.parse(m['at'] as String).toLocal(),
        read: m['read'] as bool? ?? false,
        postId: m['postId'] as String? ?? '',
        orderId: m['orderId'] as String? ?? '',
      );
}

/// Info toko untuk layar "Tentang H2O Laundry" (diedit pemilik).
class AboutInfo {
  AboutInfo({
    this.name = 'H2O Laundry Parakan',
    this.tagline = 'Laundry bersih, wangi, dan rapi',
    this.address = 'Parakan, Temanggung, Jawa Tengah',
    this.wa = '',
    this.hours = '',
    this.maps = '',
    this.instagram = '',
  });

  String name;
  String tagline;
  String address;
  String wa;
  String hours;
  String maps;
  String instagram;

  factory AboutInfo.fromMap(Map<String, dynamic> m) => AboutInfo(
        name: m['name'] as String? ?? 'H2O Laundry Parakan',
        tagline: m['tagline'] as String? ?? '',
        address: m['address'] as String? ?? '',
        wa: m['wa'] as String? ?? '',
        hours: m['hours'] as String? ?? '',
        maps: m['maps'] as String? ?? '',
        instagram: m['instagram'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'tagline': tagline,
        'address': address,
        'wa': wa,
        'hours': hours,
        'maps': maps,
        'instagram': instagram,
      };
}

/// Pesan chat Layanan Pelanggan (pelanggan <-> admin).
class ChatMessage {
  ChatMessage({
    required this.id,
    required this.phone,
    required this.name,
    required this.fromAdmin,
    required this.adminName,
    required this.text,
    required this.at,
    required this.readByCust,
    required this.readByAdmin,
  });

  final String id;
  final String phone;
  final String name;
  final bool fromAdmin;
  final String adminName;
  final String text;
  final DateTime at;
  bool readByCust;
  bool readByAdmin;

  factory ChatMessage.fromMap(Map<String, dynamic> m) => ChatMessage(
        id: m['id'] as String,
        phone: m['phone'] as String? ?? '',
        name: m['name'] as String? ?? '',
        fromAdmin: m['fromAdmin'] as bool? ?? false,
        adminName: m['adminName'] as String? ?? '',
        text: m['text'] as String? ?? '',
        at: DateTime.parse(m['at'] as String).toLocal(),
        readByCust: m['readByCust'] as bool? ?? false,
        readByAdmin: m['readByAdmin'] as bool? ?? false,
      );
}

/// Ubin Hiburan (musik, game, dll) — dikelola admin, tampil di
/// Beranda pelanggan, membuka tautan saat diketuk.
class HiburanTile {
  HiburanTile({
    required this.id,
    required this.title,
    required this.emoji,
    required this.url,
  });

  final String id;
  final String title;
  final String emoji;
  final String url;

  factory HiburanTile.fromMap(Map<String, dynamic> m) => HiburanTile(
        id: m['id'] as String,
        title: m['title'] as String? ?? '',
        emoji: m['emoji'] as String? ?? '🎮',
        url: m['url'] as String? ?? '',
      );
}

/// Profil sosial saya di server (uid, foto, mengikuti/pengikut).
class MeInfo {
  MeInfo({
    required this.uid,
    required this.photoUrl,
    required this.following,
    required this.followers,
    required this.isPrivate,
  });

  final String uid;
  String photoUrl;
  final List<String> following;
  int followers;
  bool isPrivate;

  factory MeInfo.fromMap(Map<String, dynamic> m) => MeInfo(
        uid: m['uid'] as String? ?? '',
        photoUrl: m['photoUrl'] as String? ?? '',
        following: ((m['following'] as List?) ?? [])
            .map((e) => e.toString())
            .toList(),
        followers: (m['followers'] as num? ?? 0).toInt(),
        isPrivate: m['isPrivate'] as bool? ?? false,
      );
}

/// Profil publik pengguna lain (untuk layar profil & tombol ikuti).
class UserInfo {
  UserInfo({
    required this.uid,
    required this.name,
    required this.photoUrl,
    required this.followers,
    required this.following,
    required this.followedByMe,
    required this.isPrivate,
  });

  final String uid;
  final String name;
  final String photoUrl;
  int followers;
  final int following;
  bool followedByMe;
  final bool isPrivate;

  factory UserInfo.fromMap(Map<String, dynamic> m) => UserInfo(
        uid: m['uid'] as String? ?? '',
        name: m['name'] as String? ?? '',
        photoUrl: m['photoUrl'] as String? ?? '',
        followers: (m['followers'] as num? ?? 0).toInt(),
        following: (m['following'] as num? ?? 0).toInt(),
        followedByMe: m['followedByMe'] as bool? ?? false,
        isPrivate: m['isPrivate'] as bool? ?? false,
      );
}

/// Ringkasan pengguna untuk daftar pengikut/mengikuti.
class MiniUser {
  MiniUser({required this.uid, required this.name, required this.photoUrl});

  final String uid;
  final String name;
  final String photoUrl;

  factory MiniUser.fromMap(Map<String, dynamic> m) => MiniUser(
        uid: m['uid'] as String? ?? '',
        name: m['name'] as String? ?? '',
        photoUrl: m['photoUrl'] as String? ?? '',
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
    ];
