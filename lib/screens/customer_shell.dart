import 'dart:async';
import 'dart:convert' show base64Encode;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../format.dart';
import '../models.dart';
import '../pwa/pwa.dart';
import '../store.dart';
import '../widgets.dart';
import 'new_order_screen.dart';
import 'order_detail_screen.dart';
import 'chat_screen.dart';
import 'hiburan.dart';
import 'hiburan_ext/games_hub_screen.dart';
import 'hiburan_ext/music_screen.dart';
import 'owner_access.dart';
import 'promo.dart';
import 'tentang_screen.dart';
import 'user_profile_screen.dart';

class CustomerShell extends StatefulWidget {
  const CustomerShell({super.key});

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  int _index = 0;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    store.refresh();
    _poll = Timer.periodic(
        const Duration(seconds: 30), (_) => store.refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              // Sengaja TANPA const: instance const dianggap identik oleh
              // Flutter sehingga tab tidak ikut rebuild saat data store
              // berubah (mis. jumlah reaksi promo).
              child: switch (_index) {
                0 => _HomeTab(),
                1 => _OrdersTab(history: false),
                2 => _KomunitasTab(),
                _ => _ProfileTab(
                    onOpenOrders: () => setState(() => _index = 1)),
              },
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          tooltip: 'Buat Postingan',
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const PromoComposeScreen())),
          shape: const CircleBorder(),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          child: const Icon(Icons.add, size: 30),
        ),
        floatingActionButtonLocation:
            FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: BottomAppBar(
          shape: const CircularNotchedRectangle(),
          notchMargin: 8,
          color: Colors.white,
          elevation: 12,
          height: 62,
          padding: EdgeInsets.zero,
          child: Row(
            children: [
              NavIcon(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  label: 'Beranda',
                  selected: _index == 0,
                  onTap: () => setState(() => _index = 0)),
              NavIcon(
                  icon: Icons.receipt_long_outlined,
                  activeIcon: Icons.receipt_long,
                  label: 'Pesanan',
                  selected: _index == 1,
                  onTap: () => setState(() => _index = 1)),
              const SizedBox(width: 72),
              NavIcon(
                  icon: Icons.groups_outlined,
                  activeIcon: Icons.groups,
                  label: 'Komunitas',
                  selected: _index == 2,
                  onTap: () => setState(() => _index = 2)),
              NavIcon(
                  icon: Icons.person_outline,
                  activeIcon: Icons.person,
                  label: 'Profil',
                  selected: _index == 3,
                  onTap: () => setState(() => _index = 3)),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Beranda

class _HomeTab extends StatefulWidget {
  const _HomeTab();

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  final _secretTaps = SecretTapCounter();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = store.profile.name;
    Order? active;
    for (final o in store.orders) {
      if (!o.selesai) {
        active = o;
        break;
      }
    }

    return ListView(
      // Bawah 96: memberi ruang tombol + tengah agar tidak menutupi
      // ubin Hiburan di ujung halaman.
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: BrandHeader(
                onLogoTap: () {
                  if (_secretTaps.registerTap(context)) {
                    enterOwnerMode(context);
                  }
                },
              ),
            ),
            if (store.online) ...[
              Badge.count(
                count: store.chatUnread,
                isLabelVisible: store.chatUnread > 0,
                child: IconButton.filledTonal(
                  tooltip: 'Layanan Pelanggan',
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) =>
                              const LayananPelangganScreen())),
                  icon: const Icon(Icons.support_agent),
                ),
              ),
              const SizedBox(width: 8),
              Badge.count(
                count: store.unreadNotifs,
                isLabelVisible: store.unreadNotifs > 0,
                child: IconButton.filledTonal(
                  tooltip: 'Notifikasi',
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const NotificationsScreen())),
                  icon: const Icon(Icons.notifications_outlined),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 18),
        const ServerOfflineBanner(),
        Text(
          name.isEmpty ? 'Halo! 👋' : 'Halo, ${name.split(' ').first}! 👋',
          style: theme.textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text('Mau cuci apa hari ini?',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 16),
        if (active != null) ...[
          _ActiveOrderCard(order: active),
          const SizedBox(height: 20),
        ] else ...[
          _PromoBanner(theme: theme),
          const SizedBox(height: 20),
        ],
        const SectionTitle('Layanan Kami'),
        GridView.count(
          crossAxisCount: MediaQuery.sizeOf(context).width > 560 ? 3 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.15,
          children: [
            for (final s in store.services) _ServiceCard(service: s),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: Icon(Icons.storefront,
                color: theme.colorScheme.primary),
            title: const Text('Langsung di Counter',
                style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text(
                'Antar dan ambil cucian Anda langsung di counter H2O Laundry Parakan.'),
          ),
        ),
        // Pil "Chat Sekarang" — akses cepat ke Layanan Pelanggan.
        if (store.online) ...[
          const SizedBox(height: 12),
          _ChatPelangganBanner(unread: store.chatUnread),
        ],
        // Ajakan pasang aplikasi — hanya di web yang belum terpasang
        // (di aplikasi Android / PWA terpasang otomatis tersembunyi).
        if (kIsWeb && !pwaIsStandalone()) ...[
          const SizedBox(height: 12),
          const _DownloadAppBanner(),
        ],
        // Info & Promo: banner korsel khusus pos resmi (admin).
        if (store.posts.any((p) => p.byAdmin)) ...[
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(child: SectionTitle('Info & Promo')),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const PromoFeedScreen())),
                child: const Text('Lihat Semua'),
              ),
            ],
          ),
          const PromoBannerCarousel(),
        ],
        // Hiburan: ubin tautan (musik, game, dll) kelolaan admin.
        const HiburanSection(),
      ],
    );
  }
}

/// Pil ungu "Download Aplikasi": memicu dialog install PWA (atau
/// panduan manual bila browser belum siap). Kembaran gaya pil chat.
/// Otomatis hilang bila PWA terdeteksi sudah terpasang di perangkat.
class _DownloadAppBanner extends StatefulWidget {
  const _DownloadAppBanner();

  @override
  State<_DownloadAppBanner> createState() => _DownloadAppBannerState();
}

class _DownloadAppBannerState extends State<_DownloadAppBanner> {
  bool _installed = false;

  @override
  void initState() {
    super.initState();
    pwaIsInstalled().then((v) {
      if (mounted && v) setState(() => _installed = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_installed) return const SizedBox.shrink();
    return InkWell(
      onTap: () => attemptPwaInstall(context),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF7C3AED), Color(0xFFA855F7)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        child: const Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('DOWNLOAD APLIKASI',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4)),
                  SizedBox(height: 2),
                  Text('Pasang di layar utama HP — gratis & ringan 📲',
                      style: TextStyle(
                          color: Colors.white70, fontSize: 11.5)),
                ],
              ),
            ),
            SizedBox(width: 10),
            CircleAvatar(
              radius: 23,
              backgroundColor: Colors.white,
              child: Icon(Icons.install_mobile,
                  size: 26, color: Color(0xFF7C3AED)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Alur pasang PWA satu-ketuk: coba dialog otomatis Chrome dulu;
/// kalau eventnya telat, tunggu sebentar (permintaan diantre di JS
/// dan prompt muncul sendiri); baru terakhir jatuh ke panduan singkat.
Future<void> attemptPwaInstall(BuildContext context) async {
  if (pwaTriggerInstall()) return; // dialog Chrome langsung tampil
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(const SnackBar(
      duration: Duration(seconds: 3),
      content: Text('Menyiapkan pemasangan...')));
  await Future<void>.delayed(const Duration(seconds: 3));
  // Event datang saat menunggu? Prompt sudah tampil otomatis.
  if (pwaDidPrompt()) return;
  if (await pwaIsInstalled()) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(const SnackBar(
        content: Text('Aplikasi sudah terpasang — buka "H2O Laundry" '
            'dari layar utama HP Anda 👍')));
    return;
  }
  if (context.mounted) showInstallHelp(context);
}

/// Panduan install manual — jalan terakhir bila dialog otomatis
/// benar-benar tidak tersedia (mis. iPhone/Safari).
void showInstallHelp(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Pasang Manual (30 detik)'),
      content: const Text(
        'Android: menu ⋮ Chrome → "Tambahkan ke layar utama".\n\n'
        'iPhone: tombol Bagikan → "Tambah ke Layar Utama".',
        style: TextStyle(fontSize: 14, height: 1.5),
      ),
      actions: [
        FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Mengerti')),
      ],
    ),
  );
}

/// Pil biru "Chat Layanan Pelanggan Sekarang" bergaya tombol chat
/// dokter di aplikasi apotek: avatar admin + ajakan chat.
class _ChatPelangganBanner extends StatelessWidget {
  const _ChatPelangganBanner({required this.unread});

  final int unread;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const LayananPelangganScreen())),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CHAT LAYANAN PELANGGAN',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4)),
                  SizedBox(height: 2),
                  Text('Ada pertanyaan? Kami siap membantu 👋',
                      style: TextStyle(
                          color: Colors.white70, fontSize: 11.5)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Badge.count(
              count: unread,
              isLabelVisible: unread > 0,
              child: const CircleAvatar(
                radius: 23,
                backgroundColor: Colors.white,
                child: Icon(Icons.support_agent,
                    size: 28, color: Color(0xFF2563EB)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromoBanner extends StatelessWidget {
  const _PromoBanner({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF06B6D4), Color(0xFF0E7490)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cucian numpuk?',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pesan sekarang, bawa ke counter, kami kerjakan cepat.',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13),
                ),
              ],
            ),
          ),
          const Icon(Icons.local_laundry_service,
              color: Colors.white, size: 48),
        ],
      ),
    );
  }
}

class _ActiveOrderCard extends StatelessWidget {
  const _ActiveOrderCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress =
        (order.status.index + 1) / OrderStatus.values.length;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => OrderDetailScreen(order: order))),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Pesanan Aktif • ${order.id}',
                        style: theme.textTheme.bodySmall),
                  ),
                  StatusChip(order: order),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                order.itemsBrief,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  color: statusColor(order.status),
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 8),
              Text('Ketuk untuk lacak pesanan',
                  style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.service});

  final ServiceType service;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => NewOrderScreen(initialService: service))),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(serviceIcon(service.id),
                    size: 22, color: theme.colorScheme.onPrimaryContainer),
              ),
              const Spacer(),
              Text(service.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13.5)),
              const SizedBox(height: 2),
              Text(
                '${rupiah(service.price)}/${service.unit}',
                style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5),
              ),
              Text('Estimasi ${service.estimasiHari} hari',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Pesanan

class _OrdersTab extends StatelessWidget {
  const _OrdersTab({required this.history});

  final bool history;

  @override
  Widget build(BuildContext context) {
    final orders =
        store.orders.where((o) => history ? o.selesai : !o.selesai).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(history ? 'Riwayat' : 'Pesanan Saya',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
              ),
              if (!history)
                FilledButton.tonalIcon(
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const NewOrderScreen())),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Buat Pesanan'),
                ),
            ],
          ),
        ),
        Expanded(
          child: orders.isEmpty
              ? EmptyState(
                  icon: history
                      ? Icons.history_outlined
                      : Icons.receipt_long_outlined,
                  message: history
                      ? 'Belum ada pesanan yang selesai.'
                      : 'Belum ada pesanan aktif.\nKetuk "Buat Pesanan" untuk memesan!',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  itemCount: orders.length,
                  itemBuilder: (context, i) => OrderCard(
                    order: orders[i],
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) =>
                              OrderDetailScreen(order: orders[i])),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

// -------------------------------------------------------------- Komunitas

/// Tab Komunitas: feed semua postingan (promo resmi + kiriman
/// pelanggan). Foto tampil langsung, video dibuka di layar Reels,
/// tombol + di tengah untuk menambah foto/video — gaya wca_app.
class _KomunitasTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 2),
          child: Text('Komunitas',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: !store.online
              ? const EmptyState(
                  icon: Icons.groups_outlined,
                  message: 'Komunitas membutuhkan koneksi ke server.')
              : RefreshIndicator(
                  onRefresh: () async => store.refresh(),
                  child: store.posts.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 100),
                            EmptyState(
                                icon: Icons.groups_outlined,
                                message:
                                    'Belum ada postingan. Jadilah yang '
                                    'pertama — ketuk tombol +!'),
                          ],
                        )
                      : Builder(builder: (context) {
                          // Susunan gaya Facebook: baris cerita di atas,
                          // lalu feed cuit dengan blok Reels terselip
                          // setelah beberapa pos.
                          final items = <Widget>[const StoriesRow()];
                          final posts = store.posts;
                          for (var i = 0; i < posts.length; i++) {
                            items.add(PromoCard(
                                post: posts[i], cuit: true));
                            if (i == 1) items.add(const ReelsBlock());
                          }
                          if (posts.length == 1) {
                            items.add(const ReelsBlock());
                          }
                          return ListView.builder(
                            padding:
                                const EdgeInsets.only(top: 4, bottom: 80),
                            itemCount: items.length,
                            itemBuilder: (context, i) => items[i],
                          );
                        }),
                ),
        ),
      ],
    );
  }
}

/// Riwayat pesanan selesai — dipindah dari bilah navigasi ke menu
/// pengaturan di Profil.
class RiwayatScreen extends StatelessWidget {
  const RiwayatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Pesanan')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) => _OrdersTab(history: true),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------- Notifikasi

/// Daftar notifikasi pelanggan: status pesanan, reaksi/komentar pada
/// postingan, dan promo baru. Terbuka = semua ditandai terbaca.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Tandai terbaca setelah layar tampil (badge langsung bersih).
    WidgetsBinding.instance
        .addPostFrameCallback((_) => store.markNotifsRead());
  }

  IconData _iconFor(String type) => switch (type) {
        'order' => Icons.local_laundry_service,
        'react' => Icons.favorite,
        'comment' => Icons.mode_comment,
        'reply' => Icons.reply,
        'promo' => Icons.campaign,
        'follow' => Icons.person_add_alt,
        'chat' => Icons.support_agent,
        _ => Icons.notifications,
      };

  Color _colorFor(String type) => switch (type) {
        'order' => const Color(0xFF0E7490),
        'react' => const Color(0xFFE0245E),
        'comment' || 'reply' => const Color(0xFF2563EB),
        'promo' => const Color(0xFFD97706),
        'follow' => const Color(0xFFDB2777),
        'chat' => const Color(0xFF2563EB),
        _ => const Color(0xFF64748B),
      };

  void _open(AppNotif n) {
    if (n.type == 'chat') {
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const LayananPelangganScreen()));
      return;
    }
    if (n.orderId.isNotEmpty) {
      for (final o in store.orders) {
        if (o.id == n.orderId) {
          Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => OrderDetailScreen(order: o)));
          return;
        }
      }
    }
    if (n.postId.isNotEmpty &&
        store.posts.any((p) => p.id == n.postId)) {
      showPromoComments(context, n.postId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Notifikasi')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) => RefreshIndicator(
            onRefresh: () async => store.refresh(),
            child: store.notifs.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 120),
                      EmptyState(
                          icon: Icons.notifications_none,
                          message: 'Belum ada notifikasi.'),
                    ],
                  )
                : ListView.separated(
                    itemCount: store.notifs.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, indent: 68),
                    itemBuilder: (context, i) {
                      final n = store.notifs[i];
                      return ListTile(
                        tileColor: n.read
                            ? null
                            : const Color(0xFFE9F6FA),
                        leading: CircleAvatar(
                          radius: 19,
                          backgroundColor:
                              _colorFor(n.type).withValues(alpha: 0.12),
                          child: Icon(_iconFor(n.type),
                              size: 19, color: _colorFor(n.type)),
                        ),
                        title: Text(n.text,
                            style: TextStyle(
                                fontSize: 13.5,
                                height: 1.3,
                                fontWeight: n.read
                                    ? FontWeight.w500
                                    : FontWeight.w700)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(timeAgo(n.at),
                              style: theme.textTheme.bodySmall),
                        ),
                        onTap: () => _open(n),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Profil

class _ProfileTab extends StatefulWidget {
  const _ProfileTab({required this.onOpenOrders});

  /// Pindah ke tab Pesanan (dipanggil saat statistik Pesanan diketuk).
  final VoidCallback onOpenOrders;

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  /// 0 = Video saya, 1 = Disimpan, 2 = Disukai.
  int _collection = 0;

  Future<void> _changePhoto() async {
    final x = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 512, imageQuality: 80);
    if (x == null) return;
    final b64 = base64Encode(await x.readAsBytes());
    final name = x.name.toLowerCase();
    final ext = name.endsWith('.png')
        ? 'png'
        : name.endsWith('.webp')
            ? 'webp'
            : 'jpg';
    final err = await store.uploadProfilePhoto(b64, ext);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err ?? 'Foto profil diperbarui ✅')));
  }

  /// Menu utama profil (gaya wca_app): lembar bawah berisi pengaturan.
  void _openMenu() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        final cs = Theme.of(sheetCtx).colorScheme;
        // Catatan: jangan pakai ListTileTheme.titleTextStyle di sini —
        // gaya itu mengganti fontFamily tema dan pada build web tanpa
        // CDN membuat teks menu tak tergambar.
        const tStyle =
            TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700);
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('Menu',
                              style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: cs.onSurface)),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: cs.onSurface),
                          onPressed: () => Navigator.pop(sheetCtx),
                        ),
                      ],
                    ),
                  ),
                  if (store.online) ...[
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.support_agent),
                      title: const Text('Layanan Pelanggan', style: tStyle),
                      subtitle: const Text('Chat langsung dengan admin'),
                      onTap: () {
                        Navigator.pop(sheetCtx);
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) =>
                                const LayananPelangganScreen()));
                      },
                    ),
                  ],
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.history_outlined),
                    title: const Text('Riwayat Pesanan', style: tStyle),
                    subtitle: const Text('Pesanan yang sudah selesai'),
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const RiwayatScreen()));
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: const Text('Ubah Profil', style: tStyle),
                    subtitle: const Text('Nama, no. HP, dan alamat'),
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      _editProfile(context);
                    },
                  ),
                  if (store.online) ...[
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.photo_camera_outlined),
                      title: const Text('Ganti Foto Profil', style: tStyle),
                      onTap: () {
                        Navigator.pop(sheetCtx);
                        _changePhoto();
                      },
                    ),
                    const Divider(height: 1),
                    // Privasi: profil privat menyembunyikan postingan &
                    // daftar pengikut dari pelanggan lain.
                    ListenableBuilder(
                      listenable: store,
                      builder: (context, _) => SwitchListTile(
                        secondary: const Icon(Icons.lock_outline),
                        title: const Text('Profil Privat', style: tStyle),
                        subtitle: const Text(
                            'Sembunyikan postingan & pengikut dari '
                            'pelanggan lain'),
                        value: store.me?.isPrivate ?? false,
                        onChanged: (v) async {
                          final err = await store.setPrivacy(v);
                          if (err != null && sheetCtx.mounted) {
                            ScaffoldMessenger.of(sheetCtx).showSnackBar(
                                SnackBar(content: Text(err)));
                          }
                        },
                      ),
                    ),
                  ],
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.videogame_asset_outlined),
                    title: const Text('Game', style: tStyle),
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const GamesHubScreen()));
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.music_note_outlined),
                    title: const Text('Musik', style: tStyle),
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const MusicScreen()));
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title:
                        const Text('Tentang H2O Laundry', style: tStyle),
                    subtitle: const Text('Alamat, jam buka, dan kontak'),
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const TentangScreen()));
                    },
                  ),
                  // Install PWA: banner Chrome sering tidak muncul
                  // sendiri, jadi sediakan pemicu manual di sini.
                  if (kIsWeb && !pwaIsStandalone()) ...[
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.install_mobile),
                      title: const Text('Install Aplikasi', style: tStyle),
                      subtitle:
                          const Text('Pasang di layar utama HP Anda'),
                      onTap: () {
                        Navigator.pop(sheetCtx);
                        attemptPwaInstall(context);
                      },
                    ),
                  ],
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.logout, color: cs.error),
                    title: Text('Keluar',
                        style: tStyle.copyWith(color: cs.error)),
                    subtitle:
                        const Text('Keluar dari akun di perangkat ini'),
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      _confirmLogout(context);
                    },
                  ),
                  const SizedBox(height: 8),
                ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar?'),
        content: const Text('Anda akan keluar dari akun pelanggan. '
            'Riwayat pesanan tetap tersimpan di perangkat ini.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (yes == true) await store.setRole(null);
  }

  /// Lembar ubah profil. Mode server: no. HP terkunci karena menjadi
  /// identitas akun di server.
  Future<void> _editProfile(BuildContext context) async {
    final name = TextEditingController(text: store.profile.name);
    final phone = TextEditingController(text: store.profile.phone);
    final address = TextEditingController(text: store.profile.address);
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      // SafeArea: tombol Simpan jangan tertutup bilah navigasi sistem.
      builder: (sheet) => SafeArea(
        top: false,
        child: Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, 20 + MediaQuery.of(sheet).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Ubah Profil',
                textAlign: TextAlign.center,
                style: Theme.of(sheet)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 18),
            TextField(
              controller: name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                  labelText: 'Nama',
                  prefixIcon: Icon(Icons.person_outline)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              readOnly: store.online,
              decoration: InputDecoration(
                labelText: 'No. HP / WhatsApp',
                prefixIcon: const Icon(Icons.phone_outlined),
                helperText: store.online
                    ? 'Nomor terhubung ke akun dan tidak bisa diubah'
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: address,
              maxLines: 2,
              decoration: const InputDecoration(
                  labelText: 'Alamat',
                  prefixIcon: Icon(Icons.location_on_outlined)),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => Navigator.pop(sheet, true),
              icon: const Icon(Icons.save_outlined),
              label: const Text('Simpan'),
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ],
        ),
        ),
      ),
    );
    if (saved == true) {
      await store.saveProfile(
          name.text.trim(), phone.text.trim(), address.text.trim());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profil tersimpan')));
      }
    }
  }

  void _openFollowList(bool followers) {
    final uid = store.me?.uid ?? '';
    if (uid.isEmpty) return;
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => FollowListScreen(uid: uid, followers: followers)));
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    return parts.take(2).map((w) => w[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = store.profile;
    final orders = store.orders;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Profil Saya',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
            ),
            IconButton.filledTonal(
              tooltip: 'Menu',
              icon: const Icon(Icons.menu),
              onPressed: _openMenu,
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Kartu profil bergradasi gaya wca_app.
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF06B6D4), Color(0xFF0B4F6C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      if (store.me?.photoUrl.isNotEmpty ?? false)
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: Colors.white24,
                          backgroundImage: NetworkImage(
                              store.mediaUrl(store.me!.photoUrl)),
                        )
                      else
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: Colors.white24,
                          child: Text(
                            _initials(p.name),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800),
                          ),
                        ),
                      if (store.online)
                        Positioned(
                          right: -4,
                          bottom: -4,
                          child: InkWell(
                            onTap: _changePhoto,
                            borderRadius: BorderRadius.circular(999),
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.photo_camera,
                                  size: 14, color: Color(0xFF0E7490)),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.name.isEmpty ? 'Pelanggan' : p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          p.phone.isEmpty
                              ? 'Nomor belum diisi'
                              : '+${waPhone(p.phone)}',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Pelanggan H2O',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Ubah Profil',
                    onPressed: () => _editProfile(context),
                    icon: const Icon(Icons.edit_outlined,
                        color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    _HeaderStat(
                        label: 'Pengikut',
                        value: '${store.me?.followers ?? 0}',
                        onTap: () => _openFollowList(true)),
                    _statDivider(),
                    _HeaderStat(
                        label: 'Mengikuti',
                        value: '${store.me?.following.length ?? 0}',
                        onTap: () => _openFollowList(false)),
                    _statDivider(),
                    _HeaderStat(
                        label: 'Pesanan',
                        value: '${orders.length}',
                        onTap: widget.onOpenOrders),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (store.online) ...[
          const SizedBox(height: 16),
          // Hanya ikon (tanpa teks) supaya tidak terpotong di layar
          // sempit — gaya strip tab profil TikTok/wca_app.
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                  value: 0,
                  tooltip: 'Video saya',
                  icon: Icon(Icons.movie_outlined, size: 22)),
              ButtonSegment(
                  value: 1,
                  tooltip: 'Disimpan',
                  icon: Icon(Icons.bookmark_border, size: 22)),
              ButtonSegment(
                  value: 2,
                  tooltip: 'Disukai',
                  icon: Icon(Icons.favorite_border, size: 22)),
            ],
            selected: {_collection},
            onSelectionChanged: (v) =>
                setState(() => _collection = v.first),
          ),
          const SizedBox(height: 10),
          PostMiniGrid(
            posts: switch (_collection) {
              0 => store.posts
                  .where((x) => x.mine && x.videoUrl.isNotEmpty)
                  .toList(),
              1 => store.posts.where((x) => x.bookmarkedByMe).toList(),
              _ => store.posts
                  .where((x) => x.myReaction.isNotEmpty)
                  .toList(),
            },
            emptyText: switch (_collection) {
              0 => 'Belum ada video. Ketuk + lalu pilih Video Reel!',
              1 => 'Belum ada yang disimpan. Ketuk ikon 🔖 di postingan.',
              _ => 'Belum ada yang disukai. Beri reaksi di Komunitas!',
            },
          ),
        ],
        const SizedBox(height: 20),
        Center(
          child: Text('H2O Laundry Parakan v1.0',
              style: theme.textTheme.bodySmall),
        ),
      ],
    );
  }

  Widget _statDivider() => Container(
        width: 1,
        height: 30,
        color: Colors.white24,
      );
}

/// Satu angka statistik di kartu profil (teks putih di atas gradasi).
/// Bisa diketuk: Pengikut/Mengikuti membuka daftarnya, Pesanan pindah
/// ke tab Pesanan.
class _HeaderStat extends StatelessWidget {
  const _HeaderStat(
      {required this.label, required this.value, this.onTap});

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
        ),
      ),
    );
  }
}
