import 'package:flutter/material.dart';
import 'package:stock_management/core/theme/app_colors.dart';
import 'package:stock_management/core/theme/app_tokens.dart';

class QuickActions extends StatelessWidget {
  const QuickActions({super.key, required this.onNewSale, required this.onNewPurchase});

  final VoidCallback onNewSale;
  final VoidCallback onNewPurchase;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: onNewSale,
            icon: const Icon(Icons.point_of_sale_outlined),
            label: const Text('Nouvelle vente', maxLines: 1, overflow: TextOverflow.ellipsis),
            style: FilledButton.styleFrom(
              backgroundColor: colors.sale,
              foregroundColor: scheme.onPrimary,
              minimumSize: const Size.fromHeight(56),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: FilledButton.icon(
            onPressed: onNewPurchase,
            icon: const Icon(Icons.add_shopping_cart_outlined),
            label: const Text('Nouvel achat', maxLines: 1, overflow: TextOverflow.ellipsis),
            style: FilledButton.styleFrom(
              backgroundColor: colors.purchase,
              foregroundColor: scheme.onPrimary,
              minimumSize: const Size.fromHeight(56),
            ),
          ),
        ),
      ],
    );
  }
}
