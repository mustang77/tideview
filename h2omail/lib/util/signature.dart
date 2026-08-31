import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'brand.dart';

/// The inline logo is referenced from the signature HTML by this Content-ID.
const String kSignatureLogoCid = 'brandlogo';

String _hex(Color c) {
  String f(double v) =>
      (v * 255.0).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
  return '#${f(c.r)}${f(c.g)}${f(c.b)}';
}

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

/// A per-account email signature. Personal fields are stored; the company
/// name, tagline, accent colour and logo come from the active [Brand].
class Signature {
  final bool enabled;
  final bool includeLogo;
  final String name;
  final String title;
  final String phone;
  final String website;
  final String address;

  const Signature({
    this.enabled = true,
    this.includeLogo = true,
    this.name = '',
    this.title = '',
    this.phone = '',
    this.website = '',
    this.address = '',
  });

  Signature copyWith({
    bool? enabled,
    bool? includeLogo,
    String? name,
    String? title,
    String? phone,
    String? website,
    String? address,
  }) =>
      Signature(
        enabled: enabled ?? this.enabled,
        includeLogo: includeLogo ?? this.includeLogo,
        name: name ?? this.name,
        title: title ?? this.title,
        phone: phone ?? this.phone,
        website: website ?? this.website,
        address: address ?? this.address,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'logo': includeLogo,
        'name': name,
        'title': title,
        'phone': phone,
        'website': website,
        'address': address,
      };

  factory Signature.fromJson(Map<String, dynamic> j) => Signature(
        enabled: (j['enabled'] ?? true) as bool,
        includeLogo: (j['logo'] ?? true) as bool,
        name: (j['name'] ?? '') as String,
        title: (j['title'] ?? '') as String,
        phone: (j['phone'] ?? '') as String,
        website: (j['website'] ?? '') as String,
        address: (j['address'] ?? '') as String,
      );

  /// Sensible defaults for a brand-new account (website from the email domain).
  factory Signature.initial(String email) {
    final domain =
        email.contains('@') ? email.split('@').last.toLowerCase() : '';
    return Signature(
      website: domain.isEmpty ? '' : 'https://$domain',
      address: domain == 'mayaresortsubud.com'
          ? 'Ubud, Gianyar, Bali, Indonesia'
          : '',
    );
  }

  bool get isEmpty =>
      name.isEmpty &&
      title.isEmpty &&
      phone.isEmpty &&
      website.isEmpty &&
      address.isEmpty;

  /// The logo asset for [email]'s brand, or null if none.
  String? logoAssetFor(String email) => Brand.defFor(email).logoAsset;

  /// Whether the logo can be embedded for [email] (enabled + brand has one).
  bool logoAvailableFor(String email) =>
      includeLogo && logoAssetFor(email) != null;

  /// Plain-text signature (the text/plain alternative part).
  String toText(String email) {
    final brand = Brand.defFor(email);
    final lines = <String>['--'];
    if (name.isNotEmpty) lines.add(name);
    if (title.isNotEmpty) lines.add(title);
    lines.add(brand.companyName);
    if (phone.isNotEmpty) lines.add('Tel: $phone');
    lines.add(email);
    if (website.isNotEmpty) {
      lines.add(website.replaceFirst(RegExp(r'^https?://'), ''));
    }
    if (address.isNotEmpty) lines.add(address);
    return lines.join('\n');
  }

  /// HTML signature (the text/html alternative part). When [cidLogo] is true
  /// and a brand logo exists, the logo is referenced as `cid:` (inline image).
  String toHtml(String email, {required bool cidLogo}) {
    final brand = Brand.defFor(email);
    final accent = _hex(brand.seed);
    final web = website.isEmpty
        ? ''
        : website.startsWith(RegExp(r'https?://'))
            ? website
            : 'https://$website';
    final webLabel = web.replaceFirst(RegExp(r'^https?://'), '');

    final logoCell = (cidLogo && logoAvailableFor(email))
        ? '''
    <td style="padding-right:16px;vertical-align:middle;">
      <img src="cid:$kSignatureLogoCid" width="64" height="64"
           alt="${_esc(brand.companyName)}" style="display:block;border:0;outline:none;">
    </td>'''
        : '';

    final tagline = brand.tagline;
    final rows = StringBuffer();
    rows.write(
        '<div style="font-size:16px;font-weight:bold;color:$accent;letter-spacing:.3px;">'
        '${_esc(brand.companyName)}</div>');
    if (tagline != null && tagline.isNotEmpty) {
      rows.write(
          '<div style="color:#6b7c79;font-size:12px;margin-bottom:6px;">'
          '${_esc(tagline)}</div>');
    }
    if (name.isNotEmpty) {
      rows.write('<div style="font-weight:bold;">${_esc(name)}</div>');
    }
    if (title.isNotEmpty) {
      rows.write('<div style="color:#6b7c79;">${_esc(title)}</div>');
    }
    rows.write('<div style="margin-top:6px;">');
    if (phone.isNotEmpty) {
      rows.write(
          '<a href="tel:${_esc(phone.replaceAll(' ', ''))}" '
          'style="color:#1f2d2b;text-decoration:none;">&#9742;&nbsp;'
          '${_esc(phone)}</a><br>');
    }
    rows.write(
        '<a href="mailto:${_esc(email)}" style="color:#1f2d2b;text-decoration:none;">'
        '&#9993;&nbsp;${_esc(email)}</a>');
    if (web.isNotEmpty) {
      rows.write('<br><a href="${_esc(web)}" '
          'style="color:$accent;text-decoration:none;font-weight:bold;">'
          '&#127760;&nbsp;${_esc(webLabel)}</a>');
    }
    rows.write('</div>');
    if (address.isNotEmpty) {
      rows.write('<div style="color:#6b7c79;font-size:11px;margin-top:6px;">'
          '${_esc(address)}</div>');
    }

    return '''
<table cellpadding="0" cellspacing="0" border="0"
       style="font-family:Arial,Helvetica,sans-serif;color:#1f2d2b;font-size:13px;line-height:1.4;">
  <tr>$logoCell
    <td style="border-left:2px solid $accent;padding-left:16px;vertical-align:middle;">
      $rows
    </td>
  </tr>
</table>''';
  }
}

/// Per-account signature persistence (keyed by email address).
class SignatureStore {
  static String _key(String email) => 'sig.v1.${email.toLowerCase()}';

  static Future<Signature> load(String email) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key(email));
    if (raw == null || raw.isEmpty) return Signature.initial(email);
    try {
      return Signature.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return Signature.initial(email);
    }
  }

  static Future<void> save(String email, Signature s) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key(email), jsonEncode(s.toJson()));
  }
}
