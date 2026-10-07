import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:stock_management/core/network/api_exception.dart';
import 'package:stock_management/core/theme/app_colors.dart';
import 'package:stock_management/core/theme/app_tokens.dart';
import 'package:stock_management/core/utils/formatters.dart';
import 'package:stock_management/core/utils/money.dart';
import 'package:stock_management/core/utils/number_input.dart';
import 'package:stock_management/core/utils/user_message.dart';
import 'package:stock_management/core/widgets/danger_action_dialog.dart';
import 'package:stock_management/core/widgets/document_admin.dart';
import 'package:stock_management/core/widgets/numeric_field.dart';
import 'package:stock_management/core/widgets/ui_kit.dart';
import 'package:stock_management/data/models/category.dart';
import 'package:stock_management/data/models/paginated_result.dart';
import 'package:stock_management/data/models/product.dart';
import 'package:stock_management/data/services/service_providers.dart';
import 'package:stock_management/features/auth/providers/auth_provider.dart';
import 'package:stock_management/features/home/presentation/home_screen.dart';
import 'package:stock_management/features/stock/presentation/movements_screen.dart';
import 'package:stock_management/features/stock/presentation/stock_screen.dart';

class ProductsQuery {
  const ProductsQuery({
    this.search = '',
    this.categoryId,
    this.filter = 'all',
  });

  final String search;
  final String? categoryId;
  final String filter;

  @override
  bool operator ==(Object other) =>
      other is ProductsQuery && other.search == search && other.categoryId == categoryId && other.filter == filter;

  @override
  int get hashCode => Object.hash(search, categoryId, filter);
}

final productCategoriesProvider = FutureProvider<PaginatedResult<Category>>((ref) {
  return ref.watch(categoryServiceProvider).list();
});

/// `filter`: 'all' | 'low' | 'out' list active products; 'archived' lists
/// archived (inactive) products only.
final productsListProvider = FutureProvider.family<PaginatedResult<Product>, ProductsQuery>((ref, query) {
  return ref.watch(productServiceProvider).list(
        search: query.search,
        archived: query.filter == 'archived',
        categoryId: query.categoryId,
        lowStock: query.filter == 'low',
        outOfStock: query.filter == 'out',
        pageSize: 100,
      );
});

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  String _search = '';
  String? _categoryId;
  String _filter = 'all';

  ProductsQuery get _query => ProductsQuery(search: _search, categoryId: _categoryId, filter: _filter);

  void _reset() {
    setState(() {
      _search = '';
      _categoryId = null;
      _filter = 'all';
    });
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsListProvider(_query));
    final categories = ref.watch(productCategoriesProvider);
    final categoryName = categories.asData?.value.items
        .where((category) => category.id == _categoryId)
        .map((category) => category.name)
        .firstOrNull;
    final active = [
      if (_search.isNotEmpty) 'Recherche : $_search',
      if (categoryName != null) 'Catégorie : $categoryName',
      if (_filter == 'low') 'Stock : faible',
      if (_filter == 'out') 'Stock : rupture',
      if (_filter == 'archived') 'Archivés',
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Produits')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await context.push('/products/new');
          ref.invalidate(productsListProvider);
        },
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: SearchField(
              hint: 'Nom ou SKU',
              onChanged: (value) => setState(() => _search = value),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                FilterChoice(label: 'Tous', selected: _filter == 'all', onSelected: () => setState(() => _filter = 'all')),
                FilterChoice(label: 'Stock faible', selected: _filter == 'low', onSelected: () => setState(() => _filter = 'low')),
                FilterChoice(label: 'Rupture', selected: _filter == 'out', onSelected: () => setState(() => _filter = 'out')),
                FilterChoice(label: 'Archivés', selected: _filter == 'archived', onSelected: () => setState(() => _filter = 'archived')),
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
          ActiveFiltersBar(labels: active, onReset: _reset),
          Expanded(
            child: products.when(
              data: (data) {
                if (data.items.isEmpty) {
                  return const EmptyState(
                    icon: Icons.category_outlined,
                    title: 'Aucun produit trouvé',
                    subtitle: 'Essayez de modifier votre recherche ou vos filtres.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(productsListProvider(_query)),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 88),
                    itemCount: data.items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final product = data.items[index];
                      return AppCard(
                        onTap: () async {
                          await context.push('/products/${product.id}/edit');
                          ref.invalidate(productsListProvider);
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(product.name, style: Theme.of(context).textTheme.titleMedium),
                                ),
                                if (product.isArchived)
                                  const ArchivedChip()
                                else
                                  StockStatusChip(status: product.stockStatus),
                              ],
                            ),
                            Text(
                              [
                                if (product.sku != null && product.sku!.isNotEmpty) product.sku!,
                                product.categoryName ?? '',
                              ].where((part) => part.isNotEmpty).join(' · '),
                            ),
                            Text('Stock ${formatDt(product.currentStock)} · Seuil ${formatDt(product.minimumStock)}'),
                            Text('Achat ${formatDt(product.purchasePrice)} · Vente ${formatDt(product.salePrice)}'),
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
                onRetry: () => ref.invalidate(productsListProvider(_query)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArchivedBanner extends StatelessWidget {
  const _ArchivedBanner({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final date = product.archivedAt == null
        ? null
        : DateFormat('dd/MM/yyyy HH:mm').format(product.archivedAt!.toLocal());
    final details = [
      if (date != null) 'le $date',
      if (product.archivedByName != null) 'par ${product.archivedByName}',
    ].join(' ');
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: colors.neutralContainer, borderRadius: AppRadius.mdAll),
      child: Row(
        children: [
          Icon(Icons.archive_outlined, color: colors.neutral),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              details.isEmpty ? 'Produit archivé' : 'Produit archivé $details',
              style: TextStyle(color: colors.neutral, fontWeight: FontWeight.w700),
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
  Product? _product;
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
          _sku.text = product.sku ?? '';
          _name.text = product.name;
          _description.text = product.description ?? '';
          _purchase.text = formatDecimalForInput(product.purchasePrice);
          _sale.text = formatDecimalForInput(product.salePrice);
          _minStock.text = formatDecimalForInput(product.minimumStock);
          _unit = product.unit;
          _categoryId = product.categoryId;
          _product = product;
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
    if (_name.text.trim().length < 2 || _categoryId == null) {
      setState(() => _error = 'Le nom et la catégorie sont obligatoires');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final sku = _sku.text.trim();
    final body = {
      'sku': sku.isEmpty ? null : sku,
      'name': _name.text.trim(),
      'description': _description.text.trim().isEmpty ? null : _description.text.trim(),
      'categoryId': _categoryId,
      'unit': _unit,
      'purchasePrice': decimalForApi(_purchase.text),
      'salePrice': decimalForApi(_sale.text),
      'minimumStock': _minStock.text.trim().isEmpty ? '0' : decimalForApi(_minStock.text),
      // Status changes go through archive/restore (ADMIN, audited).
    };
    try {
      if (widget.productId == null) {
        await ref.read(productServiceProvider).create(body);
      } else {
        await ref.read(productServiceProvider).update(widget.productId!, body);
      }
      if (!mounted) return;
      ref.invalidate(productsListProvider);
      ref.invalidate(dashboardProvider);
      ref.invalidate(stockListProvider);
      ref.invalidate(movementsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.productId == null ? 'Produit enregistré' : 'Produit mis à jour')),
      );
      context.pop();
    } on ApiException catch (error) {
      setState(() => _error = userFacingMessage(error));
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
          if (_product?.isArchived ?? false) ...[
            _ArchivedBanner(product: _product!),
            const SizedBox(height: 12),
          ],
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
          TextField(controller: _sku, decoration: const InputDecoration(labelText: 'SKU (optionnel)')),
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
          DecimalTextField(controller: _purchase, labelText: 'Prix d’achat'),
          const SizedBox(height: 12),
          DecimalTextField(controller: _sale, labelText: 'Prix de vente'),
          const SizedBox(height: 12),
          DecimalTextField(
            controller: _minStock,
            labelText: 'Seuil d’alerte stock',
            helperText: 'Alerte « stock faible » lorsque le stock atteint ce nombre.',
          ),
          const SizedBox(height: 12),
          TextField(controller: _description, decoration: const InputDecoration(labelText: 'Description (optionnel)')),
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
          ],
          if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          const SizedBox(height: 12),
          FilledButton(onPressed: _saving ? null : _save, child: const Text('Enregistrer')),
          // ADMIN only (enforced by the backend as well).
          if (widget.productId != null && ref.watch(isAdminProvider)) ...[
            const SizedBox(height: 24),
            if (_product?.isArchived ?? false)
              FilledButton.tonalIcon(
                onPressed: _saving ? null : _restore,
                icon: const Icon(Icons.unarchive_outlined),
                label: const Text('Restaurer le produit'),
              )
            else
              DangerButton(
                label: 'Archiver le produit',
                icon: Icons.archive_outlined,
                onPressed: _saving ? null : _archiveOrDelete,
              ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _refreshCatalog() {
    ref.invalidate(productsListProvider);
    ref.invalidate(dashboardProvider);
    ref.invalidate(stockListProvider);
    ref.invalidate(movementsProvider);
  }

  Future<void> _archiveOrDelete() async {
    final service = ref.read(productServiceProvider);
    final messenger = ScaffoldMessenger.of(context);
    final ProductDeletePreview preview;
    try {
      preview = await service.deletePreview(widget.productId!);
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(userFacingMessage(error))));
      return;
    }
    if (!mounted) return;

    final name = _name.text.trim();
    final result = await showDangerActionDialog(
      context,
      title: preview.willDelete ? 'Supprimer le produit ?' : 'Archiver le produit ?',
      confirmLabel: preview.willDelete ? 'Supprimer le produit' : 'Archiver le produit',
      reasonRequired: false,
      suggestions: const ['Plus vendu', 'Doublon', 'Erreur de saisie'],
      consequences: preview.willDelete
          ? [
              '« $name » n’a aucun mouvement, aucun achat ni aucune vente : il sera définitivement supprimé.',
            ]
          : [
              '« $name » sera masqué des listes, des sélecteurs d’achat et de vente et du tableau de bord.',
              'Il restera visible dans l’historique, les mouvements et les journaux.',
              'Vous pourrez le restaurer depuis le filtre « Archivés ».',
            ],
      warning: preview.hasStock
          ? 'Ce produit a encore un stock de ${formatQuantity(preview.currentStock)}. '
              'Ce stock ne sera pas modifié, mais il ne comptera plus dans la valeur du stock du tableau de bord.'
          : null,
    );
    if (result == null) return;

    setState(() => _saving = true);
    try {
      final deleted = await service.delete(widget.productId!, reason: result.reason);
      _refreshCatalog();
      messenger.showSnackBar(SnackBar(content: Text(deleted ? 'Produit supprimé' : 'Produit archivé')));
      if (mounted) context.pop();
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(userFacingMessage(error))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _restore() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      final restored = await ref.read(productServiceProvider).restore(widget.productId!);
      _refreshCatalog();
      if (!mounted) return;
      setState(() => _product = restored);
      messenger.showSnackBar(const SnackBar(content: Text('Produit restauré')));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(userFacingMessage(error))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
