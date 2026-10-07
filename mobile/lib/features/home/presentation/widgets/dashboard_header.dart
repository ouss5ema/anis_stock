import 'package:flutter/material.dart';
import 'package:stock_management/core/theme/app_colors.dart';
import 'package:stock_management/core/theme/app_tokens.dart';
import 'package:stock_management/core/utils/formatters.dart';
import 'package:stock_management/core/utils/labels.dart';
import 'package:stock_management/features/home/presentation/widgets/period_selector.dart';

/// Brand gradient header: greeting, date and role, with the period selector
/// pinned at the top while the dashboard scrolls.
class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    super.key,
    required this.userName,
    required this.role,
    required this.period,
    required this.onPeriodChanged,
    this.now,
  });

  final String? userName;
  final String? role;
  final String period;
  final ValueChanged<String> onPeriodChanged;
  final DateTime? now;

  static const _selectorBand = AppSpacing.minTouch + AppSpacing.md;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final textScaler = MediaQuery.textScalerOf(context);
    final greetingHeight = textScaler.scale(112).clamp(112, 180).toDouble();

    return SliverAppBar(
      pinned: true,
      automaticallyImplyLeading: false,
      backgroundColor: colors.brandDeep,
      foregroundColor: colors.onHeader,
      toolbarHeight: 0,
      expandedHeight: greetingHeight + _selectorBand,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final topInset = MediaQuery.paddingOf(context).top;
          final available = constraints.maxHeight - topInset - _selectorBand;
          final opacity = (available / greetingHeight).clamp(0.0, 1.0);
          return DecoratedBox(
            decoration: BoxDecoration(gradient: colors.headerGradient(scheme)),
            child: Stack(
              children: [
                // Subtle cyan glow taken from the logo (decorative only).
                Positioned(
                  right: -60,
                  top: -40,
                  child: IgnorePointer(
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            colors.accent.withValues(alpha: 0.35),
                            colors.accent.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: AppSpacing.page,
                  right: AppSpacing.page,
                  top: topInset + AppSpacing.sm,
                  child: Opacity(
                    opacity: opacity,
                    child: _Greeting(userName: userName, role: role, now: now ?? DateTime.now()),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(_selectorBand),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            0,
            AppSpacing.page,
            AppSpacing.md,
          ),
          child: PeriodSelector(value: period, onChanged: onPeriodChanged),
        ),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.userName, required this.role, required this.now});

  final String? userName;
  final String? role;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    final date = formatLongDate(now);
    final capitalizedDate = '${date[0].toUpperCase()}${date.substring(1)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          capitalizedDate,
          style: text.bodyMedium?.copyWith(color: colors.onHeaderMuted, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          userName == null || userName!.isEmpty ? 'Bonjour' : 'Bonjour, $userName',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.headlineSmall?.copyWith(
            color: colors.onHeader,
            fontSize: AppTextSize.greeting,
          ),
        ),
        if (role != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
            decoration: BoxDecoration(
              color: colors.onHeader.withValues(alpha: 0.16),
              borderRadius: AppRadius.pillAll,
            ),
            child: Text(
              roleLabel(role),
              style: text.labelMedium?.copyWith(color: colors.onHeader, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ],
    );
  }
}
