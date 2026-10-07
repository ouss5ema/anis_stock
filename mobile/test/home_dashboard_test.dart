import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_management/core/network/api_exception.dart';
import 'package:stock_management/core/theme/app_theme.dart';
import 'package:stock_management/core/utils/formatters.dart';
import 'package:stock_management/data/models/documents.dart';
import 'package:stock_management/features/home/presentation/widgets/dashboard_skeleton.dart';
import 'package:stock_management/features/home/presentation/widgets/dashboard_view.dart';
import 'package:stock_management/features/home/presentation/widgets/kpi_card.dart';

final now = DateTime(2026, 10, 7, 14, 30);

DashboardSnapshot snapshot({
  String saleAmount = '0',
  int saleCount = 0,
  String purchaseAmount = '0',
  int purchaseCount = 0,
  PeriodTotals? previous,
  List<DashboardPoint> series = const [],
  List<StockMovement> movements = const [],
  List<TopProduct> topProducts = const [],
  int outOfStock = 0,
  int lowStock = 0,
}) {
  return DashboardSnapshot(
    purchaseCount: purchaseCount,
    saleCount: saleCount,
    purchaseAmount: purchaseAmount,
    saleAmount: saleAmount,
    productCount: 4,
    lowStockCount: lowStock,
    outOfStockCount: outOfStock,
    stockValue: '1250',
    recentPurchases: const [],
    recentSales: const [],
    recentMovements: movements,
    topProducts: topProducts,
    previous: previous,
    series: series,
    seriesGranularity: 'hour',
  );
}

const zeroPrevious = PeriodTotals(saleAmount: '0', saleCount: 0, purchaseAmount: '0', purchaseCount: 0);

List<DashboardPoint> hourlySeries({String saleAt10 = '0'}) => List.generate(
      24,
      (hour) => DashboardPoint(
        bucket: '2026-10-07T${hour.toString().padLeft(2, '0')}:00',
        saleAmount: hour == 10 ? saleAt10 : '0',
        purchaseAmount: '0',
      ),
    );

final noActions = DashboardActions(
  onNewSale: () {},
  onNewPurchase: () {},
  onOpenSales: () {},
  onOpenPurchases: () {},
  onOpenStock: () {},
  onOpenStockFilter: (_) {},
  onOpenMovements: () {},
);

Future<void> pumpDashboard(
  WidgetTester tester, {
  DashboardSnapshot? data,
  bool isLoading = false,
  Object? error,
  DashboardActions? actions,
  VoidCallback? onRetry,
  double width = 400,
}) async {
  // Tall phone so the whole lazy list is built.
  tester.view.physicalSize = Size(width * 3, 3200 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: DashboardView(
          userName: 'Anis',
          role: 'ADMIN',
          period: 'today',
          onPeriodChanged: (_) {},
          data: data,
          isLoading: isLoading,
          error: error,
          onRetry: onRetry ?? () {},
          onRefresh: () async {},
          actions: actions ?? noActions,
          now: now,
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('loading shows skeletons, not a full-screen spinner', (tester) async {
    await pumpDashboard(tester, isLoading: true);

    expect(find.byType(DashboardSkeleton), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Bonjour, Anis'), findsOneWidget);
    expect(find.text('Mercredi 7 octobre'), findsOneWidget);
    expect(find.text('Administrateur'), findsOneWidget);
  });

  testWidgets('empty period shows clear empty states', (tester) async {
    await pumpDashboard(tester, data: snapshot(previous: zeroPrevious, series: hourlySeries()));

    expect(find.text('Aucune alerte stock'), findsOneWidget);
    expect(find.text('Aucune vente ni aucun achat aujourd’hui'), findsOneWidget);
    expect(find.text('Aucune vente aujourd’hui'), findsOneWidget);
    expect(find.text('Aucun mouvement de stock aujourd’hui'), findsOneWidget);
    // Both periods at zero: no variation badge at all.
    expect(find.byType(VariationBadge), findsNothing);
  });

  testWidgets('KPIs come from the model, with "Nouveau" when previous is 0', (tester) async {
    await pumpDashboard(
      tester,
      data: snapshot(
        saleAmount: '750',
        saleCount: 1,
        purchaseAmount: '900',
        purchaseCount: 2,
        previous: const PeriodTotals(saleAmount: '0', saleCount: 0, purchaseAmount: '600', purchaseCount: 1),
        series: hourlySeries(saleAt10: '750'),
        outOfStock: 2,
      ),
    );

    expect(find.text(formatAmount('750')), findsOneWidget);
    expect(find.text(formatAmount('900')), findsOneWidget);
    expect(find.text(formatAmount('1250')), findsOneWidget);
    expect(find.text('1 vente'), findsOneWidget);
    expect(find.text('2 achats'), findsOneWidget);
    expect(find.text('2 en alerte'), findsOneWidget);
    // Sales: previous = 0 -> "Nouveau", never +∞ %.
    expect(find.text('Nouveau'), findsOneWidget);
    expect(find.textContaining('∞'), findsNothing);
    // Purchases: 900 vs 600 -> +50 %.
    expect(find.text('+50 %'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^Ventes aujourd’hui : ')), findsOneWidget);
  });

  for (final width in [320.0, 360.0, 800.0]) {
    testWidgets('no overflow with large amounts at ${width.toInt()} px', (tester) async {
      await pumpDashboard(
        tester,
        width: width,
        data: snapshot(
          saleAmount: '987654321.123',
          saleCount: 1234,
          purchaseAmount: '123456789.999',
          purchaseCount: 999,
          previous: const PeriodTotals(saleAmount: '1', saleCount: 1, purchaseAmount: '1', purchaseCount: 1),
          series: hourlySeries(saleAt10: '987654321.123'),
          outOfStock: 12,
          lowStock: 40,
          topProducts: const [
            TopProduct(id: 'p', name: 'Produit au nom vraiment très long pour tester', quantity: '1234.5', amount: '987654321.123'),
          ],
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(KpiCard), findsNWidgets(4));
    });
  }

  testWidgets('network error keeps data on screen with a retry banner', (tester) async {
    var retried = 0;
    await pumpDashboard(
      tester,
      data: snapshot(saleAmount: '750', saleCount: 1, previous: zeroPrevious),
      error: const ApiException('Connexion impossible. Vérifiez votre connexion Internet.'),
      onRetry: () => retried++,
    );

    expect(find.text('Connexion impossible. Vérifiez votre connexion Internet.'), findsOneWidget);
    expect(find.text(formatAmount('750')), findsOneWidget);
    expect(find.byType(KpiCard), findsNWidgets(4));

    await tester.tap(find.text('Réessayer'));
    expect(retried, 1);
  });

  testWidgets('error without data shows a retry panel', (tester) async {
    await pumpDashboard(
      tester,
      error: const ApiException('Connexion impossible. Vérifiez votre connexion Internet.'),
    );

    expect(find.text('Réessayer'), findsOneWidget);
    expect(find.byType(KpiCard), findsNothing);
    expect(find.byType(DashboardSkeleton), findsNothing);
  });

  testWidgets('stock alerts open Stock with the matching filter', (tester) async {
    String? opened;
    await pumpDashboard(
      tester,
      data: snapshot(outOfStock: 2, lowStock: 1, previous: zeroPrevious),
      actions: DashboardActions(
        onNewSale: () {},
        onNewPurchase: () {},
        onOpenSales: () {},
        onOpenPurchases: () {},
        onOpenStock: () {},
        onOpenStockFilter: (filter) => opened = filter,
        onOpenMovements: () {},
      ),
    );

    await tester.tap(find.bySemanticsLabel(RegExp('^Stock faible : ')));
    expect(opened, 'low');
    await tester.tap(find.bySemanticsLabel(RegExp('^Rupture : ')));
    expect(opened, 'out');
  });

  testWidgets('recent activity shows movement, signed quantity and time', (tester) async {
    await pumpDashboard(
      tester,
      data: snapshot(
        previous: zeroPrevious,
        movements: [
          StockMovement(
            id: 'm1',
            type: 'SALE',
            quantity: '3.000',
            signedQuantity: '-3.000',
            previousStock: '10.000',
            newStock: '7.000',
            createdAt: now.subtract(const Duration(minutes: 5)),
            productName: 'Kamel Gold',
          ),
        ],
      ),
    );

    expect(find.text('Kamel Gold'), findsOneWidget);
    expect(find.text('−3'), findsOneWidget);
    expect(find.text('Vente · il y a 5 min'), findsOneWidget);
    expect(find.text('Voir tout'), findsOneWidget);
  });
}
