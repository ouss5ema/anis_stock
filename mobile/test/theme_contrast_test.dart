import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_management/core/theme/app_colors.dart';

double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  const white = Color(0xFFFFFFFF);
  const colors = AppColors.light;

  test('text colors reach WCAG AA (4.5:1) on their backgrounds', () {
    final pairs = <String, (Color, Color)>{
      'primary on white': (BrandPalette.primary, white),
      'white on primary': (white, BrandPalette.primary),
      'white on header start': (colors.onHeader, colors.brandDeep),
      'muted header text on primary': (colors.onHeaderMuted, BrandPalette.primary),
      'sale on white': (colors.sale, white),
      'sale on container': (colors.sale, colors.saleContainer),
      'white on sale button': (white, colors.sale),
      'purchase on white': (colors.purchase, white),
      'purchase on container': (colors.purchase, colors.purchaseContainer),
      'white on purchase button': (white, colors.purchase),
      'warning on white': (colors.warning, white),
      'warning on container': (colors.warning, colors.warningContainer),
      'danger on white': (colors.danger, white),
      'danger on container': (colors.danger, colors.dangerContainer),
      'neutral on white': (colors.neutral, white),
      'neutral on container': (colors.neutral, colors.neutralContainer),
    };
    for (final entry in pairs.entries) {
      expect(
        contrast(entry.value.$1, entry.value.$2),
        greaterThanOrEqualTo(4.5),
        reason: entry.key,
      );
    }
  });

  test('cyan accent is too light for text and stays decorative', () {
    expect(contrast(BrandPalette.cyan, white), lessThan(3));
  });
}
