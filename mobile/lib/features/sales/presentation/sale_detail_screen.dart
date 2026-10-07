import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:stock_management/core/theme/app_tokens.dart';
import 'package:stock_management/core/utils/money.dart';
import 'package:stock_management/core/utils/user_message.dart';
import 'package:stock_management/core/widgets/document_admin.dart';
import 'package:stock_management/core/widgets/ui_kit.dart';
import 'package:stock_management/data/models/documents.dart';
import 'package:stock_management/core/data_refresh.dart';
import 'package:stock_management/data/services/service_providers.dart';
import 'package:stock_management/features/auth/providers/auth_provider.dart';

final saleDetailProvider = FutureProvider.family<Sale, String>((ref, id) {
  return ref.watch(saleServiceProvider).getById(id);
});

class SaleDetailScreen extends ConsumerWidget {
  const SaleDetailScreen({super.key, required this.id});

  final String id;

  Future<void> _cancel(BuildContext context, WidgetRef ref, Sale sale) async {
    final service = ref.read(saleServiceProvider);
    final done = await runCancelFlow(
      context,
      title: 'Annuler la vente ${sale.referenceNumber} ?',
      confirmLabel: 'Annuler la vente',
      documentLabel: 'La vente ${sale.referenceNumber}',
      loadPreview: () => service.cancelPreview(id),
      cancel: (reason) => service.cancel(id, reason: reason),
    );
    if (done) {
      ref.invalidate(saleDetailProvider(id));
      invalidateOperationalData(ref);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(saleDetailProvider(id));
    final isAdmin = ref.watch(isAdminProvider);
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(title: const Text('Détail vente')),
      body: async.when(
        data: (sale) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, AppSpacing.xxl),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(sale.referenceNumber, style: Theme.of(context).textTheme.headlineSmall),
                ),
                DocumentStatusChip(status: sale.status, feminine: true),
              ],
            ),
            Text(sale.customer.name),
            Text(dateFormat.format(sale.saleDate.toLocal())),
            if (sale.isCancelled) ...[
              const SizedBox(height: 12),
              CancellationInfoCard(
                feminine: true,
                cancelledAt: sale.cancelledAt,
                reason: sale.cancelReason,
                byName: sale.cancelledByName,
              ),
            ],
            const SizedBox(height: 12),
            ...sale.items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  child: Text(
                    '${item.productName} · ${formatDt(item.quantity)} × ${formatDt(item.unitPrice)} = ${formatDtLabel(item.totalPrice)}',
                  ),
                ),
              ),
            ),
            Text('Total ${formatDtLabel(sale.totalAmount)}', style: Theme.of(context).textTheme.titleLarge),
            // ADMIN only (enforced by the backend as well).
            if (isAdmin && !sale.isCancelled) ...[
              const SizedBox(height: 24),
              DangerButton(
                label: 'Annuler la vente',
                icon: Icons.block_rounded,
                onPressed: () => _cancel(context, ref, sale),
              ),
            ],
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(message: userFacingMessage(error)),
      ),
    );
  }
}
