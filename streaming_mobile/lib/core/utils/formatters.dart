/// Fungsi-fungsi format untuk tampilan UI.

/// Mengformat durasi dalam menit ke format 'Xj Ym'.
/// Contoh: formatDuration(125) → '2j 5m'
String formatDuration(int? minutes) {
  if (minutes == null || minutes <= 0) return '-';
  final hours = minutes ~/ 60;
  final mins = minutes % 60;
  if (hours == 0) return '${mins}m';
  if (mins == 0) return '${hours}j';
  return '${hours}j ${mins}m';
}

/// Mengambil tahun dari ISO date string.
/// Contoh: formatYear('2024-05-15') → '2024'
String formatYear(String? isoDate) {
  if (isoDate == null || isoDate.length < 4) return '-';
  return isoDate.substring(0, 4);
}

/// Mengformat tanggal ISO ke format lokal (DD/MM/YYYY).
/// Contoh: formatDate('2024-05-15') → '15/05/2024'
String formatDate(String? isoDate) {
  if (isoDate == null || isoDate.length < 10) return '-';
  final parts = isoDate.substring(0, 10).split('-');
  if (parts.length != 3) return isoDate;
  return '${parts[2]}/${parts[1]}/${parts[0]}';
}
