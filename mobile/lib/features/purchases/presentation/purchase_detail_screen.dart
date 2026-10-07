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

final purchaseDetailProvider = FutureProvider.family<Purchase, String>((ref, id) {
  return ref.watch(purchaseServiceProvider).getById(id);
});

class PurchaseDetailScreen extends ConsumerWidget {
  const PurchaseDetailScreen({super.key, required this.id});

  final String id;

  Future<void> _cancel(BuildContext context, WidgetRef ref, Purchase purchase) async {
    final service = ref.read(purchaseServiceProvider);
    final done = await runCancelFlow(
      context,
      title: 'Annuler l’achat ${purchase.referenceNumber} ?',
      confirmLabel: 'Annuler l’achat',
      documentLabel: 'L’achat ${purchase.referenceNumber}',
      loadPreview: () => service.cancelPreview(id),
      cancel: (reason) => service.cancel(id, reason: reason),
    );
    if (done) {
      ref.invalidate(purchaseDetailProvider(id));
      invalidateOperationalData(ref);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(purchaseDetailProvider(id));
    final isAdmin = ref.watch(isAdminProvider);
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(title: const Text('Détail achat')),
      body: async.when(
        data: (purchase) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, AppSpacing.xxl),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(purchase.referenceNumber, style: Theme.of(context).textTheme.headlineSmall),
                ),
                DocumentStatusChip(status: purchase.status),
              ],
            ),
            Text(purchase.supplier.name),
            Text(dateFormat.format(purchase.purchaseDate.toLocal())),
            if (purchase.isCancelled) ...[
              const SizedBox(height: 12),
              CancellationInfoCard(
                feminine: false,
                cancelledAt: purchase.cancelledAt,
                reason: purchase.cancelReason,
                byName: purchase.cancelledByName,
              ),
            ],
            const SizedBox(height: 12),
            ...purchase.items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  child: Text(
                    '${item.productName} · ${formatDt(item.quantity)} × ${formatDt(item.unitPrice)} = ${formatDtLabel(item.totalPrice)}',
                  ),
                ),
              ),
            ),
            Text('Total ${formatDtLabel(purchase.totalAmount)}', style: Theme.of(context).textTheme.titleLarge),
            // ADMIN only (enforced by the backend as well).
            if (isAdmin && !purchase.isCancelled) ...[
              const SizedBox(height: 24),
              DangerButton(
                label: 'Annuler l’achat',
                icon: Icons.block_rounded,
                onPressed: () => _cancel(context, ref, purchase),
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
