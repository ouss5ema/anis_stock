import 'package:stock_management/data/models/partner_stats.dart';

class Customer {
  const Customer({
    required this.id,
    required this.name,
    required this.type,
    this.phone,
    this.email,
    this.address,
    this.notes,
    required this.isActive,
    this.stats,
  });

  final String id;
  final String name;
  final String type;
  final String? phone;
  final String? email;
  final String? address;
  final String? notes;
  final bool isActive;
  final PartnerStats? stats;

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      address: json['address'] as String?,
      notes: json['notes'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      stats: json['stats'] is Map<String, dynamic>
          ? PartnerStats.fromJson(
              json['stats'] as Map<String, dynamic>,
              countKey: 'saleCount',
              totalKey: 'totalSold',
              lastKey: 'lastSale',
            )
          : null,
    );
  }
}
