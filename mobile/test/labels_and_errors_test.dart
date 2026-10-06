import 'package:flutter_test/flutter_test.dart';
import 'package:stock_management/core/network/api_exception.dart';
import 'package:stock_management/core/utils/labels.dart';
import 'package:stock_management/core/utils/user_message.dart';

void main() {
  test('customer and movement labels stay user-facing', () {
    expect(customerTypeLabel('FREESHOP'), 'Free shop');
    expect(customerTypeLabel('SUPERMARKET'), 'Supermarché');
    expect(movementTypeLabel('ADJUSTMENT_OUT'), 'Ajustement sortie');
    expect(roleLabel('ADMIN'), 'Administrateur');
  });

  test('maps technical API errors to French messages', () {
    expect(
      userFacingMessage(const ApiException('Invalid email or password', statusCode: 401)),
      'Email ou mot de passe incorrect.',
    );
    expect(
      userFacingMessage(const ApiException('Invalid or expired token', statusCode: 401)),
      'Session expirée. Reconnectez-vous.',
    );
    expect(
      userFacingMessage(
        const ApiException(
          'Insufficient stock for Marlboro (SKU). Available: 12.000, requested: 100.000',
        ),
      ),
      'Stock disponible : 12.000 unités',
    );
    expect(
      userFacingMessage(Exception('SocketException: Failed host lookup')),
      'Connexion impossible. Vérifiez votre connexion Internet.',
    );
  });
}
