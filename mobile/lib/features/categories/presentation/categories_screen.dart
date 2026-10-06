import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_management/core/network/api_exception.dart';
import 'package:stock_management/core/widgets/ui_kit.dart';
import 'package:stock_management/data/models/category.dart';
import 'package:stock_management/data/models/paginated_result.dart';
import 'package:stock_management/data/services/service_providers.dart';

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
                ],
              );
            },
          ),
        );
      },
    );
  }
}
