import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tideview/format.dart';
import 'package:tideview/models.dart';
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

  test('alur pesanan: buat, majukan status, bayar', () async {
    SharedPreferences.setMockInitialValues({});
    final s = LaundryStore();
    await s.init();
    expect(s.services, isNotEmpty);

    final svc = s.serviceById('cuci_setrika')!;
    final order = s.createOrder(
      service: svc,
      qty: 3,
      antarJemput: true,
      name: 'Budi',
      phone: '0812',
      address: 'Jl. Melati 1',
      scheduledAt: DateTime.now(),
      notes: '',
    );

    expect(order.total, svc.price * 3 + LaundryStore.biayaAntarJemput);
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

    // Timbang ulang memperbarui total.
    await s.updateQty(order, 4);
    expect(order.total, svc.price * 4 + LaundryStore.biayaAntarJemput);

    // Data tersimpan dan bisa dimuat ulang oleh instance baru.
    final s2 = LaundryStore();
    await s2.init();
    expect(s2.orders.length, 1);
    expect(s2.orders.first.id, order.id);
    expect(s2.orders.first.status, OrderStatus.selesai);
    expect(s2.orders.first.paid, true);
  });
}
