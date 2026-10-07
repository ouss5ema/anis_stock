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
  final digits = parts[0].replaceAll('-', '');
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final remaining = digits.length - i;
    if (i > 0 && remaining % 3 == 0) {
      buffer.write(' ');
    }
    buffer.write(digits[i]);
  }
  final grouped = parts[0].startsWith('-') ? '-$buffer' : buffer.toString();
  return '$grouped.${fraction.substring(0, scale)}';
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
