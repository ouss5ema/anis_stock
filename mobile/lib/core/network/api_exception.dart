class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.fieldErrors = const []});

  final String message;
  final int? statusCode;
  final List<String> fieldErrors;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}
