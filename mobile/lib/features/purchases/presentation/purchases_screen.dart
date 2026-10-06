import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:stock_management/core/utils/money.dart';
import 'package:stock_management/core/widgets/ui_kit.dart';
import 'package:stock_management/data/models/documents.dart';
import 'package:stock_management/data/models/paginated_result.dart';
import 'package:stock_management/data/services/service_providers.dart';

final purchasesProvider = FutureProvider.family<PaginatedResult<Purchase>, String>((ref, search) {
  return ref.watch(purchaseServiceProvider).list(search: search);
});

class PurchasesScreen extends ConsumerStatefulWidget {
  const PurchasesScreen({super.key});

  @override
  ConsumerState<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends ConsumerState<PurchasesScreen> {
  String _search = '';
  final _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  Widget build(BuildContext context) {
    final purchases = ref.watch(purchasesProvider(_search));

    return Scaffold(
      appBar: AppBar(title: const Text('Achats')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/purchases/new');
          ref.invalidate(purchasesProvider(_search));
        },
        icon: const Icon(Icons.add),
        label: const Text('Nouvel achat'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: SearchField(
              hint: 'Référence ou fournisseur',
              onChanged: (value) => setState(() => _search = value),
            ),
          ),
          Expanded(
            child: purchases.when(
              data: (data) {
                if (data.items.isEmpty) {
                  return const EmptyState(
                    icon: Icons.shopping_cart_outlined,
                    title: 'Aucun achat enregistré.',
                    subtitle: 'Enregistrez une réception fournisseur.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(purchasesProvider(_search)),
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
                                      : Theme.of(context).colorScheme.primary,
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
                message: error.toString(),
                onRetry: () => ref.invalidate(purchasesProvider(_search)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
