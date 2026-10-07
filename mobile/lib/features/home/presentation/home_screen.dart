import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stock_management/data/models/documents.dart';
import 'package:stock_management/data/services/service_providers.dart';
import 'package:stock_management/features/auth/providers/auth_provider.dart';
import 'package:stock_management/features/home/presentation/widgets/dashboard_view.dart';
import 'package:stock_management/features/stock/presentation/stock_screen.dart';

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

    return Scaffold(
      body: DashboardView(
        userName: user?.name,
        role: user?.role,
        period: period,
        onPeriodChanged: (value) => ref.read(dashboardPeriodProvider.notifier).state = value,
        // Riverpod keeps the previous value while reloading or after an error.
        data: dashboard.valueOrNull,
        isLoading: dashboard.isLoading,
        error: dashboard.hasError ? dashboard.error : null,
        onRetry: () => ref.invalidate(dashboardProvider),
        onRefresh: () async {
          ref.invalidate(dashboardProvider);
          try {
            await ref.read(dashboardProvider.future);
          } catch (_) {
            // The error banner is shown by the view.
          }
        },
        actions: DashboardActions(
          onNewSale: () => context.push('/sales/new'),
          onNewPurchase: () => context.push('/purchases/new'),
          onOpenSales: () => context.go('/sales'),
          onOpenPurchases: () => context.go('/purchases'),
          onOpenStock: () {
            ref.read(stockFilterProvider.notifier).state = 'all';
            context.go('/stock');
          },
          onOpenStockFilter: (filter) {
            ref.read(stockFilterProvider.notifier).state = filter;
            context.go('/stock');
          },
          onOpenMovements: () => context.push('/stock/movements'),
        ),
      ),
    );
  }
}
