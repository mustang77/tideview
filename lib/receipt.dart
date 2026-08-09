import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'format.dart';
import 'models.dart';

/// Struk pesanan H2O Laundry Parakan dalam format kertas thermal 80mm.
/// Bisa dicetak lewat dialog print sistem atau dibagikan sebagai PDF.
Future<Uint8List> buildReceiptPdf(Order order) async {
  final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/PlusJakartaSans-Regular.ttf'));
  final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/PlusJakartaSans-Bold.ttf'));

  final base = pw.TextStyle(font: regular, fontSize: 8.5);
  final small = pw.TextStyle(font: regular, fontSize: 7.5);
  final strong = pw.TextStyle(font: bold, fontSize: 8.5);
  final title = pw.TextStyle(font: bold, fontSize: 11);

  pw.Widget line() => pw.Container(
        margin: const pw.EdgeInsets.symmetric(vertical: 5),
        height: 0.8,
        color: PdfColors.grey600,
      );

  pw.Widget row(String left, String right,
          {pw.TextStyle? style, pw.TextStyle? rightStyle}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(child: pw.Text(left, style: style ?? base)),
            pw.Text(right, style: rightStyle ?? style ?? base),
          ],
        ),
      );

  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.roll80,
      margin: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Center(child: pw.Text('H2O LAUNDRY', style: title)),
          pw.Center(
            child: pw.Text(
              'PARAKAN',
              style: pw.TextStyle(
                  font: bold, fontSize: 9, letterSpacing: 3),
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Center(
              child: pw.Text('Laundry bersih, wangi, dan rapi',
                  style: small)),
          line(),
          row('No. Pesanan', order.id, style: base, rightStyle: strong),
          row('Tanggal', dateTimeText(order.createdAt)),
          row('Nama', order.customerName),
          row('No. HP', order.phone),
          line(),
          for (final item in order.items) ...[
            pw.Text(item.name, style: strong),
            row(
              '  ${qtyText(item.qty, item.unit)} × ${rupiah(item.price)}',
              rupiah(item.subtotal),
            ),
          ],
          line(),
          row('TOTAL', rupiah(order.total),
              style: strong,
              rightStyle: pw.TextStyle(font: bold, fontSize: 11)),
          pw.SizedBox(height: 2),
          pw.Center(
            child: pw.Text(
              order.paid ? '*** LUNAS ***' : 'BELUM DIBAYAR',
              style: strong,
            ),
          ),
          if (order.contents.isNotEmpty) ...[
            line(),
            pw.Text('Isi cucian (deklarasi pelanggan):', style: small),
            pw.Text(order.contents.join(', '), style: base),
            pw.SizedBox(height: 2),
            pw.Text(
              'Barang di luar daftar di atas menjadi tanggung jawab '
              'pelanggan bila hilang.',
              style: small,
            ),
          ],
          if (order.notes.isNotEmpty) ...[
            line(),
            pw.Text('Catatan: ${order.notes}', style: small),
          ],
          line(),
          pw.Center(
              child: pw.Text('Status: ${order.statusText}', style: small)),
          pw.SizedBox(height: 6),
          pw.Center(child: pw.Text('Terima kasih!', style: strong)),
          pw.Center(
            child: pw.Text(
              'Simpan struk ini untuk pengambilan cucian.',
              style: small,
            ),
          ),
        ],
      ),
    ),
  );
  return doc.save();
}

/// Buka dialog cetak sistem (printer thermal/biasa, atau simpan PDF).
Future<void> printReceipt(Order order) => Printing.layoutPdf(
      onLayout: (_) => buildReceiptPdf(order),
      name: 'Struk ${order.id}',
    );

/// Bagikan struk sebagai file PDF (WhatsApp, email, dll.).
Future<void> shareReceipt(Order order) async => Printing.sharePdf(
      bytes: await buildReceiptPdf(order),
      filename: 'struk-${order.id}.pdf',
    );
