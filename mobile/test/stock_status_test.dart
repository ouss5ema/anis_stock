import 'package:flutter_test/flutter_test.dart';
import 'package:stock_management/core/utils/money.dart';
import 'package:stock_management/core/utils/stock_status.dart';
import 'package:stock_management/data/models/product.dart';

void main() {
  test('stock status follows current stock and minimum threshold', () {
    expect(computeStockStatus(currentStock: '0', minimumStock: '5'), 'OUT');
    expect(computeStockStatus(currentStock: '1', minimumStock: '5'), 'LOW');
    expect(computeStockStatus(currentStock: '5', minimumStock: '5'), 'LOW');
    expect(computeStockStatus(currentStock: '6', minimumStock: '5'), 'NORMAL');
    expect(computeStockStatus(currentStock: '1', minimumStock: '0'), 'NORMAL');
  });

  test('product json keeps a missing SKU as null', () {
    final product = Product.fromJson({
      'id': 'p1',
      'sku': null,
      'name': 'Article',
      'categoryId': 'c1',
      'unit': 'PACK',
      'purchasePrice': '1',
      'salePrice': '2',
      'currentStock': '0',
      'minimumStock': '5',
      'isActive': true,
    });
    expect(product.sku, isNull);
    expect(product.stockStatus, 'OUT');
  });

  test('money labels stay readable with thousands grouping', () {
    expect(formatDt('1250'), '1 250.000');
    expect(formatDtLabel('12'), '12.000 DT');
  });
}
