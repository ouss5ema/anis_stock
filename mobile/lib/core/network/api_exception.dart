class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.statusCode,
    this.fieldErrors = const [],
    this.code,
    this.details = const [],
  });

  final String message;
  final int? statusCode;
  final List<String> fieldErrors;

  /// Stable backend error code (`INSUFFICIENT_STOCK`, `ALREADY_CANCELLED`,
  /// `CATEGORY_NOT_EMPTY`, `FORBIDDEN`...), when the API sends one.
  final String? code;

  /// Raw `errors` objects (e.g. `{ productCount: 3 }`).
  final List<Map<String, dynamic>> details;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}
