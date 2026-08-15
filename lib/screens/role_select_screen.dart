import 'package:flutter/material.dart';

import 'customer_login_screen.dart';
import 'owner_access.dart';

class RoleSelectScreen extends StatefulWidget {
  const RoleSelectScreen({super.key});

  @override
  State<RoleSelectScreen> createState() => _RoleSelectScreenState();
}

class _RoleSelectScreenState extends State<RoleSelectScreen> {
  final _secretTaps = SecretTapCounter();

  void _onLogoTap() {
    if (_secretTaps.registerTap(context)) enterOwnerMode(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Gelembung dekoratif di latar.
            const Positioned.fill(
              child: IgnorePointer(child: _BubbleBackdrop()),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Logo besar; tetap jadi tombol rahasia Mode Pemilik.
                      GestureDetector(
                        onTap: _onLogoTap,
                        child: Image.asset(
                          'assets/logo.png',
                          height: 250,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'PARAKAN',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 6,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Laundry bersih, wangi, dan rapi.\n'
                        'Antar & ambil langsung di counter kami.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 36),
                      _RoleCard(
                        icon: Icons.person,
                        title: 'Saya Pelanggan',
                        subtitle: 'Masuk dengan nama & no. HP untuk '
                            'memesan dan melacak cucian',
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) =>
                                    const CustomerLoginScreen())),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Gelembung sabun translusen sebagai hiasan latar layar depan.
class _BubbleBackdrop extends StatelessWidget {
  const _BubbleBackdrop();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _BubblePainter());
  }
}

class _BubblePainter extends CustomPainter {
  static const _bubbles = [
    // (x, y, radius, opacity) dalam fraksi lebar/tinggi layar.
    (0.10, 0.08, 34.0, 0.20),
    (0.88, 0.05, 52.0, 0.16),
    (0.94, 0.30, 24.0, 0.22),
    (0.06, 0.34, 18.0, 0.26),
    (0.90, 0.58, 38.0, 0.16),
    (0.08, 0.66, 26.0, 0.20),
    (0.16, 0.90, 44.0, 0.14),
    (0.86, 0.86, 30.0, 0.20),
    (0.50, 0.965, 20.0, 0.20),
    (0.35, 0.045, 14.0, 0.24),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    const base = Color(0xFF38BDF8);
    for (final (fx, fy, r, a) in _bubbles) {
      final c = Offset(size.width * fx, size.height * fy);
      final paint = Paint()..color = base.withValues(alpha: a);
      canvas.drawCircle(c, r, paint);
      // Kilau kecil di kiri-atas gelembung.
      canvas.drawCircle(
        c.translate(-r * 0.32, -r * 0.32),
        r * 0.24,
        Paint()..color = Colors.white.withValues(alpha: a + 0.15),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BubblePainter oldDelegate) => false;
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon,
                    size: 28, color: theme.colorScheme.onPrimaryContainer),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
