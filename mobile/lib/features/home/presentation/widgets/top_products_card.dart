import 'package:flutter/material.dart';
import 'package:stock_management/core/theme/app_colors.dart';
import 'package:stock_management/core/theme/app_tokens.dart';
import 'package:stock_management/core/utils/formatters.dart';
import 'package:stock_management/core/utils/money.dart';
import 'package:stock_management/data/models/documents.dart';

/// Best sellers of the period with a bar proportional to the amount sold.
class TopProductsCard extends StatelessWidget {
  const TopProductsCard({super.key, required this.products});

  final List<TopProduct> products;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final max = products
        .map((product) => parseMoney(product.amount).toDouble())
        .fold<double>(0, (a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            for (var i = 0; i < products.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSpacing.sm),
              Semantics(
                label:
                    '${i + 1}. ${products[i].name}, ${formatQuantity(products[i].quantity)} vendus, ${formatAmount(products[i].amount)}',
                excludeSemantics: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${i + 1}',
                          style: text.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          flex: 3,
                          child: Text(
                            products[i].name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        // Large amounts scale down instead of overflowing.
                        Flexible(
                          flex: 2,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              formatAmount(products[i].amount),
                              style: text.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: AppRadius.pillAll,
                            child: LinearProgressIndicator(
                              value: max == 0 ? 0 : parseMoney(products[i].amount).toDouble() / max,
                              minHeight: 6,
                              color: colors.accent,
                              backgroundColor: scheme.surfaceContainer,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          'Qté ${formatQuantity(products[i].quantity)}',
                          style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
