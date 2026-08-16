# Gold & Forex Tracker (XAUUSD / GBPUSD)

A complete two-part app:

- **`backend/GoldForexApi`** — a .NET 8 API that keeps one live websocket
  connection open to Finnhub and streams real-time XAUUSD (gold) and
  GBPUSD prices to as many app instances as connect to it.
- **`flutter_app`** — a dark-themed, TradingView-style Flutter app (Android)
  that shows live prices, sparklines, and a full live chart per instrument.

