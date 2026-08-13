import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'store.dart';

// Generates a thermal-style receipt (struk) for an order and opens the OS
// print / share dialog — the user can send it to a printer, save it as a PDF,
// or share it (e.g. to WhatsApp). Works on Android, iOS, web and desktop.

String _rupiah(int n) {
  final s = n.abs().toString();
  final b = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return '${n < 0 ? '-' : ''}Rp$b';
}

String _payLabel(String p) {
  switch (p) {
    case 'COD':
      return 'Bayar di Tempat (COD)';
    case 'Transfer':
      return 'Transfer Bank';
    case 'QRIS':
      return 'QRIS';
    default:
      return p.isEmpty ? '-' : p;
  }
}

const List<String> _months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
String _dateTime(DateTime d) =>
    '${d.day} ${_months[d.month - 1]} ${d.year}, ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

pw.Widget _divider() => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Container(height: 0.6, color: PdfColors.grey600),
    );

pw.Widget _row(String a, String b, {bool bold = false, double size = 9}) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(a, style: pw.TextStyle(fontSize: size, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        pw.Text(b, style: pw.TextStyle(fontSize: size, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      ]),
    );

Future<Uint8List> buildReceiptPdf(Order o, {String waNumber = ''}) async {
  final doc = pw.Document();
  // 80mm-wide continuous roll (thermal receipt); also prints fine on A4.
  const format = PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginAll: 6 * PdfPageFormat.mm);
  doc.addPage(pw.Page(
    pageFormat: format,
    build: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
      pw.Center(child: pw.Text('PARAMALL', style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold))),
      pw.Center(child: pw.Text('Belanja online, kami antar ke rumah', style: const pw.TextStyle(fontSize: 8))),
      if (waNumber.isNotEmpty) pw.Center(child: pw.Text('WhatsApp: $waNumber', style: const pw.TextStyle(fontSize: 8))),
      pw.SizedBox(height: 5),
      _divider(),
      _row('No. Pesanan', '#${o.id}', bold: true),
      _row('Tanggal', _dateTime(o.at)),
      _row('Status', o.status),
      _divider(),
      ...o.items.map((it) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 2),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
              pw.Text(it.name, style: const pw.TextStyle(fontSize: 9)),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('${it.qty} x ${_rupiah(it.price)}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                pw.Text(_rupiah(it.sum), style: const pw.TextStyle(fontSize: 9)),
              ]),
            ]),
          )),
      _divider(),
      _row('Subtotal', _rupiah(o.subtotal)),
      _row('Ongkir', o.ongkir == 0 ? 'GRATIS' : _rupiah(o.ongkir)),
      pw.SizedBox(height: 2),
      _row('TOTAL', _rupiah(o.total), bold: true, size: 12),
      _row('Pembayaran', _payLabel(o.pay)),
      _divider(),
      pw.Text('Penerima', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
      pw.Text(o.name, style: const pw.TextStyle(fontSize: 9)),
      if (o.phone.isNotEmpty) pw.Text(o.phone, style: const pw.TextStyle(fontSize: 9)),
      if (o.addr.isNotEmpty) pw.Text(o.addr, style: const pw.TextStyle(fontSize: 9)),
      if (o.note.isNotEmpty) pw.Text('Catatan: ${o.note}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
      pw.SizedBox(height: 8),
      pw.Center(child: pw.Text('Terima kasih telah belanja di Paramall', style: const pw.TextStyle(fontSize: 8))),
      pw.SizedBox(height: 6),
    ]),
  ));
  return doc.save();
}

// Opens the print / share sheet for the order's receipt.
Future<void> printReceipt(Order o, {String waNumber = ''}) {
  return Printing.layoutPdf(onLayout: (_) => buildReceiptPdf(o, waNumber: waNumber));
}
