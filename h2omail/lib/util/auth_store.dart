import 'package:shared_preferences/shared_preferences.dart';

class SavedLogin {
  final String server;
  final String email;
  final String password;
  const SavedLogin(
      {required this.server, required this.email, required this.password});
}

/// Stores the last successful login on the device so the app can auto-login.
class AuthStore {
  static const _kServer = 'auth.server';
  static const _kEmail = 'auth.email';
  static const _kPassword = 'auth.password';

  static Future<void> save(SavedLogin login) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kServer, login.server);
    await p.setString(_kEmail, login.email);
    await p.setString(_kPassword, login.password);
  }

  static Future<SavedLogin?> load() async {
    final p = await SharedPreferences.getInstance();
    final server = p.getString(_kServer);
    final email = p.getString(_kEmail);
    final password = p.getString(_kPassword);
    if (server == null || email == null || password == null) return null;
    if (server.isEmpty || email.isEmpty || password.isEmpty) return null;
    return SavedLogin(server: server, email: email, password: password);
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kServer);
    await p.remove(_kEmail);
    await p.remove(_kPassword);
  }
}
