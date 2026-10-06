import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:stock_management/core/utils/money.dart';
import 'package:stock_management/core/widgets/ui_kit.dart';
import 'package:stock_management/data/models/documents.dart';
import 'package:stock_management/data/models/paginated_result.dart';
import 'package:stock_management/data/services/service_providers.dart';

final salesProvider = FutureProvider.family<PaginatedResult<Sale>, String>((ref, search) {
  return ref.watch(saleServiceProvider).list(search: search);
});

class SalesScreen extends ConsumerStatefulWidget {
  const SalesScreen({super.key});

  @override
  ConsumerState<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends ConsumerState<SalesScreen> {
  String _search = '';
  final _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  Widget build(BuildContext context) {
    final sales = ref.watch(salesProvider(_search));

    return Scaffold(
      appBar: AppBar(title: const Text('Ventes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/sales/new');
          ref.invalidate(salesProvider(_search));
        },
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle vente'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: SearchField(
              hint: 'Référence ou client',
              onChanged: (value) => setState(() => _search = value),
            ),
          ),
          Expanded(
            child: sales.when(
              data: (data) {
                if (data.items.isEmpty) {
                  return const EmptyState(
                    icon: Icons.point_of_sale_outlined,
                    title: 'Aucune vente pour cette période',
                    subtitle: 'Enregistrez une vente client.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(salesProvider(_search)),
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
                                      : Theme.of(context).colorScheme.primary,
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
                message: error.toString(),
                onRetry: () => ref.invalidate(salesProvider(_search)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
