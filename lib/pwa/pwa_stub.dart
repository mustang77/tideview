/// Versi non-web: PWA tidak berlaku, semua tidak tersedia.
bool pwaIsStandalone() => false;

bool pwaCanInstall() => false;

bool pwaTriggerInstall() => false;

bool pwaDidPrompt() => false;

Future<bool> pwaIsInstalled() async => false;

bool webBtSupported() => false;

bool webBtReady() => false;

Future<String> webBtPick() async => '';

Future<bool> webBtPrint(String b64) async => false;
