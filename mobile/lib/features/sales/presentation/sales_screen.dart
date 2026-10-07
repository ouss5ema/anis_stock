import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:stock_management/core/utils/dates.dart';
import 'package:stock_management/core/utils/money.dart';
import 'package:stock_management/core/utils/user_message.dart';
import 'package:stock_management/core/widgets/ui_kit.dart';
import 'package:stock_management/data/models/customer.dart';
import 'package:stock_management/data/models/documents.dart';
import 'package:stock_management/data/models/paginated_result.dart';
import 'package:stock_management/data/services/service_providers.dart';

class SalesQuery {
  const SalesQuery({this.search = '', this.customerId, this.status, this.period = 'all'});

  final String search;
  final String? customerId;
  final String? status;
  final String period;

  @override
  bool operator ==(Object other) =>
      other is SalesQuery &&
      other.search == search &&
      other.customerId == customerId &&
      other.status == status &&
      other.period == period;

  @override
  int get hashCode => Object.hash(search, customerId, status, period);
}

final saleFilterCustomersProvider = FutureProvider<PaginatedResult<Customer>>((ref) {
  return ref.watch(customerServiceProvider).list();
});

final salesProvider = FutureProvider.family<PaginatedResult<Sale>, SalesQuery>((ref, query) {
  final dates = query.period == 'all' ? null : periodQuery(query.period);
  return ref.watch(saleServiceProvider).list(
        search: query.search,
        customerId: query.customerId,
        status: query.status,
        from: dates?['from'],
        to: dates?['to'],
      );
});

class SalesScreen extends ConsumerStatefulWidget {
  const SalesScreen({super.key});

  @override
  ConsumerState<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends ConsumerState<SalesScreen> {
  String _search = '';
  String? _customerId;
  String? _status;
  String _period = 'all';
  final _dateFormat = DateFormat('dd/MM/yyyy');

  SalesQuery get _query => SalesQuery(search: _search, customerId: _customerId, status: _status, period: _period);

  void _reset() {
    setState(() {
      _search = '';
      _customerId = null;
      _status = null;
      _period = 'all';
    });
  }

  @override
  Widget build(BuildContext context) {
    final sales = ref.watch(salesProvider(_query));
    final customers = ref.watch(saleFilterCustomersProvider);
    final customerName = customers.asData?.value.items
        .where((customer) => customer.id == _customerId)
        .map((customer) => customer.name)
        .firstOrNull;
    final active = [
      if (_search.isNotEmpty) 'Recherche : $_search',
      if (customerName != null) 'Client : $customerName',
      if (_status == 'CONFIRMED') 'Statut : confirmée',
      if (_status == 'CANCELLED') 'Statut : annulée',
      if (_period == 'today') 'Période : aujourd’hui',
      if (_period == '7d') 'Période : 7 jours',
      if (_period == '30d') 'Période : 30 jours',
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Ventes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/sales/new');
          ref.invalidate(salesProvider);
        },
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle vente'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: SearchField(
              hint: 'Référence ou client',
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
                FilterChoice(label: 'Confirmées', selected: _status == 'CONFIRMED', onSelected: () => setState(() => _status = _status == 'CONFIRMED' ? null : 'CONFIRMED')),
                FilterChoice(label: 'Annulées', selected: _status == 'CANCELLED', onSelected: () => setState(() => _status = _status == 'CANCELLED' ? null : 'CANCELLED')),
              ],
            ),
          ),
          customers.when(
            data: (data) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('Tous clients'),
                    selected: _customerId == null,
                    onSelected: (_) => setState(() => _customerId = null),
                  ),
                  ...data.items.map(
                    (customer) => Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: FilterChip(
                        label: Text(customer.name),
                        selected: _customerId == customer.id,
                        onSelected: (_) => setState(() => _customerId = customer.id),
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
            child: sales.when(
              data: (data) {
                if (data.items.isEmpty) {
                  return const EmptyState(
                    icon: Icons.point_of_sale_outlined,
                    title: 'Aucune vente trouvée',
                    subtitle: 'Essayez de modifier votre recherche ou vos filtres.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(salesProvider(_query)),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 88),
                    itemCount: data.items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final sale = data.items[index];
                      return AppCard(
                        onTap: () => context.push('/sales/${sale.id}'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(sale.referenceNumber, style: Theme.of(context).textTheme.titleMedium),
                                ),
                                StatusChip(
                                  label: sale.status == 'CANCELLED' ? 'Annulée' : 'Confirmée',
                                  color: sale.status == 'CANCELLED'
                                      ? Theme.of(context).colorScheme.error
                                      : const Color(0xFF15803D),
                                ),
                              ],
                            ),
                            Text(sale.customer.name),
                            Text('${_dateFormat.format(sale.saleDate.toLocal())} · ${sale.itemCount ?? sale.items.length} article(s)'),
                            const SizedBox(height: 6),
                            Text(formatDtLabel(sale.totalAmount), style: Theme.of(context).textTheme.titleMedium),
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
                onRetry: () => ref.invalidate(salesProvider(_query)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
