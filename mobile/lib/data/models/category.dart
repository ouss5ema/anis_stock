class Category {
  const Category({
    required this.id,
    required this.name,
    this.description,
    required this.isActive,
    this.productCount,
  });

  final String id;
  final String name;
  final String? description;
  final bool isActive;
  final int? productCount;

  factory Category.fromJson(Map<String, dynamic> json) {
    final count = json['_count'];
    return Category(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      productCount: count is Map<String, dynamic> ? count['products'] as int? : null,
    );
  }
}
