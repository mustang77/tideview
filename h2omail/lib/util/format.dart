const _monthsId = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
];

String formatDateShort(DateTime? d) {
  if (d == null) return '';
  final now = DateTime.now();
  if (d.year == now.year && d.month == now.month && d.day == now.day) {
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
  if (d.year == now.year) return '${d.day} ${_monthsId[d.month - 1]}';
  return '${d.day} ${_monthsId[d.month - 1]} ${d.year}';
}

String formatDateFull(DateTime? d) {
  if (d == null) return '';
  return '${d.day} ${_monthsId[d.month - 1]} ${d.year}, '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

String formatSize(int bytes) {
  if (bytes >= 1048576) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '$bytes B';
}
