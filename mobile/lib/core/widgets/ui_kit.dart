import 'dart:async';

import 'package:flutter/material.dart';
import 'package:stock_management/core/theme/app_colors.dart';
import 'package:stock_management/core/theme/app_tokens.dart';
import 'package:stock_management/core/utils/user_message.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final card = Card(
      child: Padding(padding: padding, child: child),
    );

    if (onTap == null) {
      return card;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: card,
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: colors.outline),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(userFacingMessage(message), textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              FilledButton(onPressed: onRetry, child: const Text('Réessayer')),
            ],
          ],
        ),
      ),
    );
  }
}

class SearchField extends StatefulWidget {
  const SearchField({
    super.key,
    required this.hint,
    required this.onChanged,
    this.debounce = const Duration(milliseconds: 300),
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final Duration debounce;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: (value) {
        _timer?.cancel();
        _timer = Timer(widget.debounce, () => widget.onChanged(value));
      },
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon: const Icon(Icons.search),
      ),
    );
  }
}

/// Uniform status pill (stock faible, rupture, annulé...).
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.color,
    this.containerColor,
  });

  final String label;
  final Color color;
  final Color? containerColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: AppSpacing.xxs),
      decoration: BoxDecoration(
        color: containerColor ?? color.withValues(alpha: 0.12),
        borderRadius: AppRadius.pillAll,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: AppTextSize.badge,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class StockStatusChip extends StatelessWidget {
  const StockStatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    switch (status) {
      case 'OUT':
        return StatusChip(label: 'Rupture', color: colors.danger, containerColor: colors.dangerContainer);
      case 'LOW':
        return StatusChip(label: 'Stock faible', color: colors.warning, containerColor: colors.warningContainer);
      default:
        return StatusChip(label: 'Normal', color: colors.success, containerColor: colors.successContainer);
    }
  }
}

/// "Archivé" badge for archived products.
class ArchivedChip extends StatelessWidget {
  const ArchivedChip({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return StatusChip(label: 'Archivé', color: colors.neutral, containerColor: colors.neutralContainer);
  }
}

/// Confirmed / cancelled badge for purchases (masculine) and sales (feminine).
class DocumentStatusChip extends StatelessWidget {
  const DocumentStatusChip({super.key, required this.status, this.feminine = false});

  final String status;
  final bool feminine;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final suffix = feminine ? 'e' : '';
    if (status == 'CANCELLED') {
      return StatusChip(label: 'Annulé$suffix', color: colors.neutral, containerColor: colors.neutralContainer);
    }
    return StatusChip(label: 'Confirmé$suffix', color: colors.success, containerColor: colors.successContainer);
  }
}

class FilterChoice extends StatelessWidget {
  const FilterChoice({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
      ),
    );
  }
}

class ActiveFiltersBar extends StatelessWidget {
  const ActiveFiltersBar({
    super.key,
    required this.labels,
    required this.onReset,
  });

  final List<String> labels;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: labels
                  .map(
                    (label) => Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(label, style: const TextStyle(fontSize: 12)),
                    ),
                  )
                  .toList(),
            ),
          ),
          TextButton(onPressed: onReset, child: const Text('Réinitialiser')),
        ],
      ),
    );
  }
}

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirmer',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(confirmLabel)),
      ],
    ),
  );
  return result ?? false;
}

