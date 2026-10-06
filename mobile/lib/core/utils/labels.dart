String customerTypeLabel(String type) {
  switch (type) {
    case 'FREESHOP':
      return 'Free shop';
    case 'SUPERMARKET':
      return 'Supermarché';
    case 'SHOP':
      return 'Magasin';
    default:
      return 'Autre';
  }
}

String supplierTypeLabel(String type) {
  switch (type) {
    case 'TABAC':
      return 'Tabac';
    case 'TELECOM':
      return 'Télécom';
    default:
      return 'Autre';
  }
}

String unitLabel(String unit) {
  switch (unit) {
    case 'UNIT':
      return 'unité';
    case 'PACK':
      return 'paquet';
    case 'CARTON':
      return 'carton';
    case 'BOX':
      return 'boîte';
    case 'RECHARGE':
      return 'recharge';
    default:
      return 'unité';
  }
}

String movementTypeLabel(String type) {
  switch (type) {
    case 'PURCHASE':
      return 'Achat';
    case 'SALE':
      return 'Vente';
    case 'ADJUSTMENT_IN':
      return 'Ajustement entrée';
    case 'ADJUSTMENT_OUT':
      return 'Ajustement sortie';
    case 'RETURN_PURCHASE':
      return 'Annulation achat';
    case 'RETURN_SALE':
      return 'Annulation vente';
    default:
      return type;
  }
}

String roleLabel(String? role) {
  if (role == 'ADMIN') {
    return 'Administrateur';
  }
  return 'Utilisateur';
}

String documentStatusLabel(String status) {
  return status == 'CANCELLED' ? 'Annulé' : 'Confirmé';
}
