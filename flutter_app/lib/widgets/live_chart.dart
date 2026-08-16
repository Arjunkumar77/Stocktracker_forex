import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A live-updating line chart with a gradient fill under the line,
/// TradingView-style. Used both as a tiny sparkline inside price cards
/// (compact: true) and as the big chart on the detail screen.
class LiveChart extends StatelessWidget {
  final List<double> data;
  final Color lineColor;
  final bool compact;

  const LiveChart({
    super.key,
    required this.data,
    required this.lineColor,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (data.length < 2) {
      return const Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textSecondary),
        ),
      );
    }

    final spots = <FlSpot>[
      for (int i = 0; i < data.length; i++) FlSpot(i.toDouble(), data[i]),
    ];

    final minY = data.reduce((a, b) => a < b ? a : b);
    final maxY = data.reduce((a, b) => a > b ? a : b);
    final span = maxY - minY;
    final padding = span == 0 ? (maxY == 0 ? 1.0 : maxY * 0.001) : span * 0.15;

    return LineChart(
      LineChartData(
        minY: minY - padding,
        maxY: maxY + padding,
        gridData: FlGridData(
          show: !compact,
          drawVerticalLine: false,
          horizontalInterval: ((span + padding * 2) / 4).clamp(0.0001, double.infinity),
          getDrawingHorizontalLine: (value) =>
              const FlLine(color: AppColors.border, strokeWidth: 0.5),
        ),
        titlesData: FlTitlesData(
          show: !compact,
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: !compact,
              reservedSize: 54,
              getTitlesWidget: (value, meta) => Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  value.toStringAsFixed(2),
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
                ),
              ),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          enabled: !compact,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.surface,
            getTooltipItems: (spots) => spots
                .map((s) => LineTooltipItem(
                      s.y.toStringAsFixed(4),
                      const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                    ))
                .toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.2,
            color: lineColor,
            barWidth: compact ? 1.5 : 2.2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [lineColor.withValues(alpha: 0.25), lineColor.withValues(alpha: 0.0)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
      duration: Duration.zero, // instant redraw on every tick, no lag
    );
  }
}
