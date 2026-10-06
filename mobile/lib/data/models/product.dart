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

class Product {
  const Product({
    required this.id,
    required this.sku,
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
  });

  final String id;
  final String sku;
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

  factory Product.fromJson(Map<String, dynamic> json) {
    final category = json['category'] as Map<String, dynamic>?;
    return Product(
      id: json['id'] as String,
      sku: json['sku'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      categoryId: json['categoryId'] as String,
      categoryName: category?['name'] as String?,
      unit: json['unit'] as String,
      purchasePrice: json['purchasePrice']?.toString() ?? '0',
      salePrice: json['salePrice']?.toString() ?? '0',
      currentStock: json['currentStock']?.toString() ?? '0',
      minimumStock: json['minimumStock']?.toString() ?? '0',
      isLowStock: json['isLowStock'] as bool? ?? false,
      isOutOfStock: json['isOutOfStock'] as bool? ?? false,
      stockStatus: json['stockStatus'] as String? ?? 'NORMAL',
      isActive: json['isActive'] as bool? ?? true,
      estimatedValue: json['estimatedValue']?.toString(),
      suppliers: (json['suppliers'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ProductSupplierLink.fromJson)
          .toList(),
    );
  }
}
