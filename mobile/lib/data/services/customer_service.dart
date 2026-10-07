import 'package:stock_management/core/network/api_client.dart';
import 'package:stock_management/core/network/api_endpoints.dart';
import 'package:stock_management/data/models/customer.dart';
import 'package:stock_management/data/models/paginated_result.dart';

class CustomerService {
  CustomerService(this._apiClient);

  final ApiClient _apiClient;

  Future<PaginatedResult<Customer>> list({
    String? search,
    String? type,
    int page = 1,
    bool includeInactive = false,
  }) {
    return _apiClient.get(
      ApiEndpoints.customers,
      query: {
        'page': page,
        'pageSize': 100,
        if (search != null && search.isNotEmpty) 'search': search,
        if (type != null && type.isNotEmpty) 'type': type,
        if (includeInactive) 'includeInactive': 'true',
      },
      parser: (data) => PaginatedResult.fromJson(
        data as Map<String, dynamic>,
        Customer.fromJson,
      ),
    );
  }

  Future<Customer> getById(String id) {
    return _apiClient.get(
      ApiEndpoints.customer(id),
      parser: (data) => Customer.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<Customer> create(Map<String, dynamic> body) {
    return _apiClient.post(
      ApiEndpoints.customers,
      body: body,
      parser: (data) => Customer.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<Customer> update(String id, Map<String, dynamic> body) {
    return _apiClient.put(
      ApiEndpoints.customer(id),
      body: body,
      parser: (data) => Customer.fromJson(data as Map<String, dynamic>),
    );
  }
}
