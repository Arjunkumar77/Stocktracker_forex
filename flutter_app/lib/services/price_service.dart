import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/price_tick.dart';

/// Talks to the .NET GoldForexApi backend:
///  - fetchInitialSnapshot() does one REST call for an immediate first price
///  - connect() opens the live websocket feed and keeps it alive,
///    reconnecting automatically if it drops.
class PriceService {
  // ---------------------------------------------------------------------
  // IMPORTANT — set this to match where your .NET API is actually running:
  //   * Android emulator  -> keep '10.0.2.2' (the emulator's alias for
  //                          "localhost" on your development machine)
  //   * Physical phone    -> use your computer's LAN IP, e.g. '192.168.1.42'
  //                          (both devices must be on the same wifi network)
  // The port must match Properties/launchSettings.json on the API (5000).
  // ---------------------------------------------------------------------
  static const String host = '10.0.2.2';
  static const int port = 5000;

  final _controller = StreamController<PriceTick>.broadcast();

  /// Every price tick, from either the initial REST snapshot or the
  /// live websocket, comes through this single stream.
  Stream<PriceTick> get ticks => _controller.stream;

  /// Latest known price per symbol, updated as ticks arrive.
  final Map<String, PriceTick> latestPrices = {};

  WebSocketChannel? _channel;
  StreamSubscription? _channelSub;
  Timer? _reconnectTimer;
  bool _disposed = false;

  Future<void> fetchInitialSnapshot() async {
    try {
      final uri = Uri.parse('http://$host:$port/api/prices');
      final response = await http.get(uri).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        for (final item in data) {
          _emit(PriceTick.fromJson(item as Map<String, dynamic>));
        }
      }
    } catch (_) {
      // Non-fatal — the websocket will populate prices once it connects.
    }
  }

  void connect() {
    if (_disposed) return;

    final uri = Uri.parse('ws://$host:$port/ws/prices');

    try {
      _channel = WebSocketChannel.connect(uri);
      _channelSub = _channel!.stream.listen(
        _handleMessage,
        onError: (_) => _scheduleReconnect(),
        onDone: _scheduleReconnect,
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _handleMessage(dynamic raw) {
    final decoded = jsonDecode(raw as String) as Map<String, dynamic>;
    final type = decoded['type'] as String?;

    if (type == 'tick') {
      _emit(PriceTick.fromJson(decoded['data'] as Map<String, dynamic>));
    } else if (type == 'snapshot') {
      final data = decoded['data'] as List<dynamic>;
      for (final item in data) {
        _emit(PriceTick.fromJson(item as Map<String, dynamic>));
      }
    }
  }

  void _emit(PriceTick tick) {
    latestPrices[tick.symbol] = tick;
    if (!_controller.isClosed) {
      _controller.add(tick);
    }
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), connect);
  }

  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _channelSub?.cancel();
    _channel?.sink.close();
    _controller.close();
  }
}
