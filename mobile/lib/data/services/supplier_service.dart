import 'package:stock_management/core/network/api_client.dart';
import 'package:stock_management/core/network/api_endpoints.dart';
import 'package:stock_management/data/models/paginated_result.dart';
import 'package:stock_management/data/models/supplier.dart';

class SupplierService {
  SupplierService(this._apiClient);

  final ApiClient _apiClient;

  Future<PaginatedResult<Supplier>> list({
    String? search,
    int page = 1,
    bool includeInactive = false,
  }) {
    return _apiClient.get(
      ApiEndpoints.suppliers,
      query: {
        'page': page,
        'pageSize': 50,
        if (search != null && search.isNotEmpty) 'search': search,
        if (includeInactive) 'includeInactive': 'true',
      },
      parser: (data) => PaginatedResult.fromJson(
        data as Map<String, dynamic>,
        Supplier.fromJson,
      ),
    );
  }

  Future<Supplier> getById(String id) {
    return _apiClient.get(
      ApiEndpoints.supplier(id),
      parser: (data) => Supplier.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<Supplier> create(Map<String, dynamic> body) {
    return _apiClient.post(
      ApiEndpoints.suppliers,
      body: body,
      parser: (data) => Supplier.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<Supplier> update(String id, Map<String, dynamic> body) {
    return _apiClient.put(
      ApiEndpoints.supplier(id),
      body: body,
      parser: (data) => Supplier.fromJson(data as Map<String, dynamic>),
    );
  }
}
