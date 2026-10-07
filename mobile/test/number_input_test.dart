import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_management/core/utils/money.dart';
import 'package:stock_management/core/utils/number_input.dart';

void main() {
  test('normalizes French comma and dot to an API decimal', () {
    expect(normalizeDecimalInput('12,5'), '12.5');
    expect(normalizeDecimalInput('12.5'), '12.5');
    expect(normalizeDecimalInput(' 1 234,500 '), '1234.500');
    expect(normalizeDecimalInput('12,'), '12');
    expect(normalizeDecimalInput(',5'), '0.5');
    expect(normalizeDecimalInput('7'), '7');
  });

  test('rejects invalid decimals', () {
    expect(normalizeDecimalInput('1,2,3'), isNull);
    expect(normalizeDecimalInput('1.2,3'), isNull);
    expect(normalizeDecimalInput('abc'), isNull);
    expect(normalizeDecimalInput(''), isNull);
    expect(normalizeDecimalInput(','), isNull);
  });

  test('parses to Decimal', () {
    expect(tryParseDecimalInput('12,5'), Decimal.parse('12.5'));
    expect(tryParseDecimalInput('1,2,3'), isNull);
    expect(parseMoney('12,5'), Decimal.parse('12.5'));
    expect(parseMoney('1,2,3'), Decimal.zero);
    expect(isPositiveMoney('0,5'), isTrue);
  });

  test('API value stays compatible with the backend Number() validation', () {
    expect(decimalForApi('12,5'), '12.5');
    expect(decimalForApi('1 234.500'), '1234.500');
    expect(decimalForApi('1,2,3'), '1,2,3');
    expect(formatDecimalForInput('1234.5'), '1234.500');
  });

  group('DecimalInputFormatter', () {
    final formatter = DecimalInputFormatter();
    TextEditingValue apply(String oldText, String newText) => formatter.formatEditUpdate(
          TextEditingValue(text: oldText),
          TextEditingValue(text: newText),
        );

    test('accepts a single separator', () {
      expect(apply('12', '12,').text, '12,');
      expect(apply('12,', '12,5').text, '12,5');
      expect(apply('12', '12.').text, '12.');
    });

    test('rejects a second separator, letters and extra decimals', () {
      expect(apply('12,5', '12,5,').text, '12,5');
      expect(apply('12.5', '12.5.').text, '12.5');
      expect(apply('12', '12a').text, '12');
      expect(apply('1,234', '1,2345').text, '1,234');
      expect(apply('1', '-1').text, '1');
    });
  });
}
