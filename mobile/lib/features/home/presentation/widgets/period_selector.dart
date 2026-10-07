import 'package:flutter/material.dart';
import 'package:stock_management/core/theme/app_colors.dart';
import 'package:stock_management/core/theme/app_tokens.dart';

const dashboardPeriods = {
  'today': 'Aujourd’hui',
  '7d': '7 jours',
  '30d': '30 jours',
};

/// Period switcher shown on the brand header (white track, selected segment
/// in brand blue).
class PeriodSelector extends StatelessWidget {
  const PeriodSelector({super.key, required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = AppColors.of(context);
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<String>(
        showSelectedIcon: false,
        segments: dashboardPeriods.entries
            .map(
              (entry) => ButtonSegment<String>(
                value: entry.key,
                // Shrinks on very narrow screens instead of overflowing.
                label: FittedBox(fit: BoxFit.scaleDown, child: Text(entry.value, maxLines: 1)),
              ),
            )
            .toList(),
        selected: {value},
        onSelectionChanged: (selection) => onChanged(selection.first),
        style: SegmentedButton.styleFrom(
          backgroundColor: scheme.surface,
          foregroundColor: scheme.onSurface,
          selectedBackgroundColor: scheme.primary,
          selectedForegroundColor: scheme.onPrimary,
          side: BorderSide(color: colors.onHeader.withValues(alpha: 0.35)),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
          minimumSize: const Size(0, AppSpacing.minTouch),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          visualDensity: VisualDensity.standard,
        ),
      ),
    );
  }
}
