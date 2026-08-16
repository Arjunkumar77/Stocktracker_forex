using System.Net.WebSockets;
using System.Text;
using System.Text.Json;
using GoldForexApi.Models;

namespace GoldForexApi.Services;

/// <summary>
/// Maintains ONE persistent websocket connection to Finnhub's real-time
/// trade feed, subscribed to gold (XAU/USD) and GBP/USD via their OANDA
/// forex feed. Every trade tick that arrives is pushed straight into
/// PriceBroadcaster, which fans it out to every connected Flutter app.
///
/// Free Finnhub accounts get real-time (not delayed) forex and crypto
/// trade data over this websocket — this is what gives you "no delay"
/// prices without needing a paid plan.
/// </summary>
public class FinnhubPriceStreamService : BackgroundService
{
    private readonly PriceBroadcaster _broadcaster;
    private readonly ILogger<FinnhubPriceStreamService> _logger;
    private readonly IConfiguration _configuration;

    // Finnhub's symbol -> the symbol we show in the app.
    private static readonly Dictionary<string, string> SymbolMap = new()
    {
        { "OANDA:XAU_USD", "XAUUSD" },
        { "OANDA:GBP_USD", "GBPUSD" }
    };

    // First price seen this run, per symbol — used as the "open" reference
    // so we can show a Change / Change% even without a separate
    // previous-close lookup.
    private readonly Dictionary<string, decimal> _sessionOpen = new();

    public FinnhubPriceStreamService(
        PriceBroadcaster broadcaster,
        ILogger<FinnhubPriceStreamService> logger,
        IConfiguration configuration)
    {
        _broadcaster = broadcaster;
        _logger = logger;
        _configuration = configuration;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        var apiKey = _configuration["Finnhub:ApiKey"];

        if (string.IsNullOrWhiteSpace(apiKey) || apiKey == "YOUR_FINNHUB_API_KEY")
        {
            _logger.LogError(
                "Finnhub API key is not configured. Put a real key in appsettings.json " +
                "under Finnhub:ApiKey (get one free at https://finnhub.io/register).");
            return;
        }

        // Keep reconnecting forever if the connection drops — a phone
        // losing wifi or Finnhub restarting shouldn't kill the feed.
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await ConnectAndStreamAsync(apiKey, stoppingToken);
            }
            catch (Exception ex) when (!stoppingToken.IsCancellationRequested)
            {
                _logger.LogError(ex, "Finnhub stream connection failed, retrying in 5s");
            }

            if (!stoppingToken.IsCancellationRequested)
            {
                await Task.Delay(TimeSpan.FromSeconds(5), stoppingToken);
            }
        }
    }

    private async Task ConnectAndStreamAsync(string apiKey, CancellationToken stoppingToken)
    {
        using var ws = new ClientWebSocket();
        var uri = new Uri($"wss://ws.finnhub.io?token={apiKey}");

        _logger.LogInformation("Connecting to Finnhub websocket...");
        await ws.ConnectAsync(uri, stoppingToken);
        _logger.LogInformation("Connected. Subscribing to XAUUSD and GBPUSD...");

        foreach (var finnhubSymbol in SymbolMap.Keys)
        {
            var subscribeMsg = JsonSerializer.Serialize(new { type = "subscribe", symbol = finnhubSymbol });
            var bytes = Encoding.UTF8.GetBytes(subscribeMsg);
            await ws.SendAsync(bytes, WebSocketMessageType.Text, true, stoppingToken);
        }

        var buffer = new byte[8192];

        while (ws.State == WebSocketState.Open && !stoppingToken.IsCancellationRequested)
        {
            var messageBuilder = new StringBuilder();
            WebSocketReceiveResult result;

            do
            {
                result = await ws.ReceiveAsync(buffer, stoppingToken);

                if (result.MessageType == WebSocketMessageType.Close)
                {
                    _logger.LogWarning("Finnhub closed the websocket connection.");
                    return;
                }

                messageBuilder.Append(Encoding.UTF8.GetString(buffer, 0, result.Count));
            }
            while (!result.EndOfMessage);

            await ProcessMessageAsync(messageBuilder.ToString());
        }
    }

    private async Task ProcessMessageAsync(string message)
    {
        using var doc = JsonDocument.Parse(message);
        var root = doc.RootElement;

        if (!root.TryGetProperty("type", out var typeElement))
        {
            return;
        }

        var type = typeElement.GetString();

        // Finnhub also sends "ping" messages to keep the connection alive —
        // we only care about "trade" messages here.
        if (type != "trade" || !root.TryGetProperty("data", out var dataElement))
        {
            return;
        }

        foreach (var trade in dataElement.EnumerateArray())
        {
            var finnhubSymbol = trade.GetProperty("s").GetString() ?? string.Empty;

            if (!SymbolMap.TryGetValue(finnhubSymbol, out var displaySymbol))
            {
                continue; // not one of our two instruments
            }

            var price = trade.GetProperty("p").GetDecimal();
            var timestamp = trade.GetProperty("t").GetInt64();
            var volume = trade.TryGetProperty("v", out var v) ? v.GetDecimal() : 0;

            if (!_sessionOpen.TryGetValue(displaySymbol, out var open))
            {
                open = price;
                _sessionOpen[displaySymbol] = open;
            }

            var change = price - open;
            var changePercent = open != 0 ? (change / open) * 100 : 0;

            var tick = new PriceTick
            {
                Symbol = displaySymbol,
                Price = price,
                PreviousClose = open,
                Change = change,
                ChangePercent = changePercent,
                Timestamp = timestamp,
                Volume = volume
            };

            await _broadcaster.UpdatePriceAsync(tick);
        }
    }
}
