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

class MovementQuery {
  const MovementQuery({this.productId, this.type, this.period = 'all'});

  final String? productId;
  final String? type;
  final String period;

  @override
  bool operator ==(Object other) =>
      other is MovementQuery && other.productId == productId && other.type == type && other.period == period;

  @override
  int get hashCode => Object.hash(productId, type, period);
}

final movementsProvider = FutureProvider.family<PaginatedResult<StockMovement>, MovementQuery>((ref, query) {
  final dates = query.period == 'all' ? null : periodQuery(query.period);
  return ref.watch(stockOpsServiceProvider).movements(
        productId: query.productId,
        type: query.type,
        from: dates?['from'],
        to: dates?['to'],
      );
});

class MovementsScreen extends ConsumerStatefulWidget {
  const MovementsScreen({super.key, this.productId});

  final String? productId;

  @override
  ConsumerState<MovementsScreen> createState() => _MovementsScreenState();
}

class _MovementsScreenState extends ConsumerState<MovementsScreen> {
  String? _type;
  String _period = 'all';

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

  void _reset() {
    setState(() {
      _type = null;
      _period = 'all';
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = MovementQuery(productId: widget.productId, type: _type, period: _period);
    final async = ref.watch(movementsProvider(query));
    final active = [
      if (widget.productId != null) 'Produit sélectionné',
      if (_type == 'PURCHASE') 'Type : achats',
      if (_type == 'SALE') 'Type : ventes',
      if (_type == 'ADJUSTMENT') 'Type : ajustements',
      if (_period == 'today') 'Période : aujourd’hui',
      if (_period == '7d') 'Période : 7 jours',
      if (_period == '30d') 'Période : 30 jours',
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Mouvements de stock')),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                FilterChoice(label: 'Tous', selected: _type == null, onSelected: () => setState(() => _type = null)),
                FilterChoice(label: 'Achats', selected: _type == 'PURCHASE', onSelected: () => setState(() => _type = 'PURCHASE')),
                FilterChoice(label: 'Ventes', selected: _type == 'SALE', onSelected: () => setState(() => _type = 'SALE')),
                FilterChoice(
                  label: 'Ajustements',
                  selected: _type == 'ADJUSTMENT',
                  onSelected: () => setState(() => _type = 'ADJUSTMENT'),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                FilterChoice(label: 'Toutes dates', selected: _period == 'all', onSelected: () => setState(() => _period = 'all')),
                FilterChoice(label: 'Aujourd’hui', selected: _period == 'today', onSelected: () => setState(() => _period = 'today')),
                FilterChoice(label: '7 jours', selected: _period == '7d', onSelected: () => setState(() => _period = '7d')),
                FilterChoice(label: '30 jours', selected: _period == '30d', onSelected: () => setState(() => _period = '30d')),
              ],
            ),
          ),
          ActiveFiltersBar(labels: active, onReset: _reset),
          Expanded(
            child: async.when(
              data: (data) {
                if (data.items.isEmpty) {
                  return const EmptyState(
                    icon: Icons.history,
                    title: 'Aucun mouvement trouvé',
                    subtitle: 'Essayez de modifier vos filtres.',
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
