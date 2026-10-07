import 'package:flutter/material.dart';
import 'package:stock_management/core/theme/app_colors.dart';
import 'package:stock_management/core/theme/app_tokens.dart';
import 'package:stock_management/core/utils/formatters.dart';

/// How a variation should be colored: for sales a rise is good news, for
/// purchases it is only information.
enum VariationTone { positiveIsGood, neutral }

class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.containerColor,
    this.variation,
    this.variationTone = VariationTone.neutral,
    this.comparisonLabel,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final String subtitle;
  final Color color;
  final Color containerColor;
  final Variation? variation;
  final VariationTone variationTone;
  final String? comparisonLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final semanticsVariation = variation == null
        ? ''
        : ', ${variation!.label}${comparisonLabel != null ? ' $comparisonLabel' : ''}';

    return Semantics(
      button: onTap != null,
      label: '$label : $value, $subtitle$semanticsVariation',
      excludeSemantics: true,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSpacing.minTouch),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.xs),
                        decoration: BoxDecoration(
                          color: containerColor,
                          borderRadius: AppRadius.smAll,
                        ),
                        child: Icon(icon, size: 20, color: color),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 2,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontSize: AppTextSize.kpiLabel,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // Scales down instead of truncating large amounts.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      maxLines: 1,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontSize: AppTextSize.kpiValue,
                        color: scheme.onSurface,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  if (variation != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    VariationBadge(
                      variation: variation!,
                      tone: variationTone,
                      comparisonLabel: comparisonLabel,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class VariationBadge extends StatelessWidget {
  const VariationBadge({
    super.key,
    required this.variation,
    required this.tone,
    this.comparisonLabel,
  });

  final Variation variation;
  final VariationTone tone;
  final String? comparisonLabel;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;

    final Color color;
    if (tone == VariationTone.neutral || variation.direction == VariationDirection.flat) {
      color = colors.neutral;
    } else if (variation.direction == VariationDirection.up) {
      color = colors.success;
    } else {
      color = colors.danger;
    }

    final icon = switch (variation.direction) {
      _ when variation.isNew => Icons.fiber_new_outlined,
      VariationDirection.up => Icons.arrow_upward_rounded,
      VariationDirection.down => Icons.arrow_downward_rounded,
      VariationDirection.flat => Icons.arrow_forward_rounded,
    };

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.xxs,
      children: [
        Icon(icon, size: 16, color: color),
        Text(
          variation.label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: AppTextSize.caption,
          ),
        ),
        if (comparisonLabel != null)
          Text(
            comparisonLabel!,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: AppTextSize.caption),
          ),
      ],
    );
  }
}
