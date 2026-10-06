import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:stock_management/core/config/env.dart';
import 'package:stock_management/core/network/api_exception.dart';
import 'package:stock_management/core/storage/token_storage.dart';

class ApiClient {
  // ignore: prefer_initializing_formals
  ApiClient({required TokenStorage tokenStorage}) : _tokenStorage = tokenStorage {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppEnv.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 15),
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _tokenStorage.readToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final path = error.requestOptions.path;
          final isAuthEndpoint = path.contains('/auth/login') || path.contains('/auth/register');
          if (error.response?.statusCode == 401 && !isAuthEndpoint) {
            await _tokenStorage.clearToken();
            onUnauthorized?.call();
          }
          handler.next(error);
        },
      ),
    );
  }

  VoidCallback? onUnauthorized;
  final TokenStorage _tokenStorage;
  late final Dio _dio;

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    required T Function(dynamic data) parser,
  }) {
    return _request(() => _dio.get(path, queryParameters: query), parser);
  }

  Future<T> post<T>(
    String path, {
    Map<String, dynamic>? body,
    required T Function(dynamic data) parser,
  }) {
    return _request(() => _dio.post(path, data: body), parser);
  }

  Future<T> put<T>(
    String path, {
    Map<String, dynamic>? body,
    required T Function(dynamic data) parser,
  }) {
    return _request(() => _dio.put(path, data: body), parser);
  }

  Future<T> delete<T>(
    String path, {
    Map<String, dynamic>? body,
    required T Function(dynamic data) parser,
  }) {
    return _request(() => _dio.delete(path, data: body), parser);
  }

  Future<T> _request<T>(
    Future<Response<dynamic>> Function() send,
    T Function(dynamic data) parser,
  ) async {
    try {
      final response = await send();
      final payload = response.data;

      if (payload is! Map<String, dynamic>) {
        return parser(payload);
      }

      if (payload['success'] == false) {
        throw ApiException(
          payload['message']?.toString() ?? 'Request failed',
          statusCode: response.statusCode,
          fieldErrors: _extractErrors(payload['errors']),
        );
      }

      return parser(payload['data']);
    } on ApiException {
      rethrow;
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  ApiException _mapDioException(DioException error) {
    final statusCode = error.response?.statusCode;
    final payload = error.response?.data;

    if (payload is Map<String, dynamic>) {
      return ApiException(
        payload['message']?.toString() ?? 'Request failed',
        statusCode: statusCode,
        fieldErrors: _extractErrors(payload['errors']),
      );
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException('La connexion au serveur a expiré');
      case DioExceptionType.connectionError:
        return const ApiException(
          'Connexion impossible. Vérifiez votre connexion Internet.',
        );
      default:
        return ApiException(
          'Connexion impossible. Vérifiez votre connexion Internet.',
          statusCode: statusCode,
        );
    }
  }

  List<String> _extractErrors(dynamic errors) {
    if (errors is! List) {
      return const [];
    }

    return errors.map((item) {
      if (item is Map && item['message'] != null) {
        return item['message'].toString();
      }
      return item.toString();
    }).toList();
  }
}
