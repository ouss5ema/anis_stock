import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:stock_management/core/network/api_exception.dart';
import 'package:stock_management/core/theme/app_colors.dart';
import 'package:stock_management/core/theme/app_tokens.dart';
import 'package:stock_management/core/utils/formatters.dart';
import 'package:stock_management/core/utils/labels.dart';
import 'package:stock_management/core/utils/user_message.dart';
import 'package:stock_management/core/widgets/danger_action_dialog.dart';
import 'package:stock_management/data/models/documents.dart';

final _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');

/// "Le stock de Marlboro Rouge passera de 8 à 11" for each product.
List<String> stockConsequences(CancelPreview preview) {
  return preview.lines.map((line) {
    final unit = line.unit == null ? '' : ' ${unitLabel(line.unit!)}';
    return 'Le stock de ${line.productName} passera de ${formatQuantity(line.stockBefore)} '
        'à ${formatQuantity(line.stockAfter)}$unit';
  }).toList();
}

/// Loads the preview, asks for confirmation and a reason, then cancels.
/// Returns true when the document was cancelled. Errors are shown in a
/// SnackBar (the backend transaction remains authoritative).
Future<bool> runCancelFlow(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  required String documentLabel,
  required Future<CancelPreview> Function() loadPreview,
  required Future<void> Function(String reason) cancel,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  void showError(Object error) {
    messenger.showSnackBar(SnackBar(content: Text(userFacingMessage(error))));
  }

  CancelPreview preview;
  try {
    preview = await loadPreview();
  } catch (error) {
    showError(error);
    return false;
  }
  if (!context.mounted) return false;

  final result = await showDangerActionDialog(
    context,
    title: title,
    confirmLabel: confirmLabel,
    blockingMessage: preview.canCancel ? null : preview.blockingReason,
    consequences: [
      ...stockConsequences(preview),
      '$documentLabel sera marqué(e) « Annulé(e) » et exclu(e) du tableau de bord et des statistiques.',
      'L’historique et les mouvements de stock sont conservés.',
    ],
  );
  if (result == null) return false;

  try {
    await cancel(result.reason!);
    messenger.showSnackBar(SnackBar(content: Text('$documentLabel annulé(e)')));
    return true;
  } on ApiException catch (error) {
    // e.g. stock changed since the preview: the message gives the real stock.
    showError(error);
    return false;
  } catch (error) {
    showError(error);
    return false;
  }
}

/// Reason, author and date of a cancelled sale or purchase.
class CancellationInfoCard extends StatelessWidget {
  const CancellationInfoCard({
    super.key,
    required this.feminine,
    this.cancelledAt,
    this.reason,
    this.byName,
  });

  final bool feminine;
  final DateTime? cancelledAt;
  final String? reason;
  final String? byName;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final details = [
      if (cancelledAt != null) 'Le ${_dateTimeFormat.format(cancelledAt!.toLocal())}',
      if (byName != null) 'par $byName',
    ].join(' ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: colors.neutralContainer, borderRadius: AppRadius.mdAll),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.block_rounded, color: colors.neutral, size: 20),
              const SizedBox(width: AppSpacing.xs),
              Text(
                feminine ? 'Vente annulée' : 'Achat annulé',
                style: text.titleMedium?.copyWith(color: colors.neutral),
              ),
            ],
          ),
          if (reason != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text('Motif : $reason', style: TextStyle(color: colors.neutral)),
          ],
          if (details.isNotEmpty)
            Text(details, style: text.bodySmall?.copyWith(color: colors.neutral)),
        ],
      ),
    );
  }
}

/// Red outlined button for destructive ADMIN actions.
class DangerButton extends StatelessWidget {
  const DangerButton({super.key, required this.label, required this.icon, required this.onPressed});

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.danger,
        side: BorderSide(color: colors.danger),
        minimumSize: const Size.fromHeight(AppSpacing.minTouch),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      ),
    );
  }
}
