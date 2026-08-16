class PriceTick {
  final String symbol;
  final double price;
  final double previousClose;
  final double change;
  final double changePercent;
  final int timestamp;

  const PriceTick({
    required this.symbol,
    required this.price,
    required this.previousClose,
    required this.change,
    required this.changePercent,
    required this.timestamp,
  });

  factory PriceTick.fromJson(Map<String, dynamic> json) {
    return PriceTick(
      symbol: json['symbol'] as String,
      price: (json['price'] as num).toDouble(),
      previousClose: (json['previousClose'] as num).toDouble(),
      change: (json['change'] as num).toDouble(),
      changePercent: (json['changePercent'] as num).toDouble(),
      timestamp: json['timestamp'] as int,
    );
  }

  bool get isUp => change >= 0;
}
