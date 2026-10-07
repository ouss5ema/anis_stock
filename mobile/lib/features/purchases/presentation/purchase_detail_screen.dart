import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:stock_management/core/network/api_exception.dart';
import 'package:stock_management/core/utils/money.dart';
import 'package:stock_management/core/utils/user_message.dart';
import 'package:stock_management/core/widgets/ui_kit.dart';
import 'package:stock_management/data/models/documents.dart';
import 'package:stock_management/core/data_refresh.dart';
import 'package:stock_management/data/services/service_providers.dart';

final purchaseDetailProvider = FutureProvider.family<Purchase, String>((ref, id) {
  return ref.watch(purchaseServiceProvider).getById(id);
});

class PurchaseDetailScreen extends ConsumerWidget {
  const PurchaseDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(purchaseDetailProvider(id));
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(title: const Text('Détail achat')),
      body: async.when(
        data: (purchase) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(purchase.referenceNumber, style: Theme.of(context).textTheme.headlineSmall),
            Text(purchase.supplier.name),
            Text(dateFormat.format(purchase.purchaseDate.toLocal())),
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
            if (purchase.status == 'CONFIRMED') ...[
              const SizedBox(height: 20),
              FilledButton.tonal(
                onPressed: () async {
                  final ok = await confirmAction(
                    context,
                    title: 'Annuler cet achat ?',
                    message: 'Le stock sera diminué et l’historique conservé.',
                    confirmLabel: 'Annuler l’achat',
                  );
                  if (!ok) return;
                  try {
                    await ref.read(purchaseServiceProvider).cancel(id, reason: 'Annulation depuis l’application');
                    ref.invalidate(purchaseDetailProvider(id));
                    invalidateOperationalData(ref);
                    if (context.mounted) context.pop();
                  } on ApiException catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(userFacingMessage(error))));
                    }
                  }
                },
                child: const Text('Annuler l’achat'),
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
