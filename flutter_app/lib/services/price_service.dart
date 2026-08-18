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
  // SWITCH BETWEEN LOCAL DEV AND YOUR DEPLOYED SERVER HERE.
  //
  // Local dev (dotnet run on your PC, phone/emulator on same wifi):
  //   useProductionServer = false
  //   devHost = '10.0.2.2' for the Android emulator, or your PC's LAN IP
  //             (e.g. '192.168.1.42') for a physical phone
  //
  // Day-to-day use (API deployed to Render/Railway/etc., works anywhere,
  // no PC required):
  //   useProductionServer = true
  //   prodHost = the domain your host gave you, e.g.
  //              'gold-forex-api.onrender.com' — no "https://" prefix,
  //              no trailing slash, no port.
  // ---------------------------------------------------------------------
  static const bool useProductionServer = true;

  static const String prodHost = 'stocktracker-forex.onrender.com';

  static const String devHost = '10.0.2.2';
  static const int devPort = 5000;

  static String get _httpScheme => useProductionServer ? 'https' : 'http';
  static String get _wsScheme => useProductionServer ? 'wss' : 'ws';
  static String get _hostAndPort =>
      useProductionServer ? prodHost : '$devHost:$devPort';

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
      final uri = Uri.parse('$_httpScheme://$_hostAndPort/api/prices');
      // ignore: avoid_print
      print('[PriceService] fetching snapshot from $uri');
      final response = await http.get(uri).timeout(const Duration(seconds: 20));

      // ignore: avoid_print
      print('[PriceService] snapshot response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        for (final item in data) {
          _emit(PriceTick.fromJson(item as Map<String, dynamic>));
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('[PriceService] snapshot fetch FAILED: $e');
    }
  }

  void connect() {
    if (_disposed) return;

    final uri = Uri.parse('$_wsScheme://$_hostAndPort/ws/prices');
    // ignore: avoid_print
    print('[PriceService] connecting websocket to $uri');

    try {
      _channel = WebSocketChannel.connect(uri);
      _channelSub = _channel!.stream.listen(
        _handleMessage,
        onError: (e) {
          // ignore: avoid_print
          print('[PriceService] websocket ERROR: $e');
          _scheduleReconnect();
        },
        onDone: () {
          // ignore: avoid_print
          print('[PriceService] websocket closed (onDone)');
          _scheduleReconnect();
        },
        cancelOnError: true,
      );
    } catch (e) {
      // ignore: avoid_print
      print('[PriceService] websocket connect FAILED: $e');
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
