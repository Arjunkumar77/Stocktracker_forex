import 'package:flutter/material.dart';
import '../models/price_tick.dart';
import '../theme/app_theme.dart';
import 'live_chart.dart';

class PriceCard extends StatelessWidget {
  final String symbol;
  final String displayName;
  final PriceTick? tick;
  final List<double> history;
  final VoidCallback onTap;

  const PriceCard({
    super.key,
    required this.symbol,
    required this.displayName,
    required this.tick,
    required this.history,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isUp = (tick?.change ?? 0) >= 0;
    final color = isUp ? AppColors.bullish : AppColors.bearish;
    final decimals = symbol == 'XAUUSD' ? 2 : 5;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        symbol,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    displayName,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    tick != null ? tick!.price.toStringAsFixed(decimals) : '--',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tick != null
                        ? '${isUp ? '+' : ''}${tick!.changePercent.toStringAsFixed(2)}%'
                        : '--',
                    style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: SizedBox(
                height: 56,
                child: LiveChart(data: history, lineColor: color, compact: true),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
