import 'package:flutter_test/flutter_test.dart';
import 'package:stock_management/core/utils/formatters.dart';

/// intl uses a narrow no-break space as French thousands separator.
String plain(String value) => value.replaceAll(' ', ' ').replaceAll(' ', ' ');

void main() {
  group('amounts', () {
    test('French format with thousands separator, comma and DT', () {
      expect(plain(formatAmount('1250')), '1 250,000 DT');
      expect(plain(formatAmount('1250.5')), '1 250,500 DT');
      expect(plain(formatAmount('0')), '0,000 DT');
      expect(plain(formatAmount('999999999.999')), '999 999 999,999 DT');
      expect(plain(formatAmount(null)), '0,000 DT');
    });
  });

  group('quantities', () {
    test('drop useless decimals', () {
      expect(formatQuantity('11.000'), '11');
      expect(formatQuantity('2.500'), '2,5');
      expect(formatQuantity('0.125'), '0,125');
      expect(plain(formatQuantity('1500')), '1 500');
    });

    test('signed quantities for movements', () {
      expect(formatSignedQuantity('12.000'), '+12');
      expect(formatSignedQuantity('-3.000'), '−3');
      expect(formatSignedQuantity('0'), '0');
    });

    test('plural labels', () {
      expect(pluralize(0, 'vente'), '0 vente');
      expect(pluralize(1, 'vente'), '1 vente');
      expect(pluralize(3, 'vente'), '3 ventes');
    });
  });

  group('variation', () {
    test('previous period at zero never divides by zero', () {
      final variation = Variation.compute('150', '0');
      expect(variation, isNotNull);
      expect(variation!.label, 'Nouveau');
      expect(variation.isNew, isTrue);
      expect(Variation.compute('0', '0'), isNull);
    });

    test('percentage up and down', () {
      expect(Variation.compute('125', '100')!.label, '+25 %');
      expect(Variation.compute('125', '100')!.direction, VariationDirection.up);
      expect(Variation.compute('50', '100')!.label, '−50 %');
      expect(Variation.compute('50', '100')!.direction, VariationDirection.down);
      expect(Variation.compute('100.2', '100')!.direction, VariationDirection.flat);
      expect(Variation.compute('0', '80')!.label, '−100 %');
    });
  });

  group('dates', () {
    test('long French date', () {
      expect(formatLongDate(DateTime(2026, 10, 7)), 'mercredi 7 octobre');
    });

    test('activity time is relative, then HH:mm today, then day + time', () {
      final now = DateTime(2026, 10, 7, 14, 30);
      expect(formatActivityTime(now.subtract(const Duration(seconds: 20)), now: now), 'À l’instant');
      expect(formatActivityTime(now.subtract(const Duration(minutes: 5)), now: now), 'il y a 5 min');
      expect(formatActivityTime(DateTime(2026, 10, 7, 9, 5), now: now), '09:05');
      expect(formatActivityTime(DateTime(2026, 10, 6, 18, 40), now: now), '06/10 18:40');
    });
  });
}
