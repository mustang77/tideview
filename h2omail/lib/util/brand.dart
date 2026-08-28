import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Runtime branding: the same web build serves multiple hostnames.
/// Opened from webmail.<domain> the app brands itself for that domain and
/// pre-fills the matching mail server; anywhere else it defaults to H2O Mail.
class Brand {
  static String get _host => kIsWeb ? Uri.base.host : '';

  static bool get isWca => _host.endsWith('worldcruiseacademy.co.id');

  static String get name => isWca ? 'WCA Mail' : 'H2O Mail';

  static IconData get icon => isWca ? Icons.directions_boat : Icons.water_drop;

  static String get defaultServer {
    if (kIsWeb && _host.startsWith('webmail.')) {
      return _host.replaceFirst('webmail.', 'mail.');
    }
    return 'mail.h2olaundry.com';
  }
}
