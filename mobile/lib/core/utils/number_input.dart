import 'package:decimal/decimal.dart';
import 'package:flutter/services.dart';

final _spaces = RegExp(r'[\s  ]');
final _decimalPattern = RegExp(r'^-?(\d+([.,]\d*)?|[.,]\d+)$');

/// Normalizes a user-typed decimal for parsing and for the API:
/// accepts `,` or `.` as separator and ignores thousands spaces.
/// `'12,5'` -> `'12.5'`, `'1 234,500'` -> `'1234.500'`, `'1,2,3'` -> null.
/// Returns null for empty or invalid input.
String? normalizeDecimalInput(String? raw) {
  if (raw == null) {
    return null;
  }
  final cleaned = raw.replaceAll(_spaces, '');
  if (!_decimalPattern.hasMatch(cleaned)) {
    return null;
  }
  var normalized = cleaned.replaceAll(',', '.');
  if (normalized.endsWith('.')) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  if (normalized.startsWith('.')) {
    normalized = '0$normalized';
  } else if (normalized.startsWith('-.')) {
    normalized = '-0${normalized.substring(1)}';
  }
  return normalized;
}

Decimal? tryParseDecimalInput(String? raw) {
  final normalized = normalizeDecimalInput(raw);
  return normalized == null ? null : Decimal.tryParse(normalized);
}

/// Value sent to the API: normalized when valid, otherwise the trimmed raw
/// text so the backend validation reports the error.
String decimalForApi(String raw) => normalizeDecimalInput(raw) ?? raw.trim();

/// Accepts digits and a single `,` or `.` separator, matching the database
/// precision Decimal(12, 3): 9 integer digits and 3 decimals by default.
class DecimalInputFormatter extends TextInputFormatter {
  DecimalInputFormatter({this.maxIntegerDigits = 9, this.maxDecimals = 3})
      : _pattern = RegExp('^\\d{0,$maxIntegerDigits}([.,]\\d{0,$maxDecimals})?\$');

  final int maxIntegerDigits;
  final int maxDecimals;
  final RegExp _pattern;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return _pattern.hasMatch(newValue.text) ? newValue : oldValue;
  }
}
