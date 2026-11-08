const List<String> _weekdaysEs = [
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
  'domingo',
];

const List<String> _monthsEs = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

/// Formatea una fecha como "viernes, 8 de agosto" (es-CO), sin depender del
/// paquete intl.
String formatSpanishLongDate(DateTime date) {
  final weekday = _weekdaysEs[date.weekday - 1];
  final month = _monthsEs[date.month - 1];
  return '$weekday, ${date.day} de $month';
}

/// "hace 5 min", "hace 3 h", "Ayer", "12 ago" a partir de un ISO-8601.
String relativeSpanish(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final t = DateTime.tryParse(iso);
  if (t == null) return '';
  final d = DateTime.now().difference(t);
  if (d.inSeconds < 60) return 'hace un momento';
  if (d.inMinutes < 60) return 'hace ${d.inMinutes} min';
  if (d.inHours < 24) return 'hace ${d.inHours} h';
  if (d.inDays == 1) return 'Ayer';
  if (d.inDays < 7) return 'hace ${d.inDays} días';
  final local = t.toLocal();
  return '${local.day} ${_monthsEs[local.month - 1].substring(0, 3)}';
}

/// "14 KB", "2.4 MB", "1.2 GB".
String formatBytes(num bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var value = bytes / 1024;
  var i = 0;
  while (value >= 1024 && i < units.length - 1) {
    value /= 1024;
    i++;
  }
  final s = value >= 10 || value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
  return '$s ${units[i]}';
}

/// "hh:mm:ss" a partir de segundos.
String formatDuration(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  final mm = m.toString().padLeft(2, '0');
  final ss = s.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
}
