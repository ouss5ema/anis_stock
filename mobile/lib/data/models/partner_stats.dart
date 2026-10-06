class PartnerStats {
  const PartnerStats({
    this.count = 0,
    this.totalAmount,
    this.lastDate,
    this.lastReference,
  });

  final int count;
  final String? totalAmount;
  final DateTime? lastDate;
  final String? lastReference;

  factory PartnerStats.fromJson(
    Map<String, dynamic>? json, {
    required String countKey,
    required String totalKey,
    required String lastKey,
  }) {
    if (json == null) {
      return const PartnerStats();
    }
    final last = json[lastKey] as Map<String, dynamic>?;
    return PartnerStats(
      count: json[countKey] as int? ?? 0,
      totalAmount: json[totalKey]?.toString(),
      lastDate: last?['date'] != null ? DateTime.tryParse(last!['date'].toString()) : null,
      lastReference: last?['referenceNumber'] as String?,
    );
  }
}
