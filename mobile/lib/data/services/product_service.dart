import 'package:stock_management/core/network/api_client.dart';
import 'package:stock_management/core/network/api_endpoints.dart';
import 'package:stock_management/data/models/paginated_result.dart';
import 'package:stock_management/data/models/product.dart';

class ProductService {
  ProductService(this._apiClient);

  final ApiClient _apiClient;

  Future<PaginatedResult<Product>> list({
    String? search,
    bool lowStock = false,
    bool outOfStock = false,
    String? categoryId,
    int page = 1,
    int pageSize = 100,
    bool includeInactive = false,
    bool archived = false,
  }) {
    return _apiClient.get(
      ApiEndpoints.products,
      query: {
        'page': page,
        'pageSize': pageSize > 100 ? 100 : pageSize,
        if (search != null && search.isNotEmpty) 'search': search,
        if (lowStock) 'lowStock': 'true',
        if (outOfStock) 'outOfStock': 'true',
        if (categoryId != null && categoryId.isNotEmpty) 'categoryId': categoryId,
        if (includeInactive) 'includeInactive': 'true',
        if (archived) 'archived': 'true',
      },
      parser: (data) => PaginatedResult.fromJson(
        data as Map<String, dynamic>,
        Product.fromJson,
      ),
    );
  }

  Future<Product> getById(String id) {
    return _apiClient.get(
      ApiEndpoints.product(id),
      parser: (data) => Product.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<Map<String, dynamic>> history(String id) {
    return _apiClient.get(
      ApiEndpoints.productHistory(id),
      parser: (data) => data as Map<String, dynamic>,
    );
  }

  Future<Product> create(Map<String, dynamic> body) {
    return _apiClient.post(
      ApiEndpoints.products,
      body: body,
      parser: (data) => Product.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<Product> update(String id, Map<String, dynamic> body) {
    return _apiClient.put(
      ApiEndpoints.product(id),
      body: body,
      parser: (data) => Product.fromJson(data as Map<String, dynamic>),
    );
  }

  /// ADMIN only. Deletes the product if it has no history and no stock,
  /// archives it otherwise. Returns true when it was really deleted.
  Future<bool> delete(String id, {String? reason}) {
    return _apiClient.delete(
      ApiEndpoints.product(id),
      body: {'reason': ?reason},
      parser: (data) => (data as Map<String, dynamic>)['deletionMode'] == 'DELETED',
    );
  }

  Future<ProductDeletePreview> deletePreview(String id) {
    return _apiClient.get(
      ApiEndpoints.productDeletePreview(id),
      parser: (data) => ProductDeletePreview.fromJson(data as Map<String, dynamic>),
    );
  }

  /// ADMIN only.
  Future<Product> restore(String id, {String? reason}) {
    return _apiClient.post(
      ApiEndpoints.productRestore(id),
      body: {'reason': ?reason},
      parser: (data) => Product.fromJson(data as Map<String, dynamic>),
    );
  }
}
