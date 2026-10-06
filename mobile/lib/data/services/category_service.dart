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
}
