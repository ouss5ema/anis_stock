import 'package:flutter/material.dart';
import 'package:stock_management/core/theme/app_colors.dart';
import 'package:stock_management/core/theme/app_tokens.dart';
import 'package:stock_management/core/utils/formatters.dart';
import 'package:stock_management/core/utils/labels.dart';
import 'package:stock_management/core/widgets/ui_kit.dart';
import 'package:stock_management/data/models/product.dart';

/// Out-of-stock and low-stock alerts. [onOpenFilter] receives `out` or `low`
/// so the Stock tab opens with the matching filter.
class StockAlertCard extends StatelessWidget {
  const StockAlertCard({
    super.key,
    required this.outOfStockCount,
    required this.lowStockCount,
    required this.outOfStockProducts,
    required this.lowStockProducts,
    required this.onOpenFilter,
    this.maxProducts = 3,
  });

  final int outOfStockCount;
  final int lowStockCount;
  final List<Product> outOfStockProducts;
  final List<Product> lowStockProducts;
  final ValueChanged<String> onOpenFilter;
  final int maxProducts;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;

    if (outOfStockCount == 0 && lowStockCount == 0) {
      return Semantics(
        label: 'Aucune alerte stock',
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: colors.successContainer,
            borderRadius: AppRadius.mdAll,
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle_outline, color: colors.success, size: 20),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Aucune alerte stock',
                  style: text.bodyMedium?.copyWith(color: colors.success, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final products = [
      ...outOfStockProducts.map((product) => (product, 'out')),
      ...lowStockProducts.map((product) => (product, 'low')),
    ].take(maxProducts).toList();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: _AlertCounter(
                    label: 'Rupture',
                    count: outOfStockCount,
                    color: colors.danger,
                    containerColor: colors.dangerContainer,
                    icon: Icons.remove_shopping_cart_outlined,
                    onTap: () => onOpenFilter('out'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _AlertCounter(
                    label: 'Stock faible',
                    count: lowStockCount,
                    color: colors.warning,
                    containerColor: colors.warningContainer,
                    icon: Icons.trending_down_rounded,
                    onTap: () => onOpenFilter('low'),
                  ),
                ),
              ],
            ),
          ),
          for (final (product, filter) in products) ...[
            const Divider(height: 1),
            _AlertProductTile(
              product: product,
              isOut: filter == 'out',
              onTap: () => onOpenFilter(filter),
            ),
          ],
        ],
      ),
    );
  }
}

class _AlertCounter extends StatelessWidget {
  const _AlertCounter({
    required this.label,
    required this.count,
    required this.color,
    required this.containerColor,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final int count;
  final Color color;
  final Color containerColor;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final active = count > 0;
    final fg = active ? color : scheme.onSurfaceVariant;

    return Semantics(
      button: true,
      label: '$label : ${pluralize(count, 'produit')}. Ouvrir le stock filtré',
      excludeSemantics: true,
      child: Material(
        color: active ? containerColor : scheme.surfaceContainerLow,
        borderRadius: AppRadius.mdAll,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.mdAll,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
              child: Row(
                children: [
                  Icon(icon, color: fg),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          formatCount(count),
                          style: text.titleLarge?.copyWith(color: fg, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall?.copyWith(color: fg, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: fg),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AlertProductTile extends StatelessWidget {
  const _AlertProductTile({required this.product, required this.isOut, required this.onTap});

  final Product product;
  final bool isOut;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final color = isOut ? colors.danger : colors.warning;
    return ListTile(
      onTap: onTap,
      minTileHeight: AppSpacing.minTouch,
      dense: true,
      leading: Icon(Icons.circle, size: 10, color: color),
      minLeadingWidth: AppSpacing.sm,
      title: Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        'Stock ${formatQuantity(product.currentStock)} ${unitLabel(product.unit)} · seuil ${formatQuantity(product.minimumStock)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: scheme.onSurfaceVariant),
      ),
      trailing: StockStatusChip(status: isOut ? 'OUT' : 'LOW'),
    );
  }
}
