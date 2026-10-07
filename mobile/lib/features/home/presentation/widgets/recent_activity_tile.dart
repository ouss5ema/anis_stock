import 'package:flutter/material.dart';
import 'package:stock_management/core/theme/app_colors.dart';
import 'package:stock_management/core/theme/app_tokens.dart';
import 'package:stock_management/core/utils/formatters.dart';
import 'package:stock_management/core/utils/labels.dart';
import 'package:stock_management/data/models/documents.dart';

/// Icon and colors for a stock movement type.
({IconData icon, Color color, Color container}) movementStyle(AppColors colors, String type) {
  switch (type) {
    case 'SALE':
      return (icon: Icons.point_of_sale_outlined, color: colors.sale, container: colors.saleContainer);
    case 'PURCHASE':
      return (icon: Icons.local_shipping_outlined, color: colors.purchase, container: colors.purchaseContainer);
    case 'ADJUSTMENT_IN':
      return (icon: Icons.add_circle_outline, color: colors.success, container: colors.successContainer);
    case 'ADJUSTMENT_OUT':
      return (icon: Icons.remove_circle_outline, color: colors.warning, container: colors.warningContainer);
    default:
      // RETURN_SALE / RETURN_PURCHASE: cancellations.
      return (icon: Icons.undo_rounded, color: colors.neutral, container: colors.neutralContainer);
  }
}

class RecentActivityTile extends StatelessWidget {
  const RecentActivityTile({super.key, required this.movement, this.onTap, this.now});

  final StockMovement movement;
  final VoidCallback? onTap;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final style = movementStyle(colors, movement.type);
    final quantity = formatSignedQuantity(movement.signedQuantity);
    final time = formatActivityTime(movement.createdAt, now: now);
    final label = movementTypeLabel(movement.type);
    final product = movement.productName ?? 'Produit';

    return Semantics(
      label: '$label, $product, quantité $quantity, $time',
      excludeSemantics: true,
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: style.container, borderRadius: AppRadius.smAll),
                  child: Icon(style.icon, color: style.color, size: 20),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '$label · $time',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  quantity,
                  style: text.titleMedium?.copyWith(
                    color: style.color,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
