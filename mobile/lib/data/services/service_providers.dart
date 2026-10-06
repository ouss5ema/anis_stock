import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_management/core/providers.dart';
import 'package:stock_management/data/services/auth_service.dart';
import 'package:stock_management/data/services/category_service.dart';
import 'package:stock_management/data/services/customer_service.dart';
import 'package:stock_management/data/services/operations_service.dart';
import 'package:stock_management/data/services/product_service.dart';
import 'package:stock_management/data/services/supplier_service.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    apiClient: ref.watch(apiClientProvider),
    tokenStorage: ref.watch(tokenStorageProvider),
  );
});

final productServiceProvider = Provider<ProductService>((ref) {
  return ProductService(ref.watch(apiClientProvider));
});

final categoryServiceProvider = Provider<CategoryService>((ref) {
  return CategoryService(ref.watch(apiClientProvider));
});

final supplierServiceProvider = Provider<SupplierService>((ref) {
  return SupplierService(ref.watch(apiClientProvider));
});

final customerServiceProvider = Provider<CustomerService>((ref) {
  return CustomerService(ref.watch(apiClientProvider));
});

final purchaseServiceProvider = Provider<PurchaseService>((ref) {
  return PurchaseService(ref.watch(apiClientProvider));
});

final saleServiceProvider = Provider<SaleService>((ref) {
  return SaleService(ref.watch(apiClientProvider));
});

final stockOpsServiceProvider = Provider<StockService>((ref) {
  return StockService(ref.watch(apiClientProvider));
});

final dashboardServiceProvider = Provider<DashboardService>((ref) {
  return DashboardService(ref.watch(apiClientProvider));
});
