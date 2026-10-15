/// 7.5 -> "7,5", 25.0 -> "25", null -> "-".
String formatWeight(double? weight) {
  if (weight == null) return '-';
  final text = weight.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  return text.replaceAll('.', ',');
}

/// [25, 30, 35] -> "25-30-35", [25] -> "25", vacío o null -> "-".
String formatWeights(List<double>? weights) {
  if (weights == null || weights.isEmpty) return '-';
  return weights.map(formatWeight).join('-');
}

/// Acepta tanto "7,5" como "7.5". Devuelve null si está vacío o no es válido.
double? parseWeight(String text) {
  return double.tryParse(text.trim().replaceAll(',', '.'));
}

/// dd/MM/yy
String formatDate(DateTime date) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${two(date.year % 100)}';
}

DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

const _weekdayNames = [
  'LUNES',
  'MARTES',
  'MIÉRCOLES',
  'JUEVES',
  'VIERNES',
  'SÁBADO',
  'DOMINGO',
];

/// "LUNES 14/10/26"
String formatDateWithWeekday(DateTime date) =>
    '${_weekdayNames[date.weekday - 1]} ${formatDate(date)}';

/// 25000 -> "$ 25.000", 1500.5 -> "$ 1.500,50".
String formatMoney(double amount) {
  final cents = (amount * 100).round();
  final whole = (cents ~/ 100).toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+$)'),
    (_) => '.',
  );
  final rest = cents % 100;
  return rest == 0
      ? '\$ $whole'
      : '\$ $whole,${rest.toString().padLeft(2, '0')}';
}
