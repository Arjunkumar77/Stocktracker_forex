import 'dart:async';
import 'package:flutter/material.dart';
import '../models/price_tick.dart';
import '../services/price_service.dart';
import '../theme/app_theme.dart';
import '../widgets/price_card.dart';
import 'detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PriceService _service = PriceService();
  final Map<String, PriceTick> _ticks = {};
  final Map<String, List<double>> _history = {'XAUUSD': [], 'GBPUSD': []};
  late final StreamSubscription<PriceTick> _sub;

  static const _instruments = [
    {'symbol': 'XAUUSD', 'name': 'Gold / US Dollar'},
    {'symbol': 'GBPUSD', 'name': 'British Pound / US Dollar'},
  ];

  @override
  void initState() {
    super.initState();
    _sub = _service.ticks.listen(_onTick);
    _service.fetchInitialSnapshot();
    _service.connect();
  }

  void _onTick(PriceTick tick) {
    if (!mounted) return;
    setState(() {
      _ticks[tick.symbol] = tick;
      final list = _history.putIfAbsent(tick.symbol, () => []);
      list.add(tick.price);
      if (list.length > 60) list.removeAt(0);
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Markets', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Row(
              children: [
                _LiveDot(),
                SizedBox(width: 6),
                Text('Live', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _instruments.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final instrument = _instruments[index];
          final symbol = instrument['symbol']!;

          return PriceCard(
            symbol: symbol,
            displayName: instrument['name']!,
            tick: _ticks[symbol],
            history: _history[symbol] ?? const [],
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DetailScreen(
                    symbol: symbol,
                    displayName: instrument['name']!,
                    service: _service,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _LiveDot extends StatefulWidget {
  const _LiveDot();

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.4, end: 1.0).animate(_controller),
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(color: AppColors.bullish, shape: BoxShape.circle),
      ),
    );
  }
}
