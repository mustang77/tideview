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

  static bool get isWca {
    if (_buildBrand == 'h2o') return false; // explicit personal build
    if (_buildBrand == 'wca') return true;
    if (!kIsWeb) return true; // mobile builds default to WCA Mail
    return _host.endsWith('worldcruiseacademy.co.id');
  }

  /// True when the server cannot be changed by the user (dedicated builds).
  static bool get serverLocked => isWca && (!kIsWeb || _buildBrand == 'wca');

  static String get name => isWca ? 'WCA Mail' : 'H2O Mail';

  static IconData get icon => isWca ? Icons.directions_boat : Icons.water_drop;

  static String get defaultServer {
    if (serverLocked) return 'mail.worldcruiseacademy.co.id';
    if (kIsWeb && _host.startsWith('webmail.')) {
      return _host.replaceFirst('webmail.', 'mail.');
    }
    return 'mail.h2olaundry.com';
  }
}
