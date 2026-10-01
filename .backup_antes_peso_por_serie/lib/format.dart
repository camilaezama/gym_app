/// 7.5 -> "7,5", 25.0 -> "25", null -> "-".
String formatWeight(double? weight) {
  if (weight == null) return '-';
  final text = weight.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  return text.replaceAll('.', ',');
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
