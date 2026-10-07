import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:stock_management/core/theme/app_colors.dart';
import 'package:stock_management/core/theme/app_tokens.dart';
import 'package:stock_management/core/utils/formatters.dart';
import 'package:stock_management/core/utils/money.dart';
import 'package:stock_management/data/models/documents.dart';

/// True when at least one bucket has a sale or a purchase.
bool seriesHasActivity(List<DashboardPoint> points) => points.any(
      (point) => isPositiveMoney(point.saleAmount) || isPositiveMoney(point.purchaseAmount),
    );

/// Sales vs purchases over the period, from `series` of `/api/dashboard`.
/// Values are plotted as doubles; the tooltip shows the exact API amount.
class SalesPurchasesChart extends StatelessWidget {
  const SalesPurchasesChart({super.key, required this.points, required this.hourly});

  final List<DashboardPoint> points;
  final bool hourly;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final sales = <FlSpot>[];
    final purchases = <FlSpot>[];
    var maxY = 0.0;
    for (var i = 0; i < points.length; i++) {
      final sale = parseMoney(points[i].saleAmount).toDouble();
      final purchase = parseMoney(points[i].purchaseAmount).toDouble();
      sales.add(FlSpot(i.toDouble(), sale));
      purchases.add(FlSpot(i.toDouble(), purchase));
      if (sale > maxY) maxY = sale;
      if (purchase > maxY) maxY = purchase;
    }
    final top = maxY == 0 ? 1.0 : maxY * 1.15;
    final labelEvery = hourly ? 6 : (points.length <= 7 ? 1 : 7);
    final axisStyle = text.labelSmall?.copyWith(color: scheme.onSurfaceVariant);

    LineChartBarData line(List<FlSpot> spots, Color color) {
      return LineChartBarData(
        spots: spots,
        color: color,
        barWidth: 2.5,
        isCurved: false,
        dotData: FlDotData(show: points.length <= 7),
        belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.10)),
      );
    }

    return Semantics(
      label: 'Graphique des ventes et des achats sur la période',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xs, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.xs),
                child: Wrap(
                  spacing: AppSpacing.md,
                  children: [
                    _Legend(color: colors.sale, label: 'Ventes'),
                    _Legend(color: colors.purchase, label: 'Achats'),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              AspectRatio(
                aspectRatio: 1.7,
                child: LineChart(
                  LineChartData(
                    minX: 0,
                    maxX: (points.length - 1).toDouble().clamp(1, double.infinity),
                    minY: 0,
                    maxY: top,
                    lineBarsData: [line(sales, colors.sale), line(purchases, colors.purchase)],
                    gridData: FlGridData(
                      drawVerticalLine: false,
                      horizontalInterval: top / 4,
                      getDrawingHorizontalLine: (_) => FlLine(color: colors.cardBorder, strokeWidth: 1),
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 44,
                          interval: top / 4,
                          getTitlesWidget: (value, meta) {
                            if (value == meta.max) return const SizedBox.shrink();
                            return SideTitleWidget(
                              meta: meta,
                              child: Text(formatCompactAmount(value), style: axisStyle),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (value != index || index < 0 || index >= points.length) {
                              return const SizedBox.shrink();
                            }
                            final isLast = index == points.length - 1;
                            if (index % labelEvery != 0 && !(isLast && !hourly)) {
                              return const SizedBox.shrink();
                            }
                            final start = points[index].start;
                            return SideTitleWidget(
                              meta: meta,
                              child: Text(hourly ? formatHour(start) : formatShortDay(start), style: axisStyle),
                            );
                          },
                        ),
                      ),
                    ),
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (_) => scheme.inverseSurface,
                        fitInsideHorizontally: true,
                        fitInsideVertically: true,
                        getTooltipItems: (spots) => spots.map((spot) {
                          final point = points[spot.x.toInt()];
                          final isSale = spot.barIndex == 0;
                          final when = hourly ? formatHour(point.start) : formatShortDay(point.start);
                          final amount = formatAmount(isSale ? point.saleAmount : point.purchaseAmount);
                          return LineTooltipItem(
                            '${isSale ? '$when\n' : ''}${isSale ? 'Ventes' : 'Achats'} : $amount',
                            TextStyle(color: scheme.onInverseSurface, fontWeight: FontWeight.w700),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, borderRadius: AppRadius.pillAll),
        ),
        const SizedBox(width: AppSpacing.xxs),
        Text(label, style: Theme.of(context).textTheme.labelLarge),
      ],
    );
  }
}
