/// Versi non-web: PWA tidak berlaku, semua tidak tersedia.
bool pwaIsStandalone() => false;

bool pwaCanInstall() => false;

bool pwaTriggerInstall() => false;

bool pwaDidPrompt() => false;

Future<bool> pwaIsInstalled() async => false;
