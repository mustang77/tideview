// Cetak struk LANGSUNG ke printer thermal Bluetooth (ESC/POS) —
// sekali ketuk tanpa dialog print sistem / RawBT. Byte ESC/POS
// dirakit sendiri (struknya sederhana), koneksi lewat plugin
// print_bluetooth_thermal ke printer yang sudah di-pair.

import 'dart:convert' show base64Encode, latin1;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import 'format.dart';
import 'models.dart';
import 'pwa/pwa.dart';
import 'receipt.dart';
import 'store.dart';

// ---- Perakit byte ESC/POS -------------------------------------------

/// Printer 58mm mencetak 32 kolom (font A); 80mm mencetak 48.
int _cols(int width) => width == 80 ? 48 : 32;

/// Ganti karakter di luar Latin-1 supaya tidak jadi huruf acak.
String _sanitize(String s) {
  const map = {
    '—': '-', '–': '-', '•': '-', '×': 'x',
    '“': '"', '”': '"', '‘': "'", '’': "'",
    '…': '...',
  };
  final sb = StringBuffer();
  for (final ch in s.split('')) {
    final m = map[ch] ?? ch;
    if (m.codeUnitAt(0) <= 0xFF) sb.write(m);
  }
  return sb.toString();
}

List<int> buildEscposReceipt(Order order, {int width = 58}) {
  final cols = _cols(width);
  final out = <int>[];

  void cmd(List<int> c) => out.addAll(c);
  void raw(String s) => out.addAll(latin1.encode(_sanitize(s)));
  void line(String s,
      {bool center = false, bool bold = false, bool big = false}) {
    cmd([0x1B, 0x61, center ? 1 : 0]); // perataan
    cmd([0x1B, 0x45, bold ? 1 : 0]); // tebal
    cmd([0x1D, 0x21, big ? 0x11 : 0x00]); // ukuran ganda
    raw(s);
    cmd([0x0A]);
  }

  void row(String l, String r, {bool bold = false}) {
    final maxL = cols - r.length - 1;
    final left = l.length > maxL ? l.substring(0, maxL) : l;
    final pad = cols - left.length - r.length;
    line('$left${' ' * (pad > 0 ? pad : 1)}$r', bold: bold);
  }

  void divider() => line('-' * cols);

  cmd([0x1B, 0x40]); // reset printer
  line('H2O LAUNDRY', center: true, bold: true, big: true);
  line('P A R A K A N', center: true, bold: true);
  line('Laundry bersih, wangi, dan rapi', center: true);
  divider();
  row('No. Pesanan', order.id, bold: true);
  row('Tanggal', dateTimeText(order.createdAt));
  row('Nama', order.customerName);
  row('No. HP', order.phone);
  divider();
  for (final item in order.items) {
    line(item.name, bold: true);
    row(' ${qtyText(item.qty, item.unit)} x ${rupiah(item.price)}',
        rupiah(item.subtotal));
  }
  divider();
  row('TOTAL', rupiah(order.total), bold: true);
  line(order.paid ? '*** LUNAS ***' : 'BELUM DIBAYAR',
      center: true, bold: true);
  if (order.contents.isNotEmpty) {
    divider();
    line('Isi cucian (deklarasi pelanggan):');
    line(order.contents.join(', '));
    line('Barang di luar daftar menjadi');
    line('tanggung jawab pelanggan bila hilang.');
  }
  if (order.notes.isNotEmpty) {
    divider();
    line('Catatan: ${order.notes}');
  }
  divider();
  line('Status: ${order.statusText}', center: true);
  line('Terima kasih!', center: true, bold: true);
  line('Simpan struk ini untuk', center: true);
  line('pengambilan cucian.', center: true);
  cmd([0x1B, 0x64, 3]); // maju 3 baris supaya mudah disobek
  return out;
}

// ---- Alur cetak ------------------------------------------------------

/// MAC printer yang koneksinya sedang kita pegang. Koneksi sengaja
/// DIBIARKAN terbuka setelah mencetak: menyambung ulang tiap cetak
/// adalah sumber utama "susah connect" di printer thermal murah.
String _connectedMac = '';

/// Pastikan tersambung ke printer tersimpan; coba sampai 3 kali.
/// null = tersambung; teks = pesan error.
Future<String?> _ensureConnected() async {
  final mac = store.btPrinterMac;
  try {
    if (_connectedMac == mac &&
        await PrintBluetoothThermal.connectionStatus) {
      return null; // masih tersambung dari cetakan sebelumnya
    }
  } catch (_) {}
  try {
    await PrintBluetoothThermal.disconnect;
  } catch (_) {}
  _connectedMac = '';
  for (var attempt = 1; attempt <= 3; attempt++) {
    try {
      final ok = await PrintBluetoothThermal.connect(
              macPrinterAddress: mac)
          .timeout(const Duration(seconds: 8), onTimeout: () => false);
      if (ok) {
        _connectedMac = mac;
        return null;
      }
    } catch (_) {}
    // Printer murah sering menolak percobaan pertama — jeda lalu ulang.
    if (attempt < 3) {
      await Future<void>.delayed(Duration(milliseconds: 600 * attempt));
    }
  }
  return 'Tidak bisa tersambung ke ${store.btPrinterName} '
      '(3x percobaan). Matikan-nyalakan printernya lalu coba lagi.';
}

/// Cetak langsung ke printer tersimpan. null = sukses; teks = error.
Future<String?> _printDirect(Order order) async {
  if (store.btPrinterMac.isEmpty) return 'BELUM_PILIH';
  try {
    final on = await PrintBluetoothThermal.bluetoothEnabled;
    if (!on) return 'Bluetooth HP mati. Nyalakan dulu ya.';
  } catch (_) {}
  var err = await _ensureConnected();
  if (err != null) return err;
  final bytes = buildEscposReceipt(order, width: store.receiptWidth);
  var sent = false;
  try {
    sent = await PrintBluetoothThermal.writeBytes(bytes);
  } catch (_) {}
  if (!sent) {
    // Koneksi lama basi (printer sempat mati/menjauh): sambung ulang
    // sekali, lalu coba kirim lagi.
    _connectedMac = '';
    err = await _ensureConnected();
    if (err != null) return err;
    try {
      sent = await PrintBluetoothThermal.writeBytes(bytes);
    } catch (_) {}
  }
  // Koneksi dibiarkan hidup — cetakan berikutnya langsung jalan.
  return sent ? null : 'Gagal mengirim data ke printer.';
}

/// Pilih printer dari daftar perangkat Bluetooth yang sudah di-pair.
Future<void> pickBtPrinter(BuildContext context) async {
  // Android 12+ butuh izin runtime; versi lama langsung lolos.
  await [Permission.bluetoothConnect, Permission.bluetoothScan].request();
  List<BluetoothInfo> devices = const [];
  try {
    devices = await PrintBluetoothThermal.pairedBluetooths;
  } catch (_) {}
  if (!context.mounted) return;
  if (devices.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Tidak ada perangkat ter-pair. Pair printer di '
            'Settings > Bluetooth dulu, lalu coba lagi.')));
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('Pilih Printer Bluetooth',
                style:
                    TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ),
          for (final d in devices)
            ListTile(
              leading: const Icon(Icons.print_outlined),
              title: Text(d.name),
              subtitle: Text(d.macAdress),
              trailing: store.btPrinterMac == d.macAdress
                  ? const Icon(Icons.check_circle, color: Color(0xFF16A34A))
                  : null,
              onTap: () async {
                await store.setBtPrinter(d.macAdress, d.name);
                if (sheet.mounted) Navigator.pop(sheet);
              },
            ),
        ],
      ),
    ),
  );
}

/// Cetak langsung dengan umpan balik snackbar; kalau belum ada
/// printer tersimpan, minta pilih dulu lalu langsung mencetak.
Future<void> _directFlow(BuildContext context, Order order) async {
  if (store.btPrinterMac.isEmpty) {
    await pickBtPrinter(context);
    if (store.btPrinterMac.isEmpty || !context.mounted) return;
  }
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(SnackBar(
      duration: const Duration(seconds: 30),
      content: Text('Menyambung ke ${store.btPrinterName} & mencetak... '
          '(bisa ±10 detik pada cetakan pertama)')));
  final err = await _printDirect(order);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
      SnackBar(content: Text(err ?? 'Struk tercetak ✅')));
}

/// Cetak dari PWA/web lewat Web Bluetooth (BLE). Hanya berhasil bila
/// printernya punya mode BLE; printer SPP-saja tidak muncul di pemilih.
Future<void> _webBtFlow(BuildContext context, Order order) async {
  final messenger = ScaffoldMessenger.of(context);
  if (!webBtReady()) {
    final name = await webBtPick();
    if (name.isEmpty) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Printer tidak terpilih. Catatan: lewat web '
              'hanya printer ber-BLE yang terlihat — bila punya Anda '
              'tidak muncul, pakai "Dialog Print Browser" atau '
              'aplikasi Android.')));
      return;
    }
    messenger.showSnackBar(
        SnackBar(content: Text('Tersambung ke $name')));
  }
  messenger.showSnackBar(const SnackBar(
      duration: Duration(seconds: 20),
      content: Text('Mengirim ke printer...')));
  final ok = await webBtPrint(base64Encode(
      buildEscposReceipt(order, width: store.receiptWidth)));
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(
      content: Text(ok
          ? 'Struk tercetak ✅'
          : 'Gagal mencetak. Printer menyala dan dekat? Coba lagi.')));
}

/// Lembar pilihan cetak untuk layar pesanan pemilik: cetak langsung
/// Bluetooth (utama), ganti printer, atau dialog sistem/PDF (cadangan).
Future<void> showPrintSheet(BuildContext context, Order order) async {
  // Web/PWA: tawarkan Web Bluetooth (BLE) bila browser mendukung;
  // selain itu jatuh ke dialog print browser.
  if (kIsWeb) {
    if (!webBtSupported()) {
      await printReceipt(order);
      return;
    }
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  const Icon(Icons.flash_on, color: Color(0xFFD97706)),
              title: const Text('Cetak Langsung (Bluetooth)',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(webBtReady()
                  ? 'Printer sudah tersambung'
                  : 'Pilih printer BLE dari daftar browser'),
              onTap: () => Navigator.pop(sheet, 'ble'),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Dialog Print Browser (PDF)'),
              subtitle: const Text('Printer biasa / simpan PDF'),
              onTap: () => Navigator.pop(sheet, 'pdf'),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    switch (choice) {
      case 'ble':
        await _webBtFlow(context, order);
      case 'pdf':
        await printReceipt(order);
    }
    return;
  }
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.flash_on, color: Color(0xFFD97706)),
            title: const Text('Cetak Langsung (Bluetooth)',
                style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(store.btPrinterName.isEmpty
                ? 'Pertama kali: pilih printer dulu'
                : 'Ke ${store.btPrinterName} — tanpa dialog'),
            onTap: () => Navigator.pop(sheet, 'langsung'),
          ),
          ListTile(
            leading: const Icon(Icons.settings_bluetooth),
            title: const Text('Pilih / Ganti Printer Bluetooth'),
            subtitle: Text(store.btPrinterName.isEmpty
                ? 'Belum ada printer tersimpan'
                : 'Sekarang: ${store.btPrinterName}'),
            onTap: () => Navigator.pop(sheet, 'pilih'),
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_outlined),
            title: const Text('Cetak lewat Dialog Sistem (PDF)'),
            subtitle: const Text('RawBT / printer biasa / simpan PDF'),
            onTap: () => Navigator.pop(sheet, 'pdf'),
          ),
          const SizedBox(height: 6),
        ],
      ),
    ),
  );
  if (!context.mounted) return;
  switch (choice) {
    case 'langsung':
      await _directFlow(context, order);
    case 'pilih':
      await pickBtPrinter(context);
    case 'pdf':
      await printReceipt(order);
  }
}
