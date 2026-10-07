import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_management/core/network/api_exception.dart';
import 'package:stock_management/core/theme/app_colors.dart';
import 'package:stock_management/core/theme/app_tokens.dart';
import 'package:stock_management/core/utils/user_message.dart';
import 'package:stock_management/core/widgets/danger_action_dialog.dart';
import 'package:stock_management/core/widgets/document_admin.dart';
import 'package:stock_management/core/widgets/ui_kit.dart';
import 'package:stock_management/data/models/category.dart';
import 'package:stock_management/data/models/paginated_result.dart';
import 'package:stock_management/data/services/service_providers.dart';
import 'package:stock_management/features/auth/providers/auth_provider.dart';
import 'package:stock_management/features/products/presentation/products_screen.dart';
import 'package:stock_management/features/stock/presentation/stock_screen.dart';

final categoriesProvider = FutureProvider<PaginatedResult<Category>>((ref) {
  return ref.watch(categoryServiceProvider).list(includeInactive: true);
});

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Catégories')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(context, ref),
        child: const Icon(Icons.add),
      ),
      body: categories.when(
        data: (data) {
          if (data.items.isEmpty) {
            return const EmptyState(icon: Icons.account_tree_outlined, title: 'Aucune catégorie');
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(categoriesProvider),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 88),
              itemCount: data.items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final category = data.items[index];
                return AppCard(
                  onTap: () => _openForm(context, ref, category: category),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(category.name, style: Theme.of(context).textTheme.titleMedium),
                      if (category.description != null) Text(category.description!),
                      Text('${category.productCount ?? 0} produit(s) · ${category.isActive ? 'Active' : 'Inactive'}'),
                    ],
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(message: error.toString(), onRetry: () => ref.invalidate(categoriesProvider)),
      ),
    );
  }

  Future<void> _openForm(BuildContext context, WidgetRef ref, {Category? category}) async {
    final name = TextEditingController(text: category?.name ?? '');
    final description = TextEditingController(text: category?.description ?? '');
    var isActive = category?.isActive ?? true;
    final isAdmin = ref.read(isAdminProvider);
    var deleteRequested = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(category == null ? 'Nouvelle catégorie' : 'Modifier la catégorie'),
                  const SizedBox(height: 12),
                  TextField(controller: name, decoration: const InputDecoration(labelText: 'Nom')),
                  const SizedBox(height: 12),
                  TextField(controller: description, decoration: const InputDecoration(labelText: 'Description')),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active'),
                    value: isActive,
                    onChanged: (value) => setModalState(() => isActive = value),
                  ),
                  FilledButton(
                    onPressed: () async {
                      try {
                        final body = {
                          'name': name.text.trim(),
                          'description': description.text.trim().isEmpty ? null : description.text.trim(),
                          'isActive': isActive,
                        };
                        if (category == null) {
                          await ref.read(categoryServiceProvider).create(body);
                        } else {
                          await ref.read(categoryServiceProvider).update(category.id, body);
                        }
                        ref.invalidate(categoriesProvider);
                        if (context.mounted) Navigator.pop(context);
                      } on ApiException catch (error) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
                        }
                      }
                    },
                    child: const Text('Enregistrer'),
                  ),
                  // ADMIN only (enforced by the backend as well).
                  if (category != null && isAdmin) ...[
                    const SizedBox(height: AppSpacing.sm),
                    DangerButton(
                      label: 'Supprimer la catégorie',
                      icon: Icons.delete_outline,
                      onPressed: () {
                        deleteRequested = true;
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ],
              );
            },
          ),
        );
      },
    );

    if (deleteRequested && category != null && context.mounted) {
      await _deleteCategory(context, ref, category);
    }
  }
}

void _refreshCategories(WidgetRef ref) {
  ref.invalidate(categoriesProvider);
  ref.invalidate(productCategoriesProvider);
  ref.invalidate(stockCategoriesProvider);
  ref.invalidate(productsListProvider);
  ref.invalidate(stockListProvider);
}

/// Deletes an empty category, or proposes to reassign its products first.
Future<void> _deleteCategory(BuildContext context, WidgetRef ref, Category category) async {
  final messenger = ScaffoldMessenger.of(context);
  final count = category.productCount ?? 0;
  if (count > 0) {
    await _reassignThenDelete(context, ref, category, count);
    return;
  }

  final result = await showDangerActionDialog(
    context,
    title: 'Supprimer la catégorie ?',
    confirmLabel: 'Supprimer la catégorie',
    reasonRequired: false,
    suggestions: const ['Plus utilisée', 'Doublon', 'Erreur de saisie'],
    consequences: ['La catégorie « ${category.name} » ne contient aucun produit : elle sera définitivement supprimée.'],
  );
  if (result == null) return;

  try {
    await ref.read(categoryServiceProvider).delete(category.id, reason: result.reason);
    _refreshCategories(ref);
    messenger.showSnackBar(const SnackBar(content: Text('Catégorie supprimée')));
  } on ApiException catch (error) {
    // A product was added meanwhile: switch to the reassignment flow.
    if (error.code == 'CATEGORY_NOT_EMPTY' && context.mounted) {
      final productCount = (error.details.firstOrNull?['productCount'] as num?)?.toInt() ?? 1;
      await _reassignThenDelete(context, ref, category, productCount);
      return;
    }
    messenger.showSnackBar(SnackBar(content: Text(userFacingMessage(error))));
  }
}

Future<void> _reassignThenDelete(BuildContext context, WidgetRef ref, Category category, int count) async {
  final messenger = ScaffoldMessenger.of(context);
  final service = ref.read(categoryServiceProvider);
  List<Category> targets;
  try {
    final all = await service.list();
    targets = all.items.where((item) => item.id != category.id && item.isActive).toList();
  } catch (error) {
    messenger.showSnackBar(SnackBar(content: Text(userFacingMessage(error))));
    return;
  }
  if (!context.mounted) return;

  final choice = await showDialog<_ReassignChoice>(
    context: context,
    builder: (context) => _ReassignDialog(category: category, count: count, targets: targets),
  );
  if (choice == null) return;

  try {
    final moved = await service.reassign(category.id, choice.targetId, reason: choice.reason);
    await service.delete(category.id, reason: choice.reason);
    _refreshCategories(ref);
    messenger.showSnackBar(
      SnackBar(content: Text('$moved produit(s) réaffecté(s), catégorie « ${category.name} » supprimée')),
    );
  } catch (error) {
    _refreshCategories(ref);
    messenger.showSnackBar(SnackBar(content: Text(userFacingMessage(error))));
  }
}

class _ReassignChoice {
  const _ReassignChoice(this.targetId, this.reason);

  final String targetId;
  final String? reason;
}

class _ReassignDialog extends StatefulWidget {
  const _ReassignDialog({required this.category, required this.count, required this.targets});

  final Category category;
  final int count;
  final List<Category> targets;

  @override
  State<_ReassignDialog> createState() => _ReassignDialogState();
}

class _ReassignDialogState extends State<_ReassignDialog> {
  String? _targetId;
  final _reason = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final noTarget = widget.targets.isEmpty;

    return AlertDialog(
      title: const Text('Catégorie non vide'),
      scrollable: true,
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'La catégorie « ${widget.category.name} » contient ${widget.count} produit(s), archivés compris. '
              'Réaffectez-les à une autre catégorie pour pouvoir la supprimer.',
            ),
            const SizedBox(height: AppSpacing.md),
            if (noTarget)
              Text(
                'Aucune autre catégorie active : créez d’abord la catégorie de destination.',
                style: TextStyle(color: colors.danger, fontWeight: FontWeight.w600),
              )
            else ...[
              DropdownButtonFormField<String>(
                initialValue: _targetId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Nouvelle catégorie'),
                items: widget.targets
                    .map((target) => DropdownMenuItem(value: target.id, child: Text(target.name)))
                    .toList(),
                onChanged: (value) => setState(() => _targetId = value),
                validator: (value) => value == null ? 'Choisissez une catégorie' : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _reason,
                maxLength: 300,
                decoration: const InputDecoration(labelText: 'Motif (facultatif)'),
                validator: (value) => validateReason(value, required: false),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Retour')),
        if (!noTarget)
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colors.danger,
              foregroundColor: scheme.onError,
              minimumSize: const Size(0, AppSpacing.minTouch),
            ),
            onPressed: () {
              if (!_formKey.currentState!.validate()) return;
              final reason = _reason.text.trim();
              Navigator.pop(context, _ReassignChoice(_targetId!, reason.isEmpty ? null : reason));
            },
            child: const Text('Réaffecter et supprimer'),
          ),
      ],
    );
  }
}
