import 'package:stock_management/core/network/api_client.dart';
import 'package:stock_management/core/network/api_endpoints.dart';
import 'package:stock_management/data/models/documents.dart';
import 'package:stock_management/data/models/paginated_result.dart';

class PurchaseService {
  PurchaseService(this._apiClient);

  final ApiClient _apiClient;

  Future<PaginatedResult<Purchase>> list({
    String? search,
    String? supplierId,
    String? status,
    String? from,
    String? to,
    int page = 1,
  }) {
    return _apiClient.get(
      ApiEndpoints.purchases,
      query: {
        'page': page,
        'pageSize': 100,
        if (search != null && search.isNotEmpty) 'search': search,
        if (supplierId != null && supplierId.isNotEmpty) 'supplierId': supplierId,
        if (status != null && status.isNotEmpty) 'status': status,
        'from': ?from,
        'to': ?to,
      },
      parser: (data) => PaginatedResult.fromJson(
        data as Map<String, dynamic>,
        Purchase.fromJson,
      ),
    );
  }

  Future<Purchase> getById(String id) {
    return _apiClient.get(
      ApiEndpoints.purchase(id),
      parser: (data) => Purchase.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<Purchase> create(Map<String, dynamic> body) {
    return _apiClient.post(
      ApiEndpoints.purchases,
      body: body,
      parser: (data) => Purchase.fromJson(data as Map<String, dynamic>),
    );
  }

  /// ADMIN only. The reason (3 to 300 characters) is mandatory.
  Future<Purchase> cancel(String id, {required String reason}) {
    return _apiClient.delete(
      ApiEndpoints.purchase(id),
      body: {'reason': reason},
      parser: (data) => Purchase.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<CancelPreview> cancelPreview(String id) {
    return _apiClient.get(
      ApiEndpoints.purchaseCancelPreview(id),
      parser: (data) => CancelPreview.fromJson(data as Map<String, dynamic>),
    );
  }
}

class SaleService {
  SaleService(this._apiClient);

  final ApiClient _apiClient;

  Future<PaginatedResult<Sale>> list({
    String? search,
    String? customerId,
    String? status,
    String? from,
    String? to,
    int page = 1,
  }) {
    return _apiClient.get(
      ApiEndpoints.sales,
      query: {
        'page': page,
        'pageSize': 100,
        if (search != null && search.isNotEmpty) 'search': search,
        if (customerId != null && customerId.isNotEmpty) 'customerId': customerId,
        if (status != null && status.isNotEmpty) 'status': status,
        'from': ?from,
        'to': ?to,
      },
      parser: (data) => PaginatedResult.fromJson(
        data as Map<String, dynamic>,
        Sale.fromJson,
      ),
    );
  }

  Future<Sale> getById(String id) {
    return _apiClient.get(
      ApiEndpoints.sale(id),
      parser: (data) => Sale.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<Sale> create(Map<String, dynamic> body) {
    return _apiClient.post(
      ApiEndpoints.sales,
      body: body,
      parser: (data) => Sale.fromJson(data as Map<String, dynamic>),
    );
  }

  /// ADMIN only. The reason (3 to 300 characters) is mandatory.
  Future<Sale> cancel(String id, {required String reason}) {
    return _apiClient.delete(
      ApiEndpoints.sale(id),
      body: {'reason': reason},
      parser: (data) => Sale.fromJson(data as Map<String, dynamic>),
    );
  }

  Future<CancelPreview> cancelPreview(String id) {
    return _apiClient.get(
      ApiEndpoints.saleCancelPreview(id),
      parser: (data) => CancelPreview.fromJson(data as Map<String, dynamic>),
    );
  }
}

class StockService {
  StockService(this._apiClient);

  final ApiClient _apiClient;

  Future<PaginatedResult<StockMovement>> movements({
    String? productId,
    String? type,
    String? from,
    String? to,
    int page = 1,
  }) {
    return _apiClient.get(
      ApiEndpoints.stockMovements,
      query: {
        'page': page,
        'pageSize': 100,
        'productId': ?productId,
        'type': ?type,
        'from': ?from,
        'to': ?to,
      },
      parser: (data) => PaginatedResult.fromJson(
        data as Map<String, dynamic>,
        StockMovement.fromJson,
      ),
    );
  }

  Future<StockMovement> adjust({
    required String productId,
    required String direction,
    required String quantity,
    required String reason,
  }) {
    return _apiClient.post(
      ApiEndpoints.stockAdjustments,
      body: {
        'productId': productId,
        'direction': direction,
        'quantity': quantity,
        'reason': reason,
      },
      parser: (data) => StockMovement.fromJson(data as Map<String, dynamic>),
    );
  }
}

class DashboardService {
  DashboardService(this._apiClient);

  final ApiClient _apiClient;

  Future<DashboardSnapshot> load({String period = 'today'}) {
    return _apiClient.get(
      ApiEndpoints.dashboard,
      query: {'period': period},
      parser: (data) => DashboardSnapshot.fromJson(data as Map<String, dynamic>),
    );
  }
}
