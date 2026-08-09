import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tideview/format.dart';
import 'package:tideview/models.dart';
import 'package:tideview/receipt.dart';
import 'package:tideview/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('format rupiah dan qty', () {
    expect(rupiah(7000), 'Rp 7.000');
    expect(rupiah(1250000), 'Rp 1.250.000');
    expect(rupiah(0), 'Rp 0');
    expect(qtyText(2.5, 'kg'), '2,5 kg');
    expect(qtyText(3, 'pcs'), '3 pcs');
  });

  test('alur pesanan multi-item: buat, majukan status, bayar', () async {
    SharedPreferences.setMockInitialValues({});
    final s = LaundryStore();
    await s.init();
    expect(s.services, isNotEmpty);

    final kiloan = s.serviceById('cuci_setrika')!;
    final selimut = s.serviceById('selimut')!;
    final order = s.createOrder(
      items: [
        OrderItem(
            serviceId: kiloan.id,
            name: kiloan.name,
            unit: kiloan.unit,
            price: kiloan.price,
            qty: 3),
        OrderItem(
            serviceId: selimut.id,
            name: selimut.name,
            unit: selimut.unit,
            price: selimut.price,
            qty: 1),
      ],
      contents: ['Kaos', 'Kemeja', 'Handuk'],
      name: 'Budi',
      phone: '0812',
      scheduledAt: DateTime.now(),
      notes: '',
    );

    expect(order.total, kiloan.price * 3 + selimut.price);
    expect(order.contents, ['Kaos', 'Kemeja', 'Handuk']);
    expect(order.status, OrderStatus.menunggu);
    expect(s.activeOrders.length, 1);

    // Majukan sampai selesai.
    for (var i = 0; i < 4; i++) {
      await s.advanceStatus(order);
    }
    expect(order.status, OrderStatus.selesai);
    await s.advanceStatus(order); // tidak boleh lewat dari selesai
    expect(order.status, OrderStatus.selesai);
    expect(s.activeOrders, isEmpty);

    // Pendapatan hanya terhitung setelah lunas.
    expect(s.incomeOn(DateTime.now()), 0);
    await s.setPaid(order, true);
    expect(s.incomeOn(DateTime.now()), order.total);

    // Timbang ulang satu item memperbarui total.
    await s.updateItemQty(order, order.items.first, 4);
    expect(order.total, kiloan.price * 4 + selimut.price);

    // Data tersimpan dan bisa dimuat ulang oleh instance baru.
    final s2 = LaundryStore();
    await s2.init();
    expect(s2.orders.length, 1);
    expect(s2.orders.first.id, order.id);
    expect(s2.orders.first.items.length, 2);
    expect(s2.orders.first.contents, ['Kaos', 'Kemeja', 'Handuk']);
    expect(s2.orders.first.status, OrderStatus.selesai);
    expect(s2.orders.first.paid, true);
  });

  test('pemilik kelola katalog item: tambah, ubah, hapus', () async {
    SharedPreferences.setMockInitialValues({});
    final s = LaundryStore();
    await s.init();
    final before = s.services.length;

    final jaket = await s.addService(
        name: 'Jaket', unit: 'pcs', price: 15000, estimasiHari: 3);
    expect(s.services.length, before + 1);
    expect(jaket.name, 'Jaket');

    await s.updateService(jaket, price: 18000, name: 'Jaket Tebal');
    expect(s.serviceById(jaket.id)!.price, 18000);
    expect(s.serviceById(jaket.id)!.name, 'Jaket Tebal');

    // Tersimpan lintas instance.
    final s2 = LaundryStore();
    await s2.init();
    expect(s2.serviceById(jaket.id)!.name, 'Jaket Tebal');

    await s.deleteService(jaket);
    expect(s.serviceById(jaket.id), isNull);
    expect(s.services.length, before);
  });

  test('kelola admin: tambah, masuk, catat status, hapus', () async {
    SharedPreferences.setMockInitialValues({});
    final s = LaundryStore();
    await s.init();
    expect(s.admins, isEmpty);

    final a1 = await s.addAdmin('Admin 1', '1234');
    final a2 = await s.addAdmin('Admin 2', '5678');
    expect(s.admins.length, 2);

    await s.loginOwner(a1);
    expect(s.role, 'owner');
    expect(s.currentAdmin?.name, 'Admin 1');

    // Perubahan status tercatat atas nama admin yang masuk.
    final svc = s.serviceById('cuci_setrika')!;
    final order = s.createOrder(
      items: [
        OrderItem(
            serviceId: svc.id,
            name: svc.name,
            unit: svc.unit,
            price: svc.price,
            qty: 3),
      ],
      name: 'Budi',
      phone: '0812',
      scheduledAt: DateTime.now(),
      notes: '',
    );
    await s.advanceStatus(order);
    expect(order.history.last.by, 'Admin 1');

    // Ganti PIN dan nama.
    await s.updateAdmin(a2, name: 'Kasir Sore', pin: '9999');
    expect(a2.name, 'Kasir Sore');
    expect(a2.pin, '9999');

    // Keluar mode pemilik menghapus sesi admin.
    await s.setRole(null);
    expect(s.currentAdmin, isNull);

    // Tersimpan lintas instance.
    final s2 = LaundryStore();
    await s2.init();
    expect(s2.admins.length, 2);
    expect(s2.admins.last.name, 'Kasir Sore');

    await s.deleteAdmin(a1);
    expect(s.admins.length, 1);
  });

  test('struk PDF terbentuk dari pesanan', () async {
    final order = Order(
      id: 'H2O-TEST-001',
      customerName: 'Budi Santoso',
      phone: '081234567890',
      items: [
        OrderItem(
            serviceId: 'cuci_setrika',
            name: 'Cuci + Setrika',
            unit: 'kg',
            price: 7000,
            qty: 3.2),
        OrderItem(
            serviceId: 'selimut',
            name: 'Selimut',
            unit: 'pcs',
            price: 20000,
            qty: 1),
      ],
      contents: ['Kaos ×3', 'Kemeja ×2'],
      scheduledAt: DateTime(2026, 8, 9, 9),
      notes: 'Pisahkan baju putih',
      status: OrderStatus.siap,
      history: [StatusEntry(OrderStatus.menunggu, DateTime(2026, 8, 9, 8))],
      paid: true,
      createdAt: DateTime(2026, 8, 9, 8),
    );
    final bytes = await buildReceiptPdf(order);
    expect(bytes.length, greaterThan(1000));
    final out = Platform.environment['RECEIPT_OUT'];
    if (out != null) File(out).writeAsBytesSync(bytes);
  });

  test('migrasi pesanan lama satu-layanan menjadi item', () {
    final legacy = Order.fromMap({
      'id': 'LK-001',
      'customerName': 'Ani',
      'phone': '0813',
      'address': 'Jl. Lama 1',
      'serviceId': 'cuci_kering',
      'serviceName': 'Cuci Kering',
      'unit': 'kg',
      'pricePerUnit': 5000,
      'qty': 2,
      'antarJemput': true,
      'deliveryFee': 5000,
      'scheduledAt': '2026-08-01T09:00:00.000',
      'status': 'dijemput',
      'history': [
        {'status': 'menunggu', 'at': '2026-08-01T08:00:00.000'},
        {'status': 'dijemput', 'at': '2026-08-01T09:30:00.000'},
      ],
      'paid': false,
      'createdAt': '2026-08-01T08:00:00.000',
    });
    expect(legacy.items.length, 1);
    expect(legacy.items.first.name, 'Cuci Kering');
    expect(legacy.total, 10000);
    expect(legacy.status, OrderStatus.diterima);
  });
}
