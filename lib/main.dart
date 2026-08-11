import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'phone_otp.dart';
import 'screens/customer_shell.dart';
import 'screens/owner_shell.dart';
import 'screens/role_select_screen.dart';
import 'screens/splash_screen.dart';
import 'store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PhoneOtp.init();
  await store.init();
  runApp(const H2OLaundryApp());
}

class H2OLaundryApp extends StatelessWidget {
  const H2OLaundryApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF0891B2));
    return MaterialApp(
      title: 'H2O Laundry Parakan',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme,
        scaffoldBackgroundColor: const Color(0xFFF5F8FA),
        fontFamily: 'PlusJakartaSans',
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
          ),
          color: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFFF5F8FA),
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
          titleTextStyle: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
      ),
      // Di web (PWA/browser) huruf terasa lebih kecil daripada di
      // aplikasi Android — besarkan seluruh teks 12%.
      builder: (context, child) {
        if (!kIsWeb || child == null) return child ?? const SizedBox();
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
              textScaler: TextScaler.linear(
                  mq.textScaler.scale(1) * 1.12)),
          child: child,
        );
      },
      home: const SplashGate(),
    );
  }
}

/// Tampilkan splash bergelembung dulu, lalu masuk ke aplikasi.
class SplashGate extends StatefulWidget {
  const SplashGate({super.key});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool _showSplash = true;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      child: _showSplash
          ? SplashScreen(
              onFinished: () => setState(() => _showSplash = false))
          : const RootGate(),
    );
  }
}

/// Mengarahkan ke pemilihan mode, mode pelanggan, atau mode pemilik.
class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        switch (store.role) {
          case 'customer':
            return const CustomerShell();
          case 'owner':
            return const OwnerShell();
          default:
            return const RoleSelectScreen();
        }
      },
    );
  }
}
