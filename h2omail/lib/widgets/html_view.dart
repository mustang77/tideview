// Platform facade: mobile uses a WebView, web uses a sandboxed iframe.
export 'html_view_mobile.dart'
    if (dart.library.js_interop) 'html_view_web.dart';
