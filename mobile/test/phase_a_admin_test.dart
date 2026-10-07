import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_management/core/theme/app_theme.dart';
import 'package:stock_management/core/widgets/danger_action_dialog.dart';
import 'package:stock_management/core/widgets/document_admin.dart';
import 'package:stock_management/data/models/documents.dart';
import 'package:stock_management/data/models/product.dart';
import 'package:stock_management/features/auth/providers/auth_provider.dart';
import 'package:stock_management/features/sales/presentation/sale_detail_screen.dart';

Sale sale({String status = 'CONFIRMED'}) => Sale.fromJson({
      'id': 's1',
      'referenceNumber': 'VEN-20261007-0001',
      'saleDate': '2026-10-07T10:00:00.000Z',
      'totalAmount': '36.000',
      'status': status,
      'customer': {'id': 'c1', 'name': 'FreeShop'},
      'cancelledAt': status == 'CANCELLED' ? '2026-10-07T12:30:00.000Z' : null,
      'cancelReason': status == 'CANCELLED' ? 'Retour client' : null,
      'cancelledBy': status == 'CANCELLED' ? {'id': 'u1', 'name': 'Anis'} : null,
      'items': [
        {
          'productId': 'p1',
          'quantity': '3.000',
          'unitPrice': '12.000',
          'totalPrice': '36.000',
          'product': {'name': 'Marlboro Rouge'},
        },
      ],
    });

Future<void> pumpSaleDetail(WidgetTester tester, {required bool isAdmin, String status = 'CONFIRMED'}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        isAdminProvider.overrideWithValue(isAdmin),
        saleDetailProvider.overrideWith((ref, id) async => sale(status: status)),
      ],
      child: MaterialApp(theme: AppTheme.light(), home: const SaleDetailScreen(id: 's1')),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('cancel preview', () {
    test('parses lines and builds concrete stock consequences', () {
      final preview = CancelPreview.fromJson({
        'referenceNumber': 'VEN-1',
        'canCancel': true,
        'lines': [
          {
            'productId': 'p1',
            'productName': 'Marlboro Rouge',
            'unit': 'PACK',
            'quantity': '3.000',
            'stockBefore': '8.000',
            'stockAfter': '11.000',
          },
        ],
      });
      expect(preview.canCancel, isTrue);
      expect(stockConsequences(preview), ['Le stock de Marlboro Rouge passera de 8 à 11 paquet']);
    });

    test('keeps the blocking reason of a purchase that cannot be cancelled', () {
      final preview = CancelPreview.fromJson({
        'referenceNumber': 'ACH-1',
        'canCancel': false,
        'blockingReason': 'Impossible d’annuler l’achat ACH-1 : …',
        'lines': [
          {'productId': 'p1', 'productName': 'X', 'stockBefore': '3', 'stockAfter': '-7', 'blocking': true},
        ],
      });
      expect(preview.canCancel, isFalse);
      expect(preview.lines.single.blocking, isTrue);
      expect(preview.blockingReason, startsWith('Impossible'));
    });

    test('product delete preview distinguishes deletion and archiving', () {
      final archive = ProductDeletePreview.fromJson({
        'mode': 'ARCHIVE',
        'currentStock': '3.000',
        'hasStock': true,
        'history': {'movements': 2},
      });
      expect(archive.willDelete, isFalse);
      expect(archive.hasStock, isTrue);
      expect(ProductDeletePreview.fromJson({'mode': 'DELETE'}).willDelete, isTrue);
    });
  });

  group('reason validation (same rule as the backend)', () {
    test('required: 3 to 300 characters', () {
      expect(validateReason('', required: true), isNotNull);
      expect(validateReason('ab', required: true), isNotNull);
      expect(validateReason('Doublon', required: true), isNull);
      expect(validateReason('x' * 301, required: true), isNotNull);
    });

    test('optional: empty is accepted', () {
      expect(validateReason('', required: false), isNull);
      expect(validateReason('ab', required: false), isNotNull);
    });
  });

  testWidgets('danger dialog requires a reason, fills quick reasons and returns it', (tester) async {
    DangerActionResult? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showDangerActionDialog(
                context,
                title: 'Annuler la vente ?',
                confirmLabel: 'Annuler la vente',
                consequences: const ['Le stock de Marlboro Rouge passera de 8 à 11'],
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Le stock de Marlboro Rouge passera de 8 à 11'), findsOneWidget);

    // Empty reason is refused.
    await tester.tap(find.widgetWithText(FilledButton, 'Annuler la vente'));
    await tester.pumpAndSettle();
    expect(find.text('Le motif est obligatoire'), findsOneWidget);
    expect(result, isNull);

    await tester.tap(find.widgetWithText(ActionChip, 'Retour client'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Annuler la vente'));
    await tester.pumpAndSettle();
    expect(result?.reason, 'Retour client');
  });

  testWidgets('blocked action shows the reason and no confirm button', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDangerActionDialog(
              context,
              title: 'Annuler l’achat ?',
              confirmLabel: 'Annuler l’achat',
              blockingMessage: 'Marchandise déjà vendue',
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Marchandise déjà vendue'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Annuler l’achat'), findsNothing);
    expect(find.text('Fermer'), findsOneWidget);
  });

  testWidgets('"Annuler la vente" is shown to an ADMIN only', (tester) async {
    await pumpSaleDetail(tester, isAdmin: false);
    expect(find.text('VEN-20261007-0001'), findsOneWidget);
    expect(find.text('Annuler la vente'), findsNothing);

    await pumpSaleDetail(tester, isAdmin: true);
    expect(find.text('Annuler la vente'), findsOneWidget);
  });

  testWidgets('a cancelled sale shows its badge, reason and author, without action', (tester) async {
    await pumpSaleDetail(tester, isAdmin: true, status: 'CANCELLED');
    expect(find.text('Annulée'), findsOneWidget);
    expect(find.text('Vente annulée'), findsOneWidget);
    expect(find.text('Motif : Retour client'), findsOneWidget);
    expect(find.textContaining('par Anis'), findsOneWidget);
    expect(find.text('Annuler la vente'), findsNothing);
  });
}
