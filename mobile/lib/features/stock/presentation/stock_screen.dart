import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stock_management/core/utils/labels.dart';
import 'package:stock_management/core/utils/money.dart';
import 'package:stock_management/core/utils/user_message.dart';
import 'package:stock_management/core/widgets/ui_kit.dart';
import 'package:stock_management/data/models/category.dart';
import 'package:stock_management/data/models/paginated_result.dart';
import 'package:stock_management/data/models/product.dart';
import 'package:stock_management/data/services/service_providers.dart';
import 'package:stock_management/features/auth/providers/auth_provider.dart';

class _StockQuery {
  const _StockQuery({this.search = '', this.filter = 'all', this.categoryId, this.sort = 'name'});

  final String search;
  final String filter;
  final String? categoryId;
  final String sort;

  @override
  bool operator ==(Object other) =>
      other is _StockQuery &&
      other.search == search &&
      other.filter == filter &&
      other.categoryId == categoryId &&
      other.sort == sort;

  @override
  int get hashCode => Object.hash(search, filter, categoryId, sort);
}

final stockCategoriesProvider = FutureProvider<PaginatedResult<Category>>((ref) {
  return ref.watch(categoryServiceProvider).list();
});

final stockListProvider = FutureProvider.family<PaginatedResult<Product>, _StockQuery>((ref, query) {
  return ref.watch(productServiceProvider).list(
        search: query.search,
        lowStock: query.filter == 'low',
        outOfStock: query.filter == 'out',
        categoryId: query.categoryId,
        pageSize: 80,
      );
});

class StockScreen extends ConsumerStatefulWidget {
  const StockScreen({super.key});

  @override
  ConsumerState<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends ConsumerState<StockScreen> {
  String _search = '';
  String _filter = 'all';
  String? _categoryId;
  String _sort = 'name';

  @override
  Widget build(BuildContext context) {
    final query = _StockQuery(search: _search, filter: _filter, categoryId: _categoryId, sort: _sort);
    final stock = ref.watch(stockListProvider(query));
    final categories = ref.watch(stockCategoriesProvider);
    final isAdmin = ref.watch(authProvider).user?.role == 'ADMIN';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock'),
        actions: [
          IconButton(
            onPressed: () => context.push('/stock/movements'),
            icon: const Icon(Icons.history),
            tooltip: 'Mouvements',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: SearchField(
              hint: 'Rechercher un article',
              onChanged: (value) => setState(() => _search = value),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                ChoiceChip(label: const Text('Tous'), selected: _filter == 'all', onSelected: (_) => setState(() => _filter = 'all')),
                const SizedBox(width: 8),
                ChoiceChip(label: const Text('Stock faible'), selected: _filter == 'low', onSelected: (_) => setState(() => _filter = 'low')),
                const SizedBox(width: 8),
                ChoiceChip(label: const Text('Rupture'), selected: _filter == 'out', onSelected: (_) => setState(() => _filter = 'out')),
                const SizedBox(width: 8),
                ChoiceChip(label: const Text('Nom'), selected: _sort == 'name', onSelected: (_) => setState(() => _sort = 'name')),
                const SizedBox(width: 8),
                ChoiceChip(label: const Text('Stock'), selected: _sort == 'stock', onSelected: (_) => setState(() => _sort = 'stock')),
              ],
            ),
          ),
          categories.when(
            data: (data) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('Toutes catégories'),
                    selected: _categoryId == null,
                    onSelected: (_) => setState(() => _categoryId = null),
                  ),
                  ...data.items.map(
                    (category) => Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: FilterChip(
                        label: Text(category.name),
                        selected: _categoryId == category.id,
                        onSelected: (_) => setState(() => _categoryId = category.id),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: stock.when(
              data: (data) {
                final items = [...data.items];
                if (_sort == 'stock') {
                  items.sort((a, b) => parseMoney(a.currentStock).compareTo(parseMoney(b.currentStock)));
                }
                if (items.isEmpty) {
                  return const EmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: 'Aucun produit trouvé',
                    subtitle: 'Modifiez la recherche ou les filtres.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(stockListProvider(query)),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final product = items[index];
                      return AppCard(
                        onTap: () => context.push('/stock/movements?productId=${product.id}'),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(product.name, style: Theme.of(context).textTheme.titleMedium),
                                  Text('${product.categoryName ?? 'Sans catégorie'} · ${unitLabel(product.unit)}'),
                                  Text('Seuil ${formatDt(product.minimumStock)} · ${formatDtLabel(product.estimatedValue)}'),
                                  if (isAdmin)
                                    TextButton(
                                      onPressed: () => context.push('/stock/adjust/${product.id}'),
                                      child: const Text('Ajuster'),
                                    ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  formatDt(product.currentStock),
                                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                Text(unitLabel(product.unit), style: Theme.of(context).textTheme.bodySmall),
                                const SizedBox(height: 4),
                                StockStatusChip(status: product.stockStatus),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => ErrorView(
                message: userFacingMessage(error),
                onRetry: () => ref.invalidate(stockListProvider(query)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
