import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Branding resolves in two ways:
/// 1. Build-time: `--dart-define=BRAND=wca` produces a dedicated WCA Mail
///    build (server locked, field hidden) — used for the Android APK.
/// 2. Runtime (web only): the same generic build opened from
///    webmail.<domain> brands itself for that domain.
class Brand {
  static const String _buildBrand = String.fromEnvironment('BRAND');

  static String get _host => kIsWeb ? Uri.base.host : '';

  static bool get isWca =>
      _buildBrand == 'wca' || _host.endsWith('worldcruiseacademy.co.id');

  /// True only for dedicated builds: the server cannot be changed by the user.
  static bool get serverLocked => _buildBrand == 'wca';

  static String get name => isWca ? 'WCA Mail' : 'H2O Mail';

  static IconData get icon => isWca ? Icons.directions_boat : Icons.water_drop;

  static String get defaultServer {
    if (_buildBrand == 'wca') return 'mail.worldcruiseacademy.co.id';
    if (kIsWeb && _host.startsWith('webmail.')) {
      return _host.replaceFirst('webmail.', 'mail.');
    }
    return 'mail.h2olaundry.com';
  }
}
