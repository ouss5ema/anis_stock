import 'package:flutter_test/flutter_test.dart';
import 'package:stock_management/core/utils/money.dart';

void main() {
  test('formats and multiplies money without using double', () {
    expect(formatDt('9.5'), '9.500');
    expect(multiplyMoney('50', '9.500'), '475.000');
    expect(addMoney(['250.000', '475.000']), '725.000');
    expect(greaterThanMoney('21', '20'), isTrue);
    expect(isPositiveMoney('0'), isFalse);
  });
}
