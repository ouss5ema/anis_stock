import 'package:flutter/material.dart';
import 'package:stock_management/core/utils/labels.dart';
import 'package:stock_management/core/utils/money.dart';
import 'package:stock_management/core/widgets/ui_kit.dart';
import 'package:stock_management/data/models/product.dart';

class DraftLine {
  DraftLine({
    required this.product,
    this.quantity = '1',
    required this.unitPrice,
  });

  final Product product;
  String quantity;
  String unitPrice;

  String get total => multiplyMoney(quantity, unitPrice);
}

class DocumentLineCard extends StatelessWidget {
  const DocumentLineCard({
    super.key,
    required this.line,
    required this.onQuantityChanged,
    required this.onPriceChanged,
    required this.onRemove,
    this.showStock = false,
    this.stockError = false,
    this.stockErrorText,
  });

  final DraftLine line;
  final ValueChanged<String> onQuantityChanged;
  final ValueChanged<String> onPriceChanged;
  final VoidCallback onRemove;
  final bool showStock;
  final bool stockError;
  final String? stockErrorText;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(line.product.name, style: Theme.of(context).textTheme.titleMedium),
              ),
              IconButton(onPressed: onRemove, icon: const Icon(Icons.close)),
            ],
          ),
          Text('${line.product.sku} · ${unitLabel(line.product.unit)}'),
          if (showStock)
            Text(
              stockError
                  ? (stockErrorText ?? 'Stock disponible : ${formatDt(line.product.currentStock)} ${unitLabel(line.product.unit)}')
                  : 'Stock dispo : ${formatDt(line.product.currentStock)} ${unitLabel(line.product.unit)}',
              style: TextStyle(color: stockError ? colors.error : null, fontWeight: FontWeight.w600),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: line.quantity,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Qté'),
                  onChanged: onQuantityChanged,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  initialValue: line.unitPrice,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Prix'),
                  onChanged: onPriceChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              formatDtLabel(line.total),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }
}
