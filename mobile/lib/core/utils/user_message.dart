import 'package:stock_management/core/network/api_exception.dart';

String userFacingMessage(
  Object error, {
  String fallback = 'Impossible de charger les données. Vérifiez votre connexion.',
}) {
  if (error is ApiException) {
    return mapApiMessage(error);
  }
  return mapRawMessage(error.toString(), fallback: fallback);
}

String mapApiMessage(ApiException error) {
  final lower = error.message.toLowerCase();
  if (error.statusCode == 401) {
    if (lower.contains('invalid email or password')) {
      return 'Email ou mot de passe incorrect.';
    }
    return 'Votre session a expiré. Veuillez vous reconnecter.';
  }
  if (error.statusCode == 403) {
    return 'Vous n’avez pas l’autorisation d’effectuer cette action.';
  }
  if (error.statusCode == 404) {
    return 'Élément introuvable.';
  }
  if (error.statusCode == 409) {
    return mapRawMessage(error.message, fallback: 'Cette opération entre en conflit avec des données existantes.');
  }
  if (error.statusCode == 422) {
    return error.fieldErrors.isNotEmpty
        ? error.fieldErrors.first
        : 'Les informations saisies sont invalides.';
  }
  return mapRawMessage(error.message, fallback: fallbackForStatus(error.statusCode));
}

String fallbackForStatus(int? statusCode) {
  if (statusCode == 500) {
    return 'Le serveur a rencontré un problème. Réessayez plus tard.';
  }
  return 'Impossible de charger les données. Vérifiez votre connexion.';
}

String mapRawMessage(String message, {required String fallback}) {
  final lower = message.toLowerCase();

  if (lower.contains('socket') ||
      lower.contains('failed host lookup') ||
      lower.contains('connection refused') ||
      lower.contains('network is unreachable') ||
      lower.contains('xmlhttprequest') ||
      lower.contains('clientexception')) {
    return 'Connexion impossible. Vérifiez votre connexion Internet.';
  }

  if (lower.contains('invalid email or password')) {
    return 'Email ou mot de passe incorrect.';
  }
  if (lower.contains('insufficient stock')) {
    final available = RegExp(r'Available:\s*([0-9.]+)').firstMatch(message)?.group(1);
    if (available != null) {
      return 'Stock disponible : $available unités';
    }
    return 'Stock insuffisant pour cet article.';
  }
  if (lower.contains('inactive')) {
    return 'Ce compte ou cet élément n’est plus actif.';
  }
  if (lower.contains('already exists')) {
    return 'Un enregistrement identique existe déjà.';
  }
  if (lower.contains('too many attempts')) {
    return 'Trop de tentatives. Réessayez dans quelques minutes.';
  }
  if (lower.contains('internal server error') || lower.contains('http 500')) {
    return 'Le serveur a rencontré un problème. Réessayez plus tard.';
  }
  if (message.contains('Exception') ||
      message.contains('Error:') ||
      message.contains('Prisma') ||
      message.contains('ECONN') ||
      message.contains('Stack')) {
    return fallback;
  }

  return message;
}
