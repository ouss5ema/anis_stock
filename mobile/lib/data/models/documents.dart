class NamedRef {
  const NamedRef({required this.id, required this.name, this.type});

  final String id;
  final String name;
  final String? type;

  factory NamedRef.fromJson(Map<String, dynamic>? json) {
    return NamedRef(
      id: json?['id'] as String? ?? '',
      name: json?['name'] as String? ?? '',
      type: json?['type'] as String?,
    );
  }
}

class DocumentLine {
  const DocumentLine({
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.productName,
    this.productSku,
    this.productStock,
  });

  final String productId;
  final String quantity;
  final String unitPrice;
  final String totalPrice;
  final String? productName;
  final String? productSku;
  final String? productStock;

  factory DocumentLine.fromJson(Map<String, dynamic> json) {
    final product = json['product'] as Map<String, dynamic>?;
    return DocumentLine(
      productId: json['productId'] as String,
      quantity: json['quantity']?.toString() ?? '0',
      unitPrice: json['unitPrice']?.toString() ?? '0',
      totalPrice: json['totalPrice']?.toString() ?? '0',
      productName: product?['name'] as String?,
      productSku: product?['sku'] as String?,
      productStock: product?['currentStock']?.toString(),
    );
  }
}

class Purchase {
  const Purchase({
    required this.id,
    required this.referenceNumber,
    required this.purchaseDate,
    required this.totalAmount,
    required this.status,
    required this.supplier,
    this.notes,
    this.itemCount,
    this.items = const [],
  });

  final String id;
  final String referenceNumber;
  final DateTime purchaseDate;
  final String totalAmount;
  final String status;
  final NamedRef supplier;
  final String? notes;
  final int? itemCount;
  final List<DocumentLine> items;

  factory Purchase.fromJson(Map<String, dynamic> json) {
    return Purchase(
      id: json['id'] as String,
      referenceNumber: json['referenceNumber'] as String,
      purchaseDate: DateTime.parse(json['purchaseDate'] as String),
      totalAmount: json['totalAmount']?.toString() ?? '0',
      status: json['status'] as String? ?? 'CONFIRMED',
      supplier: NamedRef.fromJson(json['supplier'] as Map<String, dynamic>?),
      notes: json['notes'] as String?,
      itemCount: json['itemCount'] as int?,
      items: (json['items'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(DocumentLine.fromJson)
          .toList(),
    );
  }
}

class Sale {
  const Sale({
    required this.id,
    required this.referenceNumber,
    required this.saleDate,
    required this.totalAmount,
    required this.status,
    required this.customer,
    this.notes,
    this.itemCount,
    this.items = const [],
  });

  final String id;
  final String referenceNumber;
  final DateTime saleDate;
  final String totalAmount;
  final String status;
  final NamedRef customer;
  final String? notes;
  final int? itemCount;
  final List<DocumentLine> items;

  factory Sale.fromJson(Map<String, dynamic> json) {
    return Sale(
      id: json['id'] as String,
      referenceNumber: json['referenceNumber'] as String,
      saleDate: DateTime.parse(json['saleDate'] as String),
      totalAmount: json['totalAmount']?.toString() ?? '0',
      status: json['status'] as String? ?? 'CONFIRMED',
      customer: NamedRef.fromJson(json['customer'] as Map<String, dynamic>?),
      notes: json['notes'] as String?,
      itemCount: json['itemCount'] as int?,
      items: (json['items'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(DocumentLine.fromJson)
          .toList(),
    );
  }
}

class StockMovement {
  const StockMovement({
    required this.id,
    required this.type,
    required this.quantity,
    required this.signedQuantity,
    required this.previousStock,
    required this.newStock,
    required this.createdAt,
    this.productName,
    this.productSku,
    this.referenceType,
    this.referenceId,
    this.reason,
  });

  final String id;
  final String type;
  final String quantity;
  final String signedQuantity;
  final String previousStock;
  final String newStock;
  final DateTime createdAt;
  final String? productName;
  final String? productSku;
  final String? referenceType;
  final String? referenceId;
  final String? reason;

  factory StockMovement.fromJson(Map<String, dynamic> json) {
    final product = json['product'] as Map<String, dynamic>?;
    return StockMovement(
      id: json['id'] as String,
      type: json['type'] as String,
      quantity: json['quantity']?.toString() ?? '0',
      signedQuantity: json['signedQuantity']?.toString() ?? json['quantity']?.toString() ?? '0',
      previousStock: json['previousStock']?.toString() ?? '0',
      newStock: json['newStock']?.toString() ?? '0',
      createdAt: DateTime.parse(json['createdAt'] as String),
      productName: product?['name'] as String?,
      productSku: product?['sku'] as String?,
      referenceType: json['referenceType'] as String?,
      referenceId: json['referenceId'] as String?,
      reason: json['reason'] as String?,
    );
  }
}

class DashboardSnapshot {
  const DashboardSnapshot({
    required this.purchaseCount,
    required this.saleCount,
    required this.purchaseAmount,
    required this.saleAmount,
    required this.productCount,
    required this.lowStockCount,
    required this.outOfStockCount,
    required this.stockValue,
    required this.recentPurchases,
    required this.recentSales,
    required this.recentMovements,
  });

  final int purchaseCount;
  final int saleCount;
  final String purchaseAmount;
  final String saleAmount;
  final int productCount;
  final int lowStockCount;
  final int outOfStockCount;
  final String stockValue;
  final List<Purchase> recentPurchases;
  final List<Sale> recentSales;
  final List<StockMovement> recentMovements;

  factory DashboardSnapshot.fromJson(Map<String, dynamic> json) {
    final today = json['today'] as Map<String, dynamic>? ?? {};
    final stock = json['stock'] as Map<String, dynamic>? ?? {};
    return DashboardSnapshot(
      purchaseCount: today['purchaseCount'] as int? ?? 0,
      saleCount: today['saleCount'] as int? ?? 0,
      purchaseAmount: today['purchaseAmount']?.toString() ?? '0',
      saleAmount: today['saleAmount']?.toString() ?? '0',
      productCount: stock['productCount'] as int? ?? 0,
      lowStockCount: stock['lowStockCount'] as int? ?? 0,
      outOfStockCount: stock['outOfStockCount'] as int? ?? 0,
      stockValue: stock['approximateValue']?.toString() ?? '0',
      recentPurchases: (json['recentPurchases'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(Purchase.fromJson)
          .toList(),
      recentSales: (json['recentSales'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(Sale.fromJson)
          .toList(),
      recentMovements: (json['recentMovements'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(StockMovement.fromJson)
          .toList(),
    );
  }
}
