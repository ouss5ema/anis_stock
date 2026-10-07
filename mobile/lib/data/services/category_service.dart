import 'package:stock_management/core/network/api_client.dart';
import 'package:stock_management/core/network/api_endpoints.dart';
import 'package:stock_management/data/models/category.dart';
import 'package:stock_management/data/models/paginated_result.dart';

class CategoryService {
  CategoryService(this._apiClient);

  final ApiClient _apiClient;

  Future<PaginatedResult<Category>> list({
    String? search,
    int page = 1,
    bool includeInactive = false,
  }) {
    return _apiClient.get(
      ApiEndpoints.categories,
      query: {
        'page': page,
        'pageSize': 50,
        if (search != null && search.isNotEmpty) 'search': search,
        if (includeInactive) 'includeInactive': 'true',
      },
      parser: (data) => PaginatedResult.fromJson(
        data as Map<String, dynamic>,
        Category.fromJson,
      ),
    );
  }

  Future<Category> create(Map<String, dynamic> body) {
    return _apiClient.post(
      ApiEndpoints.categories,
      body: body,
      parser: (data) => Category.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<Category> update(String id, Map<String, dynamic> body) {
    return _apiClient.put(
      ApiEndpoints.category(id),
      body: body,
      parser: (data) => Category.fromJson(data as Map<String, dynamic>),
    );
  }

  /// ADMIN only. Refused with code `CATEGORY_NOT_EMPTY` while products
  /// (archived included) still use the category.
  Future<void> delete(String id, {String? reason}) {
    return _apiClient.delete(
      ApiEndpoints.category(id),
      body: {'reason': ?reason},
      parser: (_) {},
    );
  }

  /// ADMIN only. Moves every product to [targetCategoryId]; returns the count.
  Future<int> reassign(String id, String targetCategoryId, {String? reason}) {
    return _apiClient.post(
      ApiEndpoints.categoryReassign(id),
      body: {'targetCategoryId': targetCategoryId, 'reason': ?reason},
      parser: (data) => ((data as Map<String, dynamic>)['movedCount'] as num?)?.toInt() ?? 0,
    );
  }
}
