namespace GoldForexApi.Models;

/// <summary>
/// A single live price update for one instrument (XAUUSD or GBPUSD).
/// This is what gets sent to the Flutter app, both over the websocket
/// and from the REST snapshot endpoint.
/// </summary>
public class PriceTick
{
    public string Symbol { get; set; } = string.Empty;      // "XAUUSD" or "GBPUSD"
    public decimal Price { get; set; }
    public decimal PreviousClose { get; set; }               // session open reference price
    public decimal Change { get; set; }
    public decimal ChangePercent { get; set; }
    public long Timestamp { get; set; }                      // ms since epoch (from Finnhub)
    public decimal Volume { get; set; }
}
