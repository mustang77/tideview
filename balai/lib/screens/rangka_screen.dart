import 'package:flutter/material.dart';

import '../core/config.dart';
import '../core/theme.dart';
import '../data/auth_repository.dart';
import '../models/warga.dart';
import 'acara_screen.dart';
import 'beranda_screen.dart';
import 'saya_screen.dart';
import 'tulis_screen.dart';
import 'warga_screen.dart';

/// Rangka aplikasi: kepala halaman, empat tab di bawah, dan tombol tulis.
///
/// Profil warga dimuat satu kali di sini lalu diteruskan ke bawah, supaya
/// keempat tab tidak masing-masing membuka aliran data sendiri ke Firestore.
class RangkaScreen extends StatefulWidget {
  const RangkaScreen({super.key});

  @override
  State<RangkaScreen> createState() => _RangkaScreenState();
}

class _RangkaScreenState extends State<RangkaScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Warga?>(
      stream: AuthRepository.profilSaya(),
      builder: (context, snap) {
        final saya = snap.data;
        final t = BalaiTheme.of(context);

        final halaman = <Widget>[
          BerandaScreen(saya: saya),
          AcaraScreen(saya: saya),
          const WargaScreen(),
          SayaScreen(saya: saya),
        ];

        return Scaffold(
          appBar: _tab == 0
              ? AppBar(
                  titleSpacing: 18,
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        BalaiConfig.namaAplikasi,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text(
                        BalaiConfig.namaDesa,
                        style: TextStyle(fontSize: 11.5, color: t.tinta3),
                      ),
                    ],
                  ),
                )
              : null,
          body: SafeArea(child: halaman[_tab]),
          floatingActionButton: _tab == 0 && (saya?.bolehMenulis ?? false)
              ? FloatingActionButton(
                  onPressed: () => TulisScreen.buka(context, saya: saya!),
                  tooltip: 'Tulis kiriman',
                  child: const Icon(Icons.add, size: 28),
                )
              : null,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: const <NavigationDestination>[
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Beranda',
              ),
              NavigationDestination(
                icon: Icon(Icons.event_outlined),
                selectedIcon: Icon(Icons.event),
                label: 'Acara',
              ),
              NavigationDestination(
                icon: Icon(Icons.groups_outlined),
                selectedIcon: Icon(Icons.groups),
                label: 'Warga',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Saya',
              ),
            ],
          ),
        );
      },
    );
  }
}
