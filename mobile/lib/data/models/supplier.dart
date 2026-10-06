import 'package:stock_management/data/models/partner_stats.dart';

class SupplierProductLink {
  const SupplierProductLink({
    required this.productId,
    required this.productName,
    this.productSku,
  });

  final String productId;
  final String productName;
  final String? productSku;

  factory SupplierProductLink.fromJson(Map<String, dynamic> json) {
    final product = json['product'] as Map<String, dynamic>?;
    return SupplierProductLink(
      productId: json['productId'] as String? ?? product?['id'] as String? ?? '',
      productName: product?['name'] as String? ?? '',
      productSku: product?['sku'] as String?,
    );
  }
}

class Supplier {
  const Supplier({
    required this.id,
    required this.name,
    required this.type,
    this.phone,
    this.email,
    this.address,
    this.taxNumber,
    this.notes,
    required this.isActive,
    this.stats,
    this.products = const [],
  });

  final String id;
  final String name;
  final String type;
  final String? phone;
  final String? email;
  final String? address;
  final String? taxNumber;
  final String? notes;
  final bool isActive;
  final PartnerStats? stats;
  final List<SupplierProductLink> products;

  factory Supplier.fromJson(Map<String, dynamic> json) {
    return Supplier(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      address: json['address'] as String?,
      taxNumber: json['taxNumber'] as String?,
      notes: json['notes'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      stats: json['stats'] is Map<String, dynamic>
          ? PartnerStats.fromJson(
              json['stats'] as Map<String, dynamic>,
              countKey: 'purchaseCount',
              totalKey: 'totalPurchased',
              lastKey: 'lastPurchase',
            )
          : null,
      products: (json['products'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(SupplierProductLink.fromJson)
          .toList(),
    );
  }
}
