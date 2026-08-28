import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Renders untrusted email HTML in a WebView with JavaScript disabled.
/// Tapped links open in the external browser.
class HtmlContentView extends StatefulWidget {
  final String html;
  const HtmlContentView({super.key, required this.html});

  @override
  State<HtmlContentView> createState() => _HtmlContentViewState();
}

class _HtmlContentViewState extends State<HtmlContentView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    final doc = '<!DOCTYPE html><html><head>'
        '<meta name="viewport" content="width=device-width, initial-scale=1">'
        '<style>body{font-family:sans-serif;margin:12px;word-break:break-word;'
        'background:#ffffff;color:#111111;} img{max-width:100%;height:auto;}'
        '</style></head><body>${widget.html}</body></html>';
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.disabled)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (request) {
          final url = Uri.tryParse(request.url);
          if (url != null &&
              (url.scheme == 'http' || url.scheme == 'https')) {
            launchUrl(url, mode: LaunchMode.externalApplication);
          }
          return NavigationDecision.prevent;
        },
      ))
      ..loadHtmlString(doc);
  }

  @override
  Widget build(BuildContext context) => WebViewWidget(controller: _controller);
}
