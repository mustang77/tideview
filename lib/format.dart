/// Format angka dan tanggal gaya Indonesia tanpa dependensi tambahan.
library;

String rupiah(num value) {
  final v = value.round();
  final s = v.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return '${v < 0 ? '-' : ''}Rp $buf';
}

/// "2,5 kg" / "3 pcs" — buang desimal kalau bulat, koma gaya Indonesia.
String qtyText(double qty, String unit) {
  final text = qty == qty.roundToDouble()
      ? qty.toInt().toString()
      : qty.toStringAsFixed(1).replaceAll('.', ',');
  return '$text $unit';
}

const _days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
const _months = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];

String dayName(DateTime d) => _days[d.weekday - 1];
String monthName(DateTime d) => _months[d.month - 1];
String monthShort(DateTime d) => _months[d.month - 1].substring(0, 3);

String _two(int n) => n.toString().padLeft(2, '0');

/// "Sen, 10 Agu 2026"
String shortDate(DateTime d) =>
    '${dayName(d).substring(0, 3)}, ${d.day} ${monthShort(d)} ${d.year}';

/// "Senin, 10 Agustus 2026"
String fullDate(DateTime d) =>
    '${dayName(d)}, ${d.day} ${monthName(d)} ${d.year}';

/// "14:05"
String timeText(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

/// "Sen, 10 Agu 2026 • 14:05"
String dateTimeText(DateTime d) => '${shortDate(d)} • ${timeText(d)}';

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
