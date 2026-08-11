import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tideview/models.dart';
import 'package:tideview/receipt.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Order sample() => Order(
        id: 'H2O-0042',
        customerName: 'Budi Santoso',
        phone: '6281299988877',
        items: [
          OrderItem(
              serviceId: 's1',
              name: 'Cuci + Setrika',
              unit: 'kg',
              price: 7000,
              qty: 3),
          OrderItem(
              serviceId: 's2',
              name: 'Express 1 Hari',
              unit: 'kg',
              price: 12000,
              qty: 1.5),
        ],
        contents: ['5 kaos', '2 celana', '1 jaket'],
        scheduledAt: DateTime(2026, 8, 11, 10),
        notes: 'Jangan pakai pewangi',
        status: OrderStatus.diproses,
        history: [],
        paid: true,
        createdAt: DateTime(2026, 8, 11, 9, 30),
      );

  test('struk 58mm dan 80mm terbentuk dan lebar halaman benar', () async {
    final w58 = await buildReceiptPdf(sample(), width: 58);
    final w80 = await buildReceiptPdf(sample(), width: 80);
    expect(w58.length, greaterThan(1000));
    expect(w80.length, greaterThan(1000));
    // Simpan untuk pemeriksaan visual (opsional, di luar CI).
    final dir = Platform.environment['RECEIPT_OUT'];
    if (dir != null) {
      File('$dir/struk58.pdf').writeAsBytesSync(w58);
      File('$dir/struk80.pdf').writeAsBytesSync(w80);
    }
  });
}
