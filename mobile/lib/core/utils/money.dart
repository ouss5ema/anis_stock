import 'package:decimal/decimal.dart';

Decimal parseMoney(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return Decimal.zero;
  }
  return Decimal.parse(raw.replaceAll(',', '.').trim());
}

String formatDt(String? raw, {int scale = 3}) {
  final value = parseMoney(raw);
  final text = value.toString();
  final parts = text.split('.');
  final fraction = (parts.length > 1 ? parts[1] : '').padRight(scale, '0');
  return '${parts[0]}.${fraction.substring(0, scale)}';
}

String formatDtLabel(String? raw) => '${formatDt(raw)} DT';

String multiplyMoney(String quantity, String unitPrice) {
  return formatDt((parseMoney(quantity) * parseMoney(unitPrice)).toString());
}

String addMoney(Iterable<String> amounts) {
  var total = Decimal.zero;
  for (final amount in amounts) {
    total += parseMoney(amount);
  }
  return formatDt(total.toString());
}

bool isPositiveMoney(String? raw) => parseMoney(raw) > Decimal.zero;

bool greaterThanMoney(String left, String right) {
  return parseMoney(left) > parseMoney(right);
}
