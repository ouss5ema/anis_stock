import 'package:stock_management/core/utils/stock_status.dart';

class ProductSupplierLink {
  const ProductSupplierLink({
    required this.supplierId,
    required this.supplierName,
    this.isPreferred = false,
  });

  final String supplierId;
  final String supplierName;
  final bool isPreferred;

  factory ProductSupplierLink.fromJson(Map<String, dynamic> json) {
    final supplier = json['supplier'] as Map<String, dynamic>?;
    return ProductSupplierLink(
      supplierId: json['supplierId'] as String,
      supplierName: supplier?['name'] as String? ?? '',
      isPreferred: json['isPreferred'] as bool? ?? false,
    );
  }
}

/// What `DELETE /products/:id` will do: real deletion (no history, zero
/// stock) or archiving. Indicative: the backend decides under lock.
class ProductDeletePreview {
  const ProductDeletePreview({
    required this.willDelete,
    required this.currentStock,
    required this.hasStock,
    required this.isArchived,
    required this.movementCount,
  });

  final bool willDelete;
  final String currentStock;
  final bool hasStock;
  final bool isArchived;
  final int movementCount;

  factory ProductDeletePreview.fromJson(Map<String, dynamic> json) {
    final history = json['history'] as Map<String, dynamic>? ?? const {};
    return ProductDeletePreview(
      willDelete: json['mode'] == 'DELETE',
      currentStock: json['currentStock']?.toString() ?? '0',
      hasStock: json['hasStock'] as bool? ?? false,
      isArchived: json['isArchived'] as bool? ?? false,
      movementCount: (history['movements'] as num?)?.toInt() ?? 0,
    );
  }
}

class Product {
  const Product({
    required this.id,
    this.sku,
    required this.name,
    this.description,
    required this.categoryId,
    this.categoryName,
    required this.unit,
    required this.purchasePrice,
    required this.salePrice,
    required this.currentStock,
    required this.minimumStock,
    required this.isLowStock,
    required this.isOutOfStock,
    required this.stockStatus,
    required this.isActive,
    this.suppliers = const [],
    this.estimatedValue,
    this.archivedAt,
    this.archivedByName,
  });

  final String id;
  final String? sku;
  final String name;
  final String? description;
  final String categoryId;
  final String? categoryName;
  final String unit;
  final String purchasePrice;
  final String salePrice;
  final String currentStock;
  final String minimumStock;
  final bool isLowStock;
  final bool isOutOfStock;
  final String stockStatus;
  final bool isActive;
  final List<ProductSupplierLink> suppliers;
  final String? estimatedValue;
  final DateTime? archivedAt;
  final String? archivedByName;

  /// Inactive = archived (including legacy inactive products without date).
  bool get isArchived => !isActive;

  factory Product.fromJson(Map<String, dynamic> json) {
    final category = json['category'] as Map<String, dynamic>?;
    final currentStock = json['currentStock']?.toString() ?? '0';
    final minimumStock = json['minimumStock']?.toString() ?? '0';
    final status = json['stockStatus'] as String? ??
        computeStockStatus(currentStock: currentStock, minimumStock: minimumStock);
    return Product(
      id: json['id'] as String,
      sku: json['sku'] as String?,
      name: json['name'] as String,
      description: json['description'] as String?,
      categoryId: json['categoryId'] as String,
      categoryName: category?['name'] as String?,
      unit: json['unit'] as String,
      purchasePrice: json['purchasePrice']?.toString() ?? '0',
      salePrice: json['salePrice']?.toString() ?? '0',
      currentStock: currentStock,
      minimumStock: minimumStock,
      isLowStock: json['isLowStock'] as bool? ?? status == 'LOW',
      isOutOfStock: json['isOutOfStock'] as bool? ?? status == 'OUT',
      stockStatus: status,
      isActive: json['isActive'] as bool? ?? true,
      estimatedValue: json['estimatedValue']?.toString(),
      archivedAt: json['archivedAt'] is String ? DateTime.tryParse(json['archivedAt'] as String) : null,
      archivedByName: (json['archivedBy'] as Map<String, dynamic>?)?['name'] as String?,
      suppliers: (json['suppliers'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ProductSupplierLink.fromJson)
          .toList(),
    );
  }
}
