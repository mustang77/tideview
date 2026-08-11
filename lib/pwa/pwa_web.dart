import 'dart:js_interop';

// Jembatan ke fungsi kecil di web/index.html yang menyimpan event
// beforeinstallprompt (lihat komentar di sana).

@JS('h2oIsStandalone')
external bool _isStandalone();

@JS('h2oCanInstall')
external bool _canInstall();

@JS('h2oInstall')
external bool _install();

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

/// Tampilkan dialog install PWA; false bila tidak tersedia.
bool pwaTriggerInstall() {
  try {
    return _install();
  } catch (_) {
    return false;
  }
}
