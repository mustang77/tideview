import 'package:flutter/material.dart';

import '../models/kategori.dart';

/// Label kecil bertuliskan jenis kiriman: "Dijual", "Butuh bantuan", dan
/// seterusnya.
class LabelKategori extends StatelessWidget {
  const LabelKategori(this.kategori, {super.key});

  final Kategori kategori;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: kategori.warnaLatar(context),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        kategori.label,
        style: TextStyle(
          color: kategori.warna(context),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// Tombol pilihan berbentuk pil, dipakai untuk memilih kategori saat menulis
/// dan menyaring keahlian di buku warga.
class PilPilihan extends StatelessWidget {
  const PilPilihan({
    super.key,
    required this.label,
    required this.terpilih,
    required this.onTap,
  });

  final String label;
  final bool terpilih;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    return Material(
      color: terpilih ? skema.primary : skema.surface,
      shape: StadiumBorder(
        side: BorderSide(
          color: terpilih ? skema.primary : skema.outline,
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: terpilih ? skema.onPrimary : skema.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
