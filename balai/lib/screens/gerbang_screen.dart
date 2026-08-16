import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/auth_repository.dart';
import 'masuk_screen.dart';
import 'rangka_screen.dart';

/// Memilih antara layar masuk dan isi aplikasi, mengikuti keadaan akun.
///
/// Semua layar lain boleh menganggap warga sudah masuk, karena hanya lewat
/// sini jalannya.
class GerbangScreen extends StatelessWidget {
  const GerbangScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthRepository.perubahanAkun(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.data == null) return const MasukScreen();
        return const RangkaScreen();
      },
    );
  }
}
