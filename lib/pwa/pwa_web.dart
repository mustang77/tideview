import 'dart:js_interop';

// Jembatan ke fungsi kecil di web/index.html yang menyimpan event
// beforeinstallprompt (lihat komentar di sana).

@JS('h2oIsStandalone')
external bool _isStandalone();

@JS('h2oCanInstall')
external bool _canInstall();

@JS('h2oInstall')
external bool _install();

@JS('h2oIsInstalled')
external JSPromise<JSBoolean> _isInstalled();

@JS('h2oDidPrompt')
external bool _didPrompt();

/// Sudah berjalan sebagai aplikasi terpasang (bukan tab browser)?
bool pwaIsStandalone() {
  try {
    return _isStandalone();
  } catch (_) {
    return false;
  }
}

/// Browser siap menampilkan dialog install (event sudah tertangkap)?
bool pwaCanInstall() {
  try {
    return _canInstall();
  } catch (_) {
    return false;
  }
}

/// Tampilkan dialog install PWA. false = belum tersedia — tapi
/// permintaan diantre di JS dan prompt muncul sendiri begitu siap.
bool pwaTriggerInstall() {
  try {
    return _install();
  } catch (_) {
    return false;
  }
}

/// Dialog install sudah pernah tampil di sesi ini (termasuk lewat
/// antrean otomatis)?
bool pwaDidPrompt() {
  try {
    return _didPrompt();
  } catch (_) {
    return false;
  }
}

/// PWA ini sudah terpasang di perangkat? (Chrome Android; browser
/// lain menjawab false.)
Future<bool> pwaIsInstalled() async {
  try {
    return (await _isInstalled().toDart).toDart;
  } catch (_) {
    return false;
  }
}
