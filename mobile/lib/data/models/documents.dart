import 'package:stock_management/data/models/product.dart';

DateTime? _parseDate(Object? value) => value is String ? DateTime.tryParse(value) : null;

/// One product affected by a cancellation, as returned by `cancel-preview`.
class StockImpactLine {
  const StockImpactLine({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.stockBefore,
    required this.stockAfter,
    this.unit,
    this.blocking = false,
  });

  final String productId;
  final String productName;
  final String quantity;
  final String stockBefore;
  final String stockAfter;
  final String? unit;

  /// Not enough stock to cancel (goods already sold).
  final bool blocking;

  factory StockImpactLine.fromJson(Map<String, dynamic> json) {
    return StockImpactLine(
      productId: json['productId'] as String? ?? '',
      productName: json['productName'] as String? ?? 'Produit',
      quantity: json['quantity']?.toString() ?? '0',
      stockBefore: json['stockBefore']?.toString() ?? '0',
      stockAfter: json['stockAfter']?.toString() ?? '0',
      unit: json['unit'] as String?,
      blocking: json['blocking'] as bool? ?? false,
    );
  }
}

/// Indicative preview of a sale or purchase cancellation. The backend
/// transaction remains authoritative.
class CancelPreview {
  const CancelPreview({
    required this.referenceNumber,
    required this.canCancel,
    required this.lines,
    this.blockingReason,
  });

  final String referenceNumber;
  final bool canCancel;
  final String? blockingReason;
  final List<StockImpactLine> lines;

  factory CancelPreview.fromJson(Map<String, dynamic> json) {
    return CancelPreview(
      referenceNumber: json['referenceNumber'] as String? ?? '',
      canCancel: json['canCancel'] as bool? ?? false,
      blockingReason: json['blockingReason'] as String?,
      lines: (json['lines'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(StockImpactLine.fromJson)
          .toList(),
    );
  }
}

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
    this.cancelledAt,
    this.cancelReason,
    this.cancelledByName,
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
  final DateTime? cancelledAt;
  final String? cancelReason;
  final String? cancelledByName;

  bool get isCancelled => status == 'CANCELLED';

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
      cancelledAt: _parseDate(json['cancelledAt']),
      cancelReason: json['cancelReason'] as String?,
      cancelledByName: (json['cancelledBy'] as Map<String, dynamic>?)?['name'] as String?,
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
    this.cancelledAt,
    this.cancelReason,
    this.cancelledByName,
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
  final DateTime? cancelledAt;
  final String? cancelReason;
  final String? cancelledByName;

  bool get isCancelled => status == 'CANCELLED';

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
      cancelledAt: _parseDate(json['cancelledAt']),
      cancelReason: json['cancelReason'] as String?,
      cancelledByName: (json['cancelledBy'] as Map<String, dynamic>?)?['name'] as String?,
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

class TopProduct {
  const TopProduct({
    required this.id,
    required this.name,
    required this.quantity,
    required this.amount,
  });

  final String id;
  final String name;
  final String quantity;
  final String amount;

  factory TopProduct.fromJson(Map<String, dynamic> json) {
    return TopProduct(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Produit',
      quantity: json['quantity']?.toString() ?? '0',
      amount: json['amount']?.toString() ?? '0',
    );
  }
}

/// Confirmed sales and purchases totals over a period.
class PeriodTotals {
  const PeriodTotals({
    required this.saleAmount,
    required this.saleCount,
    required this.purchaseAmount,
    required this.purchaseCount,
  });

  final String saleAmount;
  final int saleCount;
  final String purchaseAmount;
  final int purchaseCount;

  factory PeriodTotals.fromJson(Map<String, dynamic> json) {
    return PeriodTotals(
      saleAmount: json['saleAmount']?.toString() ?? '0',
      saleCount: (json['saleCount'] as num?)?.toInt() ?? 0,
      purchaseAmount: json['purchaseAmount']?.toString() ?? '0',
      purchaseCount: (json['purchaseCount'] as num?)?.toInt() ?? 0,
    );
  }
}

/// One bucket of the dashboard series: a day (`2026-10-07`) or an hour
/// (`2026-10-07T14:00`) in Africa/Tunis time.
class DashboardPoint {
  const DashboardPoint({
    required this.bucket,
    required this.saleAmount,
    required this.purchaseAmount,
    this.saleCount = 0,
    this.purchaseCount = 0,
  });

  final String bucket;
  final String saleAmount;
  final String purchaseAmount;
  final int saleCount;
  final int purchaseCount;

  /// Local wall-clock time of the bucket start (no time zone conversion).
  DateTime get start => DateTime.parse(bucket.length == 10 ? bucket : '$bucket:00');

  factory DashboardPoint.fromJson(Map<String, dynamic> json) {
    return DashboardPoint(
      bucket: json['date'] as String? ?? '',
      saleAmount: json['saleAmount']?.toString() ?? '0',
      purchaseAmount: json['purchaseAmount']?.toString() ?? '0',
      saleCount: (json['saleCount'] as num?)?.toInt() ?? 0,
      purchaseCount: (json['purchaseCount'] as num?)?.toInt() ?? 0,
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
    this.outOfStockProducts = const [],
    this.lowStockProducts = const [],
    this.topProducts = const [],
    this.previous,
    this.series = const [],
    this.seriesGranularity = 'day',
  });

  /// Totals of the selected period. The API sends them under `today`
  /// for every period; mapped here to [current].
  PeriodTotals get current => PeriodTotals(
        saleAmount: saleAmount,
        saleCount: saleCount,
        purchaseAmount: purchaseAmount,
        purchaseCount: purchaseCount,
      );

  /// Same totals for the previous period of equal length. Null when the
  /// backend does not provide it (older API).
  final PeriodTotals? previous;
  final List<DashboardPoint> series;

  /// `'day'` or `'hour'`.
  final String seriesGranularity;

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
  final List<Product> outOfStockProducts;
  final List<Product> lowStockProducts;
  final List<TopProduct> topProducts;

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
      outOfStockProducts: (json['outOfStockProducts'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(Product.fromJson)
          .toList(),
      lowStockProducts: (json['lowStockProducts'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(Product.fromJson)
          .toList(),
      topProducts: (json['topProducts'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(TopProduct.fromJson)
          .toList(),
      previous: json['previous'] is Map<String, dynamic>
          ? PeriodTotals.fromJson(json['previous'] as Map<String, dynamic>)
          : null,
      series: (json['series'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(DashboardPoint.fromJson)
          .toList(),
      seriesGranularity: json['seriesGranularity'] as String? ?? 'day',
    );
  }
}
