import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_management/features/home/presentation/home_screen.dart';
import 'package:stock_management/features/products/presentation/products_screen.dart';
import 'package:stock_management/features/purchases/presentation/purchases_screen.dart';
import 'package:stock_management/features/sales/presentation/sales_screen.dart';
import 'package:stock_management/features/stock/presentation/movements_screen.dart';
import 'package:stock_management/features/stock/presentation/stock_screen.dart';

void invalidateOperationalData(WidgetRef ref) {
  ref.invalidate(dashboardProvider);
  ref.invalidate(stockListProvider);
  ref.invalidate(productsListProvider);
  ref.invalidate(movementsProvider);
  ref.invalidate(purchasesProvider);
  ref.invalidate(salesProvider);
}
