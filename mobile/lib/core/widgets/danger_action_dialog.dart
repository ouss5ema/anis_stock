import 'package:flutter/material.dart';
import 'package:stock_management/core/theme/app_colors.dart';
import 'package:stock_management/core/theme/app_tokens.dart';

const quickReasons = ['Erreur de saisie', 'Retour client', 'Doublon'];

/// Result of a confirmed [showDangerActionDialog]: the typed reason
/// (null when the reason is optional and left empty).
class DangerActionResult {
  const DangerActionResult(this.reason);

  final String? reason;
}

/// Confirmation for an irreversible ADMIN action: concrete consequences,
/// reason field with quick reasons, explicit red button.
/// Returns null when the user cancels.
Future<DangerActionResult?> showDangerActionDialog(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  List<String> consequences = const [],
  String? warning,
  String? blockingMessage,
  bool reasonRequired = true,
  List<String> suggestions = quickReasons,
}) {
  return showDialog<DangerActionResult>(
    context: context,
    builder: (context) => _DangerActionDialog(
      title: title,
      confirmLabel: confirmLabel,
      consequences: consequences,
      warning: warning,
      blockingMessage: blockingMessage,
      reasonRequired: reasonRequired,
      suggestions: suggestions,
    ),
  );
}

/// Same rule as the backend: 3 to 300 characters.
String? validateReason(String? value, {required bool required}) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) {
    return required ? 'Le motif est obligatoire' : null;
  }
  if (text.length < 3) return 'Au moins 3 caractères';
  if (text.length > 300) return '300 caractères maximum';
  return null;
}

class _DangerActionDialog extends StatefulWidget {
  const _DangerActionDialog({
    required this.title,
    required this.confirmLabel,
    required this.consequences,
    required this.warning,
    required this.blockingMessage,
    required this.reasonRequired,
    required this.suggestions,
  });

  final String title;
  final String confirmLabel;
  final List<String> consequences;
  final String? warning;
  final String? blockingMessage;
  final bool reasonRequired;
  final List<String> suggestions;

  @override
  State<_DangerActionDialog> createState() => _DangerActionDialogState();
}

class _DangerActionDialogState extends State<_DangerActionDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    if (!_formKey.currentState!.validate()) return;
    final text = _controller.text.trim();
    Navigator.pop(context, DangerActionResult(text.isEmpty ? null : text));
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final blocked = widget.blockingMessage != null;

    return AlertDialog(
      title: Text(widget.title),
      scrollable: true,
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (blocked)
              _Notice(
                icon: Icons.block_rounded,
                message: widget.blockingMessage!,
                color: colors.danger,
                container: colors.dangerContainer,
              ),
            if (widget.consequences.isNotEmpty) ...[
              Text('Conséquences', style: text.labelLarge),
              const SizedBox(height: AppSpacing.xxs),
              for (final line in widget.consequences)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(Icons.arrow_right_rounded, color: scheme.onSurfaceVariant),
                      ),
                      Expanded(child: Text(line)),
                    ],
                  ),
                ),
            ],
            if (widget.warning != null) ...[
              const SizedBox(height: AppSpacing.xs),
              _Notice(
                icon: Icons.warning_amber_rounded,
                message: widget.warning!,
                color: colors.warning,
                container: colors.warningContainer,
              ),
            ],
            if (!blocked) ...[
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final suggestion in widget.suggestions)
                    ActionChip(
                      label: Text(suggestion),
                      onPressed: () => setState(() => _controller.text = suggestion),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _controller,
                maxLength: 300,
                minLines: 1,
                maxLines: 3,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: widget.reasonRequired ? 'Motif (obligatoire)' : 'Motif (facultatif)',
                ),
                validator: (value) => validateReason(value, required: widget.reasonRequired),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(blocked ? 'Fermer' : 'Retour'),
        ),
        if (!blocked)
          FilledButton(
            onPressed: _confirm,
            style: FilledButton.styleFrom(
              backgroundColor: colors.danger,
              foregroundColor: scheme.onError,
              minimumSize: const Size(0, AppSpacing.minTouch),
            ),
            child: Text(widget.confirmLabel),
          ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.message, required this.color, required this.container});

  final IconData icon;
  final String message;
  final Color color;
  final Color container;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(color: container, borderRadius: AppRadius.mdAll),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(message, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
