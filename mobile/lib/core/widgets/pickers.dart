import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_management/core/utils/labels.dart';
import 'package:stock_management/core/utils/money.dart';
import 'package:stock_management/core/widgets/ui_kit.dart';
import 'package:stock_management/data/models/customer.dart';
import 'package:stock_management/data/models/product.dart';
import 'package:stock_management/data/models/supplier.dart';
import 'package:stock_management/data/services/service_providers.dart';

Future<Product?> pickProduct(BuildContext context, WidgetRef ref, {bool showSalePrice = false}) {
  return showModalBottomSheet<Product>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _ProductPickerSheet(showSalePrice: showSalePrice),
  );
}

Future<Supplier?> pickSupplier(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<Supplier>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => const _SupplierPickerSheet(),
  );
}

Future<Customer?> pickCustomer(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<Customer>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => const _CustomerPickerSheet(),
  );
}

class _ProductPickerSheet extends ConsumerStatefulWidget {
  const _ProductPickerSheet({this.showSalePrice = false});

  final bool showSalePrice;

  @override
  ConsumerState<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends ConsumerState<_ProductPickerSheet> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(productServiceProvider).list(search: _search, pageSize: 30);

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          children: [
            Text('Choisir un produit', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            SearchField(hint: 'Nom ou SKU', onChanged: (value) => setState(() => _search = value)),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder(
                future: async,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final items = snapshot.data!.items;
                  if (items.isEmpty) {
                    return const EmptyState(icon: Icons.search_off, title: 'Aucun produit');
                  }
                  return ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final product = items[index];
                      return AppCard(
                        onTap: () => Navigator.pop(context, product),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(product.name, style: Theme.of(context).textTheme.titleMedium),
                                  Text('${product.sku} · Stock ${formatDt(product.currentStock)} ${unitLabel(product.unit)}'),
                                  Text(
                                    widget.showSalePrice
                                        ? 'Prix ${formatDtLabel(product.salePrice)}'
                                        : 'Prix d’achat ${formatDtLabel(product.purchasePrice)}',
                                  ),
                                ],
                              ),
                            ),
                            StockStatusChip(status: product.stockStatus),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupplierPickerSheet extends ConsumerStatefulWidget {
  const _SupplierPickerSheet();

  @override
  ConsumerState<_SupplierPickerSheet> createState() => _SupplierPickerSheetState();
}

class _SupplierPickerSheetState extends ConsumerState<_SupplierPickerSheet> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    return _PartnerSheet(
      title: 'Choisir un fournisseur',
      future: ref.watch(supplierServiceProvider).list(search: _search),
      onSearch: (value) => setState(() => _search = value),
      itemBuilder: (context, index, data) {
        final supplier = data[index] as Supplier;
        return AppCard(
          onTap: () => Navigator.pop(context, supplier),
          child: Text(supplier.name, style: Theme.of(context).textTheme.titleMedium),
        );
      },
    );
  }
}

class _CustomerPickerSheet extends ConsumerStatefulWidget {
  const _CustomerPickerSheet();

  @override
  ConsumerState<_CustomerPickerSheet> createState() => _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends ConsumerState<_CustomerPickerSheet> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    return _PartnerSheet(
      title: 'Choisir un client',
      future: ref.watch(customerServiceProvider).list(search: _search),
      onSearch: (value) => setState(() => _search = value),
      itemBuilder: (context, index, data) {
        final customer = data[index] as Customer;
        return AppCard(
          onTap: () => Navigator.pop(context, customer),
          child: Text(customer.name, style: Theme.of(context).textTheme.titleMedium),
        );
      },
    );
  }
}

class _PartnerSheet extends StatelessWidget {
  const _PartnerSheet({
    required this.title,
    required this.future,
    required this.onSearch,
    required this.itemBuilder,
  });

  final String title;
  final Future<dynamic> future;
  final ValueChanged<String> onSearch;
  final Widget Function(BuildContext context, int index, List<dynamic> data) itemBuilder;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            SearchField(hint: 'Rechercher', onChanged: onSearch),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder(
                future: future,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final items = (snapshot.data as dynamic).items as List<dynamic>;
                  if (items.isEmpty) {
                    return const EmptyState(icon: Icons.search_off, title: 'Aucun résultat');
                  }
                  return ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => itemBuilder(context, index, items),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
