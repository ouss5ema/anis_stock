import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:stock_management/core/utils/dates.dart';
import 'package:stock_management/core/utils/money.dart';
import 'package:stock_management/core/utils/user_message.dart';
import 'package:stock_management/core/widgets/ui_kit.dart';
import 'package:stock_management/data/models/documents.dart';
import 'package:stock_management/data/models/paginated_result.dart';
import 'package:stock_management/data/models/supplier.dart';
import 'package:stock_management/data/services/service_providers.dart';

class PurchasesQuery {
  const PurchasesQuery({this.search = '', this.supplierId, this.status, this.period = 'all'});

  final String search;
  final String? supplierId;
  final String? status;
  final String period;

  @override
  bool operator ==(Object other) =>
      other is PurchasesQuery &&
      other.search == search &&
      other.supplierId == supplierId &&
      other.status == status &&
      other.period == period;

  @override
  int get hashCode => Object.hash(search, supplierId, status, period);
}

final purchaseFilterSuppliersProvider = FutureProvider<PaginatedResult<Supplier>>((ref) {
  return ref.watch(supplierServiceProvider).list();
});

final purchasesProvider = FutureProvider.family<PaginatedResult<Purchase>, PurchasesQuery>((ref, query) {
  final dates = query.period == 'all' ? null : periodQuery(query.period);
  return ref.watch(purchaseServiceProvider).list(
        search: query.search,
        supplierId: query.supplierId,
        status: query.status,
        from: dates?['from'],
        to: dates?['to'],
      );
});

class PurchasesScreen extends ConsumerStatefulWidget {
  const PurchasesScreen({super.key});

  @override
  ConsumerState<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends ConsumerState<PurchasesScreen> {
  String _search = '';
  String? _supplierId;
  String? _status;
  String _period = 'all';
  final _dateFormat = DateFormat('dd/MM/yyyy');

  PurchasesQuery get _query =>
      PurchasesQuery(search: _search, supplierId: _supplierId, status: _status, period: _period);

  void _reset() {
    setState(() {
      _search = '';
      _supplierId = null;
      _status = null;
      _period = 'all';
    });
  }

  @override
  Widget build(BuildContext context) {
    final purchases = ref.watch(purchasesProvider(_query));
    final suppliers = ref.watch(purchaseFilterSuppliersProvider);
    final supplierName = suppliers.asData?.value.items
        .where((supplier) => supplier.id == _supplierId)
        .map((supplier) => supplier.name)
        .firstOrNull;
    final active = [
      if (_search.isNotEmpty) 'Recherche : $_search',
      if (supplierName != null) 'Fournisseur : $supplierName',
      if (_status == 'CONFIRMED') 'Statut : confirmé',
      if (_status == 'CANCELLED') 'Statut : annulé',
      if (_period == 'today') 'Période : aujourd’hui',
      if (_period == '7d') 'Période : 7 jours',
      if (_period == '30d') 'Période : 30 jours',
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Achats')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/purchases/new');
          ref.invalidate(purchasesProvider);
        },
        icon: const Icon(Icons.add),
        label: const Text('Nouvel achat'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: SearchField(
              hint: 'Référence ou fournisseur',
              onChanged: (value) => setState(() => _search = value),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                FilterChoice(label: 'Toutes dates', selected: _period == 'all', onSelected: () => setState(() => _period = 'all')),
                FilterChoice(label: 'Aujourd’hui', selected: _period == 'today', onSelected: () => setState(() => _period = 'today')),
                FilterChoice(label: '7 jours', selected: _period == '7d', onSelected: () => setState(() => _period = '7d')),
                FilterChoice(label: '30 jours', selected: _period == '30d', onSelected: () => setState(() => _period = '30d')),
                FilterChoice(label: 'Confirmés', selected: _status == 'CONFIRMED', onSelected: () => setState(() => _status = _status == 'CONFIRMED' ? null : 'CONFIRMED')),
                FilterChoice(label: 'Annulés', selected: _status == 'CANCELLED', onSelected: () => setState(() => _status = _status == 'CANCELLED' ? null : 'CANCELLED')),
              ],
            ),
          ),
          suppliers.when(
            data: (data) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('Tous fournisseurs'),
                    selected: _supplierId == null,
                    onSelected: (_) => setState(() => _supplierId = null),
                  ),
                  ...data.items.map(
                    (supplier) => Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: FilterChip(
                        label: Text(supplier.name),
                        selected: _supplierId == supplier.id,
                        onSelected: (_) => setState(() => _supplierId = supplier.id),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          ActiveFiltersBar(labels: active, onReset: _reset),
          Expanded(
            child: purchases.when(
              data: (data) {
                if (data.items.isEmpty) {
                  return const EmptyState(
                    icon: Icons.shopping_cart_outlined,
                    title: 'Aucun achat trouvé',
                    subtitle: 'Essayez de modifier votre recherche ou vos filtres.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(purchasesProvider(_query)),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 88),
                    itemCount: data.items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final purchase = data.items[index];
                      return AppCard(
                        onTap: () => context.push('/purchases/${purchase.id}'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    purchase.referenceNumber,
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                ),
                                StatusChip(
                                  label: purchase.status == 'CANCELLED' ? 'Annulé' : 'Confirmé',
                                  color: purchase.status == 'CANCELLED'
                                      ? Theme.of(context).colorScheme.error
                                      : const Color(0xFF15803D),
                                ),
                              ],
                            ),
                            Text(purchase.supplier.name),
                            Text(
                              '${_dateFormat.format(purchase.purchaseDate.toLocal())} · ${purchase.itemCount ?? purchase.items.length} article(s)',
                            ),
                            const SizedBox(height: 6),
                            Text(
                              formatDtLabel(purchase.totalAmount),
                              style: Theme.of(context).textTheme.titleMedium,
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
                onRetry: () => ref.invalidate(purchasesProvider(_query)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
