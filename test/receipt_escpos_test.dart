import 'dart:convert' show latin1;

import 'package:flutter_test/flutter_test.dart';
import 'package:tideview/models.dart';
import 'package:tideview/receipt_bt.dart';

void main() {
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
        ],
        contents: ['5 kaos'],
        scheduledAt: DateTime(2026, 8, 11, 10),
        notes: 'Tanpa pewangi — “wangi” alami…',
        status: OrderStatus.siap,
        history: [],
        paid: true,
        createdAt: DateTime(2026, 8, 11, 9, 30),
      );

  test('struk ESC/POS berisi bagian utama dan tersanitasi Latin-1', () {
    final bytes = buildEscposReceipt(sample(), width: 58);
    // Semua byte harus muat Latin-1 (printer thermal tidak kenal UTF-8).
    expect(bytes.every((b) => b >= 0 && b <= 255), true);
    final text = latin1.decode(bytes);
    expect(text, contains('H2O LAUNDRY'));
    expect(text, contains('H2O-0042'));
    expect(text, contains('Cuci + Setrika'));
    expect(text, contains('Rp 21.000'));
    expect(text, contains('LUNAS'));
    // Em-dash/petik keriting dari catatan harus sudah diganti ASCII.
    expect(text, contains('Tanpa pewangi - "wangi" alami...'));
    expect(text.contains('—'), false);
  });
}
