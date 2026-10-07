import 'package:stock_management/core/utils/money.dart';

String computeStockStatus({required String currentStock, required String minimumStock}) {
  final current = parseMoney(currentStock);
  final min = parseMoney(minimumStock);
  if (current <= parseMoney('0')) {
    return 'OUT';
  }
  if (current <= min) {
    return 'LOW';
  }
  return 'NORMAL';
}
