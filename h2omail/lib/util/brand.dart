import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A single brand: name, icon, accent color, and its mail server.
class BrandDef {
  final String key;
  final String name;
  final IconData icon;
  final Color seed;
  final String server;

  /// If non-null, this hostname suffix selects the brand on web.
  final String? hostSuffix;

  const BrandDef({
    required this.key,
    required this.name,
    required this.icon,
    required this.seed,
    required this.server,
    this.hostSuffix,
  });
}

/// All brands the one build can present. Order matters for host matching.
const List<BrandDef> _brands = [
  BrandDef(
    key: 'wca',
    name: 'WCA Mail',
    icon: Icons.directions_boat,
    seed: Color(0xFF0288D1),
    server: 'mail.worldcruiseacademy.co.id',
    hostSuffix: 'worldcruiseacademy.co.id',
  ),
  BrandDef(
    key: 'maya',
    name: 'Maya Resort Mail',
    icon: Icons.spa,
    seed: Color(0xFF00897B),
    server: 'mail.h2olaundry.com', // maya menumpang ke server h2olaundry
    hostSuffix: 'mayaresortsubud.com',
  ),
];

const BrandDef _h2o = BrandDef(
  key: 'h2o',
  name: 'H2O Mail',
  icon: Icons.water_drop,
  seed: Color(0xFF0288D1),
  server: 'mail.h2olaundry.com',
);

/// Resolves the active brand from a build-time define or the web hostname.
class Brand {
  static const String _buildBrand = String.fromEnvironment('BRAND');

  static String get _host => kIsWeb ? Uri.base.host : '';

  static final BrandDef _active = _resolve();

  static BrandDef _resolve() {
    if (_buildBrand.isNotEmpty) {
      for (final b in _brands) {
        if (b.key == _buildBrand) return b;
      }
      return _h2o;
    }
    if (kIsWeb) {
      for (final b in _brands) {
        if (b.hostSuffix != null && _host.endsWith(b.hostSuffix!)) return b;
      }
    }
    return _h2o;
  }

  static String get name => _active.name;
  static IconData get icon => _active.icon;
  static Color get seed => _active.seed;
  static String get defaultServer => _active.server;

  /// Dedicated builds and branded hostnames lock the server field.
  static bool get serverLocked => _active.key != 'h2o';
}
