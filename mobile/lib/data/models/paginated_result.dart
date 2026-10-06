class PaginatedResult<T> {
  const PaginatedResult({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  final List<T> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;

  factory PaginatedResult.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic> json) itemParser,
  ) {
    final pagination = json['pagination'] as Map<String, dynamic>? ?? {};
    final items = (json['items'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(itemParser)
        .toList();

    return PaginatedResult<T>(
      items: items,
      total: pagination['total'] as int? ?? items.length,
      page: pagination['page'] as int? ?? 1,
      pageSize: pagination['pageSize'] as int? ?? items.length,
      totalPages: pagination['totalPages'] as int? ?? 1,
    );
  }
}
