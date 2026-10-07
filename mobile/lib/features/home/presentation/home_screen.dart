import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stock_management/core/utils/dates.dart';
import 'package:stock_management/core/utils/labels.dart';
import 'package:stock_management/core/utils/money.dart';
import 'package:stock_management/core/utils/user_message.dart';
import 'package:stock_management/core/widgets/ui_kit.dart';
import 'package:stock_management/data/models/documents.dart';
import 'package:stock_management/data/services/service_providers.dart';
import 'package:stock_management/features/auth/providers/auth_provider.dart';

final dashboardPeriodProvider = StateProvider<String>((ref) => 'today');

final dashboardProvider = FutureProvider<DashboardSnapshot>((ref) {
  final period = ref.watch(dashboardPeriodProvider);
  return ref.watch(dashboardServiceProvider).load(period: period);
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final period = ref.watch(dashboardPeriodProvider);
    final dashboard = ref.watch(dashboardProvider);
    final colors = Theme.of(context).colorScheme;
    final salesLabel = period == '7d'
        ? 'Ventes sur 7 jours'
        : period == '30d'
            ? 'Ventes sur 30 jours'
            : 'Ventes aujourd’hui';
    final purchasesLabel = period == '7d'
        ? 'Achats sur 7 jours'
        : period == '30d'
            ? 'Achats sur 30 jours'
            : 'Achats aujourd’hui';

    return Scaffold(
      appBar: AppBar(title: const Text('Accueil')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardProvider);
          await ref.read(dashboardProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Bonjour${user != null ? ', ${user.name}' : ''}',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text('Aperçu de votre activité', style: TextStyle(color: colors.onSurfaceVariant)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                FilterChoice(
                  label: 'Aujourd’hui',
                  selected: period == 'today',
                  onSelected: () => ref.read(dashboardPeriodProvider.notifier).state = 'today',
                ),
                FilterChoice(
                  label: '7 jours',
                  selected: period == '7d',
                  onSelected: () => ref.read(dashboardPeriodProvider.notifier).state = '7d',
                ),
                FilterChoice(
                  label: '30 jours',
                  selected: period == '30d',
                  onSelected: () => ref.read(dashboardPeriodProvider.notifier).state = '30d',
                ),
              ],
            ),
            const SizedBox(height: 16),
            dashboard.when(
              data: (data) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          label: 'Produits',
                          value: '${data.productCount}',
                          subtitle: 'Articles actifs',
                          onTap: () => context.go('/stock'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetricCard(
                          label: 'Valeur du stock',
                          value: formatDtLabel(data.stockValue),
                          subtitle: 'Au prix d’achat',
                          onTap: () => context.go('/stock'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          label: purchasesLabel,
                          value: formatDtLabel(data.purchaseAmount),
                          subtitle: '${data.purchaseCount} achat(s)',
                          onTap: () => context.go('/purchases'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetricCard(
                          label: salesLabel,
                          value: formatDtLabel(data.saleAmount),
                          subtitle: '${data.saleCount} vente(s)',
                          onTap: () => context.go('/sales'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text('Attention', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          label: 'Produits en rupture',
                          value: '${data.outOfStockCount}',
                          subtitle: data.outOfStockCount == 1 ? '1 produit' : '${data.outOfStockCount} produits',
                          accent: data.outOfStockCount > 0 ? const Color(0xFFDC2626) : null,
                          onTap: () => context.go('/stock'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetricCard(
                          label: 'Stock faible',
                          value: '${data.lowStockCount}',
                          subtitle: data.lowStockCount == 1 ? '1 produit' : '${data.lowStockCount} produits',
                          accent: data.lowStockCount > 0 ? const Color(0xFFEA580C) : null,
                          onTap: () => context.go('/stock'),
                        ),
                      ),
                    ],
                  ),
                  if (data.outOfStockProducts.isNotEmpty || data.lowStockProducts.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...data.outOfStockProducts.take(4).map(
                          (product) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: AppCard(
                              onTap: () => context.go('/stock'),
                              child: Row(
                                children: [
                                  Expanded(child: Text(product.name)),
                                  const StockStatusChip(status: 'OUT'),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ...data.lowStockProducts.take(4).map(
                          (product) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: AppCard(
                              onTap: () => context.go('/stock'),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${product.name} · ${formatDt(product.currentStock)}',
                                    ),
                                  ),
                                  const StockStatusChip(status: 'LOW'),
                                ],
                              ),
                            ),
                          ),
                        ),
                  ],
                  const SizedBox(height: 12),
                  Text('Activité récente', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (data.recentSales.isEmpty && data.recentPurchases.isEmpty && data.recentMovements.isEmpty)
                    const EmptyState(
                      icon: Icons.inbox_outlined,
                      title: 'Aucune activité sur cette période',
                    ),
                  ...data.recentSales.take(3).map(
                        (sale) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: AppCard(
                            onTap: () => context.push('/sales/${sale.id}'),
                            child: Text(
                              'Vente · ${sale.customer.name} · ${formatDtLabel(sale.totalAmount)}',
                            ),
                          ),
                        ),
                      ),
                  ...data.recentPurchases.take(3).map(
                        (purchase) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: AppCard(
                            onTap: () => context.push('/purchases/${purchase.id}'),
                            child: Text(
                              'Achat · ${purchase.supplier.name} · ${formatDtLabel(purchase.totalAmount)}',
                            ),
                          ),
                        ),
                      ),
                  ...data.recentMovements.take(5).map(
                        (movement) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: AppCard(
                            onTap: () => context.push('/stock/movements'),
                            child: Text(
                              '${formatDateTime(movement.createdAt)} · ${movementTypeLabel(movement.type)} · ${movement.productName ?? 'Produit'}',
                            ),
                          ),
                        ),
                      ),
                  if (data.topProducts.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('Produits les plus vendus', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ...data.topProducts.map(
                      (product) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: AppCard(
                          child: Row(
                            children: [
                              Expanded(child: Text(product.name)),
                              Text(formatDtLabel(product.amount), style: const TextStyle(fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => ErrorView(
                message: userFacingMessage(error),
                onRetry: () => ref.invalidate(dashboardProvider),
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              onTap: () => context.push('/purchases/new'),
              child: const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.shopping_cart_outlined),
                title: Text('Nouvel achat'),
                trailing: Icon(Icons.chevron_right),
              ),
            ),
            const SizedBox(height: 8),
            AppCard(
              onTap: () => context.push('/sales/new'),
              child: const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.point_of_sale_outlined),
                title: Text('Nouvelle vente'),
                trailing: Icon(Icons.chevron_right),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.subtitle,
    this.accent,
    this.onTap,
  });

  final String label;
  final String value;
  final String subtitle;
  final Color? accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
          ),
          Text(subtitle),
        ],
      ),
    );
  }
}
