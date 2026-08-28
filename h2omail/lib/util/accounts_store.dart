import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SavedAccount {
  final String server;
  final String email;
  final String password;
  const SavedAccount(
      {required this.server, required this.email, required this.password});

  Map<String, dynamic> toJson() =>
      {'server': server, 'email': email, 'password': password};

  factory SavedAccount.fromJson(Map<String, dynamic> j) => SavedAccount(
        server: (j['server'] ?? '') as String,
        email: (j['email'] ?? '') as String,
        password: (j['password'] ?? '') as String,
      );
}

/// Stores every signed-in account on the device (Gmail-style multi-account).
class AccountsStore {
  static const _kAccounts = 'accounts.v1';
  static const _kActive = 'accounts.active';
  // Legacy single-account keys (pre multi-account builds).
  static const _kOldServer = 'auth.server';
  static const _kOldEmail = 'auth.email';
  static const _kOldPassword = 'auth.password';

  static Future<List<SavedAccount>> list() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kAccounts);
    if (raw != null && raw.isNotEmpty) {
      try {
        final l = (jsonDecode(raw) as List)
            .cast<Map<String, dynamic>>()
            .map(SavedAccount.fromJson)
            .where((a) => a.email.isNotEmpty)
            .toList();
        return l;
      } catch (_) {}
    }
    // One-time migration from the old single-account storage.
    final server = p.getString(_kOldServer);
    final email = p.getString(_kOldEmail);
    final password = p.getString(_kOldPassword);
    if (server != null && email != null && password != null) {
      final migrated = [
        SavedAccount(server: server, email: email, password: password)
      ];
      await _save(migrated);
      await p.remove(_kOldServer);
      await p.remove(_kOldEmail);
      await p.remove(_kOldPassword);
      return migrated;
    }
    return [];
  }

  static Future<void> _save(List<SavedAccount> accounts) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
        _kAccounts, jsonEncode(accounts.map((a) => a.toJson()).toList()));
  }

  static Future<int> activeIndex() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_kActive) ?? 0;
  }

  static Future<void> setActive(int i) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kActive, i);
  }

  static Future<SavedAccount?> active() async {
    final accounts = await list();
    if (accounts.isEmpty) return null;
    final i = await activeIndex();
    return accounts[i >= 0 && i < accounts.length ? i : 0];
  }

  /// Adds (or updates) an account and makes it active.
  static Future<void> upsert(SavedAccount a) async {
    final accounts = await list();
    final i = accounts.indexWhere(
        (x) => x.email.toLowerCase() == a.email.toLowerCase() &&
            x.server == a.server);
    if (i >= 0) {
      accounts[i] = a;
      await _save(accounts);
      await setActive(i);
    } else {
      accounts.add(a);
      await _save(accounts);
      await setActive(accounts.length - 1);
    }
  }

  /// Removes the active account; returns the remaining accounts.
  static Future<List<SavedAccount>> removeActive() async {
    final accounts = await list();
    if (accounts.isEmpty) return accounts;
    final i = await activeIndex();
    final idx = i >= 0 && i < accounts.length ? i : 0;
    accounts.removeAt(idx);
    await _save(accounts);
    await setActive(0);
    return accounts;
  }
}
