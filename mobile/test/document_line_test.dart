import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_management/core/utils/money.dart';
import 'package:stock_management/core/widgets/document_line_card.dart';
import 'package:stock_management/core/widgets/ui_kit.dart';
import 'package:stock_management/data/models/product.dart';

Product _product({String stock = '12.000'}) {
  return Product(
    id: 'p1',
    sku: 'SKU-1',
    name: 'Marlboro',
    categoryId: 'c1',
    unit: 'PACK',
    purchasePrice: '25.000',
    salePrice: '30.000',
    currentStock: stock,
    minimumStock: '5.000',
    isLowStock: false,
    isOutOfStock: false,
    stockStatus: 'NORMAL',
    isActive: true,
  );
}

void main() {
  testWidgets('sale line shows available stock and overflow message', (tester) async {
    final line = DraftLine(product: _product(), unitPrice: '30.000')..quantity = '20';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DocumentLineCard(
            line: line,
            showStock: true,
            stockError: greaterThanMoney(line.quantity, line.product.currentStock),
            stockErrorText: 'Stock disponible : 12.000 paquets',
            onQuantityChanged: (_) {},
            onPriceChanged: (_) {},
            onRemove: () {},
          ),
        ),
      ),
    );

    expect(find.text('Stock disponible : 12.000 paquets'), findsOneWidget);
    expect(find.text('Marlboro'), findsOneWidget);
  });

  testWidgets('empty and error states are readable', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmptyState(icon: Icons.inbox, title: 'Aucun achat enregistré.'),
        ),
      ),
    );
    expect(find.text('Aucun achat enregistré.'), findsOneWidget);
  });
}
