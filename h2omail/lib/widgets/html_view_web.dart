import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import '../util/text_size.dart';

/// Renders untrusted email HTML inside a sandboxed iframe (no scripts).
class HtmlContentView extends StatefulWidget {
  final String html;
  const HtmlContentView({super.key, required this.html});

  @override
  State<HtmlContentView> createState() => _HtmlContentViewState();
}

class _HtmlContentViewState extends State<HtmlContentView> {
  static int _counter = 0;
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = 'h2omail-html-${_counter++}';
    final doc =
        // zoom on the root = browser zoom: emails with their own small px
        // sizes grow too, and the text still wraps to the window
        '<base target="_blank"><style>html{zoom:$kEmailZoom}'
        'body{font-family:sans-serif;margin:12px;line-height:1.5;'
        'word-break:break-word;background:#ffffff;color:#111111;}'
        'img{max-width:100%;height:auto;}</style>'
        '${widget.html}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) {
      final iframe = web.HTMLIFrameElement()
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.border = 'none';
      iframe.setAttribute('srcdoc', doc);
      iframe.setAttribute(
          'sandbox', 'allow-popups allow-popups-to-escape-sandbox');
      return iframe;
    });
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewType);
}
