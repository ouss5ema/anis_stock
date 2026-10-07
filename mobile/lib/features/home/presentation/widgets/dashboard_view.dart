import 'package:flutter/material.dart';
import 'package:stock_management/core/theme/app_colors.dart';
import 'package:stock_management/core/theme/app_tokens.dart';
import 'package:stock_management/core/utils/formatters.dart';
import 'package:stock_management/core/utils/user_message.dart';
import 'package:stock_management/data/models/documents.dart';
import 'package:stock_management/features/home/presentation/widgets/dashboard_header.dart';
import 'package:stock_management/features/home/presentation/widgets/dashboard_skeleton.dart';
import 'package:stock_management/features/home/presentation/widgets/kpi_card.dart';
import 'package:stock_management/features/home/presentation/widgets/quick_actions.dart';
import 'package:stock_management/features/home/presentation/widgets/recent_activity_tile.dart';
import 'package:stock_management/features/home/presentation/widgets/sales_purchases_chart.dart';
import 'package:stock_management/features/home/presentation/widgets/section_header.dart';
import 'package:stock_management/features/home/presentation/widgets/stock_alert_card.dart';
import 'package:stock_management/features/home/presentation/widgets/top_products_card.dart';

/// Navigation callbacks of the dashboard, so the view stays display-only.
class DashboardActions {
  const DashboardActions({
    required this.onNewSale,
    required this.onNewPurchase,
    required this.onOpenSales,
    required this.onOpenPurchases,
    required this.onOpenStock,
    required this.onOpenStockFilter,
    required this.onOpenMovements,
  });

  final VoidCallback onNewSale;
  final VoidCallback onNewPurchase;
  final VoidCallback onOpenSales;
  final VoidCallback onOpenPurchases;
  final VoidCallback onOpenStock;
  final ValueChanged<String> onOpenStockFilter;
  final VoidCallback onOpenMovements;
}

String comparisonLabelFor(String period) {
  switch (period) {
    case '7d':
      return 'vs 7 j préc.';
    case '30d':
      return 'vs 30 j préc.';
    default:
      return 'vs hier';
  }
}

String _periodPhrase(String period) {
  switch (period) {
    case '7d':
      return 'sur 7 jours';
    case '30d':
      return 'sur 30 jours';
    default:
      return 'aujourd’hui';
  }
}

class DashboardView extends StatelessWidget {
  const DashboardView({
    super.key,
    required this.userName,
    required this.role,
    required this.period,
    required this.onPeriodChanged,
    required this.data,
    required this.isLoading,
    required this.error,
    required this.onRetry,
    required this.onRefresh,
    required this.actions,
    this.now,
  });

  final String? userName;
  final String? role;
  final String period;
  final ValueChanged<String> onPeriodChanged;

  /// Last data received; kept on screen during reloads and after errors.
  final DashboardSnapshot? data;
  final bool isLoading;
  final Object? error;
  final VoidCallback onRetry;
  final Future<void> Function() onRefresh;
  final DashboardActions actions;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final snapshot = data;
    final List<Widget> content;

    if (snapshot == null && error != null) {
      content = [_ErrorPanel(message: userFacingMessage(error!), onRetry: onRetry)];
    } else if (snapshot == null) {
      content = const [DashboardSkeleton()];
    } else {
      content = [
        if (isLoading) const _ReloadIndicator(),
        if (error != null) _ErrorBanner(message: userFacingMessage(error!), onRetry: onRetry),
        ..._sections(context, snapshot),
      ];
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      edgeOffset: MediaQuery.paddingOf(context).top + AppSpacing.minTouch,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          DashboardHeader(
            userName: userName,
            role: role,
            period: period,
            onPeriodChanged: onPeriodChanged,
            now: now,
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.md,
              AppSpacing.page,
              AppSpacing.xxl,
            ),
            sliver: SliverList(delegate: SliverChildListDelegate(content)),
          ),
        ],
      ),
    );
  }

  List<Widget> _sections(BuildContext context, DashboardSnapshot snapshot) {
    final colors = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final previous = snapshot.previous;
    final comparison = comparisonLabelFor(period);
    final alertCount = snapshot.outOfStockCount + snapshot.lowStockCount;
    final chartVisible = snapshot.series.length > 1;

    final kpis = [
      KpiCard(
        icon: Icons.point_of_sale_outlined,
        label: 'Ventes ${_periodPhrase(period)}',
        value: formatAmount(snapshot.current.saleAmount),
        subtitle: pluralize(snapshot.current.saleCount, 'vente'),
        color: colors.sale,
        containerColor: colors.saleContainer,
        variation: previous == null ? null : Variation.compute(snapshot.current.saleAmount, previous.saleAmount),
        variationTone: VariationTone.positiveIsGood,
        comparisonLabel: comparison,
        onTap: actions.onOpenSales,
      ),
      KpiCard(
        icon: Icons.local_shipping_outlined,
        label: 'Achats ${_periodPhrase(period)}',
        value: formatAmount(snapshot.current.purchaseAmount),
        subtitle: pluralize(snapshot.current.purchaseCount, 'achat'),
        color: colors.purchase,
        containerColor: colors.purchaseContainer,
        variation:
            previous == null ? null : Variation.compute(snapshot.current.purchaseAmount, previous.purchaseAmount),
        variationTone: VariationTone.neutral,
        comparisonLabel: comparison,
        onTap: actions.onOpenPurchases,
      ),
      KpiCard(
        icon: Icons.inventory_2_outlined,
        label: 'Valeur du stock',
        value: formatAmount(snapshot.stockValue),
        subtitle: 'Au prix d’achat',
        color: scheme.primary,
        containerColor: scheme.primaryContainer,
        onTap: actions.onOpenStock,
      ),
      KpiCard(
        icon: Icons.category_outlined,
        label: 'Produits actifs',
        value: formatCount(snapshot.productCount),
        subtitle: alertCount == 0 ? 'Aucune alerte' : '${formatCount(alertCount)} en alerte',
        color: scheme.primary,
        containerColor: scheme.primaryContainer,
        onTap: actions.onOpenStock,
      ),
    ];

    return [
      _KpiGrid(children: kpis),
      const SizedBox(height: AppSpacing.md),
      QuickActions(onNewSale: actions.onNewSale, onNewPurchase: actions.onNewPurchase),
      const SectionHeader(title: 'Alertes stock'),
      StockAlertCard(
        outOfStockCount: snapshot.outOfStockCount,
        lowStockCount: snapshot.lowStockCount,
        outOfStockProducts: snapshot.outOfStockProducts,
        lowStockProducts: snapshot.lowStockProducts,
        onOpenFilter: actions.onOpenStockFilter,
      ),
      if (chartVisible) ...[
        const SectionHeader(title: 'Ventes et achats'),
        if (seriesHasActivity(snapshot.series))
          SalesPurchasesChart(points: snapshot.series, hourly: snapshot.seriesGranularity == 'hour')
        else
          _CompactEmpty(
            icon: Icons.show_chart_rounded,
            message: 'Aucune vente ni aucun achat ${_periodPhrase(period)}',
          ),
      ],
      const SectionHeader(title: 'Produits les plus vendus'),
      if (snapshot.topProducts.isEmpty)
        _CompactEmpty(
          icon: Icons.emoji_events_outlined,
          message: 'Aucune vente ${_periodPhrase(period)}',
          actionLabel: 'Nouvelle vente',
          onAction: actions.onNewSale,
        )
      else
        TopProductsCard(products: snapshot.topProducts),
      SectionHeader(
        title: 'Activité récente',
        actionLabel: 'Voir tout',
        onAction: actions.onOpenMovements,
      ),
      if (snapshot.recentMovements.isEmpty)
        _CompactEmpty(
          icon: Icons.history_rounded,
          message: 'Aucun mouvement de stock ${_periodPhrase(period)}',
        )
      else
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < snapshot.recentMovements.length && i < 6; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 68),
                RecentActivityTile(
                  movement: snapshot.recentMovements[i],
                  onTap: actions.onOpenMovements,
                  now: now,
                ),
              ],
            ],
          ),
        ),
    ];
  }
}

/// 2×2 grid on phones, one column under 340 px, four columns on tablets.
/// Cards of a row share the same height.
class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width < 340 ? 1 : (width >= 640 ? 4 : 2);
        final rows = <Widget>[];
        for (var start = 0; start < children.length; start += columns) {
          final rowItems = children.skip(start).take(columns).toList();
          if (rows.isNotEmpty) rows.add(const SizedBox(height: AppSpacing.sm));
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < columns; i++) ...[
                    if (i > 0) const SizedBox(width: AppSpacing.sm),
                    Expanded(child: i < rowItems.length ? rowItems[i] : const SizedBox.shrink()),
                  ],
                ],
              ),
            ),
          );
        }
        return Column(children: rows);
      },
    );
  }
}

class _CompactEmpty extends StatelessWidget {
  const _CompactEmpty({required this.icon, required this.message, this.actionLabel, this.onAction});

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: Row(
          children: [
            Icon(icon, color: scheme.onSurfaceVariant),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(message, style: TextStyle(color: scheme.onSurfaceVariant)),
            ),
            if (actionLabel != null && onAction != null)
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ),
      ),
    );
  }
}

class _ReloadIndicator extends StatelessWidget {
  const _ReloadIndicator();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.sm),
      child: ClipRRect(
        borderRadius: AppRadius.pillAll,
        child: LinearProgressIndicator(minHeight: 3),
      ),
    );
  }
}

/// Error shown above data already on screen: the data stays visible.
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Semantics(
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xxs, AppSpacing.xxs, AppSpacing.xxs),
          decoration: BoxDecoration(color: colors.dangerContainer, borderRadius: AppRadius.mdAll),
          child: Row(
            children: [
              Icon(Icons.cloud_off_rounded, color: colors.danger, size: 20),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(color: colors.danger, fontWeight: FontWeight.w600),
                ),
              ),
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(foregroundColor: colors.danger),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Error without any data to show yet.
class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Column(
        children: [
          Icon(Icons.cloud_off_rounded, size: 48, color: colors.danger),
          const SizedBox(height: AppSpacing.sm),
          Text(message, textAlign: TextAlign.center, style: text.bodyLarge),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }
}
