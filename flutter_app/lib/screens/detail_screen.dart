import 'dart:async';
import 'package:flutter/material.dart';
import '../models/price_tick.dart';
import '../services/price_service.dart';
import '../theme/app_theme.dart';
import '../widgets/live_chart.dart';

class DetailScreen extends StatefulWidget {
  final String symbol;
  final String displayName;
  final PriceService service;

  const DetailScreen({
    super.key,
    required this.symbol,
    required this.displayName,
    required this.service,
  });

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late final StreamSubscription<PriceTick> _sub;
  PriceTick? _tick;
  final List<double> _history = [];

  @override
  void initState() {
    super.initState();
    _tick = widget.service.latestPrices[widget.symbol];
    if (_tick != null) _history.add(_tick!.price);

    _sub = widget.service.ticks.listen((tick) {
      if (tick.symbol != widget.symbol || !mounted) return;
      setState(() {
        _tick = tick;
        _history.add(tick.price);
        if (_history.length > 150) _history.removeAt(0);
      });
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUp = (_tick?.change ?? 0) >= 0;
    final color = isUp ? AppColors.bullish : AppColors.bearish;
    final decimals = widget.symbol == 'XAUUSD' ? 2 : 5;

    final high = _history.isEmpty ? null : _history.reduce((a, b) => a > b ? a : b);
    final low = _history.isEmpty ? null : _history.reduce((a, b) => a < b ? a : b);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.symbol, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(widget.displayName,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _tick != null ? _tick!.price.toStringAsFixed(decimals) : '--',
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _tick != null
                  ? '${isUp ? '+' : ''}${_tick!.change.toStringAsFixed(decimals)} '
                    '(${isUp ? '+' : ''}${_tick!.changePercent.toStringAsFixed(2)}%)'
                  : '--',
              style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Container(
                padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: LiveChart(data: _history, lineColor: color),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatTile(label: 'Session High', value: high?.toStringAsFixed(decimals) ?? '--'),
                _StatTile(label: 'Session Low', value: low?.toStringAsFixed(decimals) ?? '--'),
                _StatTile(
                    label: 'Session Open',
                    value: _tick?.previousClose.toStringAsFixed(decimals) ?? '--'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;

  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
      ],
    );
  }
}
