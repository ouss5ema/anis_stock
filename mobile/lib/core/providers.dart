import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_management/core/network/api_client.dart';
import 'package:stock_management/core/storage/token_storage.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(tokenStorage: ref.watch(tokenStorageProvider));
});
