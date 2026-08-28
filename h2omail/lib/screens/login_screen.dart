import 'package:flutter/material.dart';

import '../jmap/jmap_client.dart';
import '../util/accounts_store.dart';
import '../util/brand.dart';
import 'mail_home_screen.dart';

class LoginScreen extends StatefulWidget {
  /// When true this screen adds another account (no auto-login).
  final bool adding;
  const LoginScreen({super.key, this.adding = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _server = TextEditingController(text: Brand.defaultServer);
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (!widget.adding) _tryAutoLogin();
  }

  Future<void> _tryAutoLogin() async {
    final saved = await AccountsStore.active();
    if (saved == null || !mounted) return;
    _server.text = saved.server;
    _email.text = saved.email;
    _password.text = saved.password;
    await _login();
  }

  Future<void> _login() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Isi email dan password dulu.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final client = JmapClient(
      server: _server.text.trim(),
      username: email,
      password: password,
    );
    try {
      await client.connect();
      await AccountsStore.upsert(SavedAccount(
          server: client.server, email: email, password: password));
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => MailHomeScreen(client: client)),
        (_) => false,
      );
    } on JmapException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Gagal terhubung: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: widget.adding
          ? AppBar(title: const Text('Tambah Akun'))
          : null,
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Card(
              margin: const EdgeInsets.all(24),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Brand.icon, size: 56, color: cs.primary),
                    const SizedBox(height: 8),
                    Text(Brand.name,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 24),
                    if (!Brand.serverLocked) ...[
                      TextField(
                        controller: _server,
                        decoration: const InputDecoration(
                          labelText: 'Server',
                          prefixIcon: Icon(Icons.dns_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.username],
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.alternate_email),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _password,
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      onSubmitted: (_) => _busy ? null : _login(),
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock_outline),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: TextStyle(color: cs.error),
                          textAlign: TextAlign.center),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _busy ? null : _login,
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Masuk'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
