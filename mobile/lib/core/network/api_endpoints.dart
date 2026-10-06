class ApiEndpoints {
  static const health = '/health';
  static const login = '/auth/login';
  static const register = '/auth/register';
  static const me = '/auth/me';
  static const dashboard = '/dashboard';
  static const categories = '/categories';
  static const products = '/products';
  static const suppliers = '/suppliers';
  static const customers = '/customers';
  static const purchases = '/purchases';
  static const sales = '/sales';
  static const stockMovements = '/stock/movements';
  static const stockAdjustments = '/stock/adjustments';

  static String category(String id) => '$categories/$id';
  static String product(String id) => '$products/$id';
  static String productHistory(String id) => '$products/$id/history';
  static String supplier(String id) => '$suppliers/$id';
  static String customer(String id) => '$customers/$id';
  static String purchase(String id) => '$purchases/$id';
  static String purchaseItems(String id) => '$purchases/$id/items';
  static String sale(String id) => '$sales/$id';
  static String saleItems(String id) => '$sales/$id/items';
}
