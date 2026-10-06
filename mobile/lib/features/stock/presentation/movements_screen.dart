import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stock_management/core/utils/dates.dart';
import 'package:stock_management/core/utils/labels.dart';
import 'package:stock_management/core/utils/money.dart';
import 'package:stock_management/core/utils/user_message.dart';
import 'package:stock_management/core/widgets/ui_kit.dart';
import 'package:stock_management/data/models/documents.dart';
import 'package:stock_management/data/models/paginated_result.dart';
import 'package:stock_management/data/services/service_providers.dart';

class _MovementQuery {
  const _MovementQuery({this.productId, this.type});

  final String? productId;
  final String? type;

  @override
  bool operator ==(Object other) =>
      other is _MovementQuery && other.productId == productId && other.type == type;

  @override
  int get hashCode => Object.hash(productId, type);
}

final movementsProvider = FutureProvider.family<PaginatedResult<StockMovement>, _MovementQuery>((ref, query) {
  return ref.watch(stockOpsServiceProvider).movements(productId: query.productId, type: query.type);
});

class MovementsScreen extends ConsumerStatefulWidget {
  const MovementsScreen({super.key, this.productId});

  final String? productId;

  @override
  ConsumerState<MovementsScreen> createState() => _MovementsScreenState();
}

class _MovementsScreenState extends ConsumerState<MovementsScreen> {
  String? _type;

  void _openSource(StockMovement movement) {
    if (movement.referenceId == null) return;
    if (movement.referenceType == 'PURCHASE' || movement.type == 'PURCHASE' || movement.type == 'RETURN_PURCHASE') {
      context.push('/purchases/${movement.referenceId}');
      return;
    }
    if (movement.referenceType == 'SALE' || movement.type == 'SALE' || movement.type == 'RETURN_SALE') {
      context.push('/sales/${movement.referenceId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _MovementQuery(productId: widget.productId, type: _type);
    final async = ref.watch(movementsProvider(query));

    return Scaffold(
      appBar: AppBar(title: const Text('Mouvements de stock')),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                ChoiceChip(label: const Text('Tous'), selected: _type == null, onSelected: (_) => setState(() => _type = null)),
                const SizedBox(width: 8),
                ChoiceChip(label: const Text('Achats'), selected: _type == 'PURCHASE', onSelected: (_) => setState(() => _type = 'PURCHASE')),
                const SizedBox(width: 8),
                ChoiceChip(label: const Text('Ventes'), selected: _type == 'SALE', onSelected: (_) => setState(() => _type = 'SALE')),
                const SizedBox(width: 8),
                ChoiceChip(label: const Text('Ajustements'), selected: _type == 'ADJUSTMENT_OUT', onSelected: (_) => setState(() => _type = 'ADJUSTMENT_OUT')),
              ],
            ),
          ),
          Expanded(
            child: async.when(
              data: (data) {
                if (data.items.isEmpty) {
                  return const EmptyState(
                    icon: Icons.history,
                    title: 'Aucun mouvement',
                    subtitle: 'Les changements de stock apparaîtront ici.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(movementsProvider(query)),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: data.items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final movement = data.items[index];
                      return AppCard(
                        onTap: movement.referenceId == null ? null : () => _openSource(movement),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(movement.productName ?? 'Produit', style: Theme.of(context).textTheme.titleMedium),
                            Text('${formatDateTime(movement.createdAt)} · ${movementTypeLabel(movement.type)}'),
                            Text('${movement.signedQuantity}  ·  ${formatDt(movement.previousStock)} → ${formatDt(movement.newStock)}'),
                            if (movement.reason != null) Text(movement.reason!),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => ErrorView(message: userFacingMessage(error)),
            ),
          ),
        ],
      ),
    );
  }
}
