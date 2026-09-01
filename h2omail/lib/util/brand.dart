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

  /// Bundled logo used for in-app previews (PNG asset), if the brand has one.
  final String? logoAsset;

  /// Public https URL of the logo, embedded in outgoing email signatures.
  /// Hosted logos render inline in Gmail et al.; cid attachments do not.
  final String? logoUrl;

  /// Short line under the company name in the signature (optional).
  final String? tagline;

  /// Organisation name used in the email signature (defaults to [name]).
  final String? company;

  const BrandDef({
    required this.key,
    required this.name,
    required this.icon,
    required this.seed,
    required this.server,
    this.hostSuffix,
    this.logoAsset,
    this.logoUrl,
    this.tagline,
    this.company,
  });

  String get companyName => company ?? name;
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
    company: 'World Cruise Academy',
    logoAsset: 'assets/wca_logo_160.png',
    logoUrl:
        'https://webmail.worldcruiseacademy.co.id/assets/assets/wca_logo_160.png',
  ),
  BrandDef(
    key: 'maya',
    name: 'Maya Resort Mail',
    icon: Icons.spa,
    seed: Color(0xFF00897B),
    server: 'mail.h2olaundry.com', // maya menumpang ke server h2olaundry
    hostSuffix: 'mayaresortsubud.com',
    logoAsset: 'assets/maya_logo_160.png',
    logoUrl:
        'https://webmail.mayaresortsubud.com/assets/assets/maya_logo_160.png',
    tagline: 'Serenity in the Heart of Bali',
    company: 'Maya Resort Ubud',
  ),
];

const BrandDef _h2o = BrandDef(
  key: 'h2o',
  name: 'H2O Mail',
  icon: Icons.water_drop,
  seed: Color(0xFF0288D1),
  server: 'mail.h2olaundry.com',
  company: 'H2O Laundry',
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
  static String get company => _active.companyName;
  static String? get tagline => _active.tagline;
  static String? get logoAsset => _active.logoAsset;

  /// Resolves the brand for a specific account by its email domain, so a
  /// signature is branded per-account (not per-build). Falls back to the
  /// active build brand when the domain isn't a known brand.
  static BrandDef defFor(String email) {
    final domain =
        email.contains('@') ? email.split('@').last.toLowerCase() : '';
    if (domain.isNotEmpty) {
      for (final b in _brands) {
        if (b.hostSuffix != null && domain.endsWith(b.hostSuffix!)) return b;
      }
    }
    return _active;
  }

  /// Dedicated builds and branded hostnames lock the server field.
  static bool get serverLocked => _active.key != 'h2o';
}
