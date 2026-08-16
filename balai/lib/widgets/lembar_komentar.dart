import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/waktu.dart';
import '../data/auth_repository.dart';
import '../data/kiriman_repository.dart';
import '../models/kiriman.dart';
import '../models/warga.dart';
import 'foto_warga.dart';

/// Lembar komentar yang naik dari bawah layar.
class LembarKomentar extends StatefulWidget {
  const LembarKomentar({super.key, required this.kiriman, required this.saya});

  final Kiriman kiriman;
  final Warga? saya;

  static Future<void> buka(
    BuildContext context, {
    required Kiriman kiriman,
    required Warga? saya,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => LembarKomentar(kiriman: kiriman, saya: saya),
    );
  }

  @override
  State<LembarKomentar> createState() => _LembarKomentarState();
}

class _LembarKomentarState extends State<LembarKomentar> {
  final TextEditingController _tulis = TextEditingController();
  bool _mengirim = false;

  @override
  void dispose() {
    _tulis.dispose();
    super.dispose();
  }

  Future<void> _kirim() async {
    final saya = widget.saya;
    if (saya == null || _tulis.text.trim().isEmpty || _mengirim) return;

    setState(() => _mengirim = true);
    try {
      await KirimanRepository.tulisKomentar(
        kirimanId: widget.kiriman.id,
        penulis: saya,
        isi: _tulis.text,
      );
      _tulis.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AuthRepository.pesanRamah(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _mengirim = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = BalaiTheme.of(context);
    final bolehTulis = widget.saya?.bolehMenulis ?? false;

    return Padding(
      // Naikkan lembar setinggi papan ketik supaya kotak tulis tidak
      // tertutup saat warga mengetik.
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, gulir) {
          return Column(
            children: <Widget>[
              const SizedBox(height: 10),
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: t.garis,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Text('Komentar', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Divider(height: 1, color: t.garis),
              Expanded(
                child: StreamBuilder<List<Komentar>>(
                  stream: KirimanRepository.komentar(widget.kiriman.id),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final daftar = snap.data ?? const <Komentar>[];
                    if (daftar.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            'Belum ada komentar.\nJadilah yang pertama menyahut.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: t.tinta3, height: 1.6),
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      controller: gulir,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: daftar.length,
                      itemBuilder: (context, i) =>
                          _baris(context, t, daftar[i]),
                    );
                  },
                ),
              ),
              Divider(height: 1, color: t.garis),
              _kotakTulis(context, t, bolehTulis),
            ],
          );
        },
      ),
    );
  }

  Widget _baris(BuildContext context, BalaiTheme t, Komentar k) {
    final saya = widget.saya;
    final bolehHapus = saya != null &&
        (saya.uid == k.penulisUid ||
            saya.uid == widget.kiriman.penulisUid ||
            saya.kepalaDesa);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 9, 6, 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          FotoWarga(nama: k.penulisNama, foto: k.penulisFoto, ukuran: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        k.penulisNama,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      Waktu.lalu(k.dibuat),
                      style: TextStyle(fontSize: 11.5, color: t.tinta3),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(k.isi, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          if (bolehHapus)
            IconButton(
              icon: Icon(Icons.close, size: 18, color: t.tinta3),
              tooltip: 'Hapus komentar',
              onPressed: () => KirimanRepository.hapusKomentar(
                kirimanId: widget.kiriman.id,
                komentarId: k.id,
              ),
            ),
        ],
      ),
    );
  }

  Widget _kotakTulis(BuildContext context, BalaiTheme t, bool bolehTulis) {
    if (!bolehTulis) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
        child: Text(
          'Akun Anda menunggu persetujuan kepala desa sebelum bisa '
          'berkomentar.',
          textAlign: TextAlign.center,
          style: TextStyle(color: t.tinta3, fontSize: 13, height: 1.5),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: _tulis,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Tulis komentar…'),
              onSubmitted: (_) => _kirim(),
            ),
          ),
          const SizedBox(width: 6),
          IconButton.filled(
            onPressed: _mengirim ? null : _kirim,
            icon: _mengirim
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}
