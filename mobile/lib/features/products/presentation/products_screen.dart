import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stock_management/core/network/api_exception.dart';
import 'package:stock_management/core/utils/money.dart';
import 'package:stock_management/core/utils/user_message.dart';
import 'package:stock_management/core/widgets/ui_kit.dart';
import 'package:stock_management/data/models/category.dart';
import 'package:stock_management/data/models/paginated_result.dart';
import 'package:stock_management/data/models/product.dart';
import 'package:stock_management/data/services/service_providers.dart';

final productsListProvider = FutureProvider.family<PaginatedResult<Product>, String>((ref, search) {
  return ref.watch(productServiceProvider).list(search: search, includeInactive: true);
});

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsListProvider(_search));

    return Scaffold(
      appBar: AppBar(title: const Text('Produits')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await context.push('/products/new');
          ref.invalidate(productsListProvider(_search));
        },
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: SearchField(
              hint: 'Nom ou SKU',
              onChanged: (value) => setState(() => _search = value),
            ),
          ),
          Expanded(
            child: products.when(
              data: (data) {
                if (data.items.isEmpty) {
                  return const EmptyState(icon: Icons.category_outlined, title: 'Aucun produit');
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(productsListProvider(_search)),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 88),
                    itemCount: data.items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final product = data.items[index];
                      return AppCard(
                        onTap: () => context.push('/products/${product.id}/edit'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(product.name, style: Theme.of(context).textTheme.titleMedium),
                                ),
                                StockStatusChip(status: product.stockStatus),
                              ],
                            ),
                            Text('${product.sku} · ${product.categoryName ?? ''}'),
                            Text('Stock ${formatDt(product.currentStock)} · Seuil ${formatDt(product.minimumStock)}'),
                            Text('Achat ${formatDt(product.purchasePrice)} · Vente ${formatDt(product.salePrice)}'),
                            if (!product.isActive)
                              Text('Inactif', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => ErrorView(message: error.toString()),
            ),
          ),
        ],
      ),
    );
  }
}

class ProductFormScreen extends ConsumerStatefulWidget {
  const ProductFormScreen({super.key, this.productId});

  final String? productId;

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _sku = TextEditingController();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _purchase = TextEditingController();
  final _sale = TextEditingController();
  final _minStock = TextEditingController(text: '0');
  String _unit = 'PACK';
  String? _categoryId;
  bool _isActive = true;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<Category> _categories = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final categories = await ref.read(categoryServiceProvider).list(includeInactive: true);
      Product? product;
      if (widget.productId != null) {
        product = await ref.read(productServiceProvider).getById(widget.productId!);
      }
      if (!mounted) return;
      setState(() {
        _categories = categories.items;
        if (product != null) {
          _sku.text = product.sku;
          _name.text = product.name;
          _description.text = product.description ?? '';
          _purchase.text = formatDt(product.purchasePrice);
          _sale.text = formatDt(product.salePrice);
          _minStock.text = formatDt(product.minimumStock);
          _unit = product.unit;
          _categoryId = product.categoryId;
          _isActive = product.isActive;
        } else if (_categories.isNotEmpty) {
          _categoryId = _categories.first.id;
        }
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = userFacingMessage(error);
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _sku.dispose();
    _name.dispose();
    _description.dispose();
    _purchase.dispose();
    _sale.dispose();
    _minStock.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().length < 2 || _sku.text.trim().isEmpty || _categoryId == null) {
      setState(() => _error = 'SKU, nom et catégorie sont obligatoires');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final body = {
      'sku': _sku.text.trim(),
      'name': _name.text.trim(),
      'description': _description.text.trim().isEmpty ? null : _description.text.trim(),
      'categoryId': _categoryId,
      'unit': _unit,
      'purchasePrice': _purchase.text.trim(),
      'salePrice': _sale.text.trim(),
      'minimumStock': _minStock.text.trim().isEmpty ? '0' : _minStock.text.trim(),
      'isActive': _isActive,
    };
    try {
      if (widget.productId == null) {
        await ref.read(productServiceProvider).create(body);
      } else {
        await ref.read(productServiceProvider).update(widget.productId!, body);
      }
      if (mounted) context.pop();
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.productId == null ? 'Nouveau produit' : 'Modifier le produit')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(controller: _sku, decoration: const InputDecoration(labelText: 'SKU')),
          const SizedBox(height: 12),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nom')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _categoryId,
            items: _categories
                .map((category) => DropdownMenuItem(value: category.id, child: Text(category.name)))
                .toList(),
            onChanged: (value) => setState(() => _categoryId = value),
            decoration: const InputDecoration(labelText: 'Catégorie'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _unit,
            items: const [
              DropdownMenuItem(value: 'UNIT', child: Text('Unité')),
              DropdownMenuItem(value: 'PACK', child: Text('Paquet')),
              DropdownMenuItem(value: 'CARTON', child: Text('Carton')),
              DropdownMenuItem(value: 'BOX', child: Text('Boîte')),
              DropdownMenuItem(value: 'RECHARGE', child: Text('Recharge')),
              DropdownMenuItem(value: 'OTHER', child: Text('Autre')),
            ],
            onChanged: (value) => setState(() => _unit = value ?? 'PACK'),
            decoration: const InputDecoration(labelText: 'Unité'),
          ),
          const SizedBox(height: 12),
          TextField(controller: _purchase, decoration: const InputDecoration(labelText: 'Prix d’achat indicatif')),
          const SizedBox(height: 12),
          TextField(controller: _sale, decoration: const InputDecoration(labelText: 'Prix de vente')),
          const SizedBox(height: 12),
          TextField(controller: _minStock, decoration: const InputDecoration(labelText: 'Stock minimum')),
          const SizedBox(height: 12),
          TextField(controller: _description, decoration: const InputDecoration(labelText: 'Description')),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Actif'),
            value: _isActive,
            onChanged: (value) async {
              if (!value) {
                final confirmed = await confirmAction(
                  context,
                  title: 'Désactiver le produit',
                  message: 'Ce produit ne pourra plus être sélectionné dans les achats et ventes.',
                );
                if (!confirmed) return;
              }
              setState(() => _isActive = value);
            },
          ),
          if (widget.productId != null) ...[
            const SizedBox(height: 12),
            Text('Historique', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            AppCard(
              onTap: () => context.push('/stock/movements?productId=${widget.productId}'),
              child: const ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Mouvements de stock'),
                trailing: Icon(Icons.chevron_right),
              ),
            ),
            const Text('Le prix d’achat indicatif n’est pas un prix historique d’achat.'),
          ],
          if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          FilledButton(onPressed: _saving ? null : _save, child: const Text('Enregistrer')),
        ],
      ),
    );
  }
}
