using System.Collections.Concurrent;
using System.Net.WebSockets;
using System.Text;
using System.Text.Json;
using GoldForexApi.Models;

namespace GoldForexApi.Services;

/// <summary>
/// Holds the latest known price for each instrument and fans out every
/// update to all connected Flutter clients over their own websocket
/// connections. There is exactly ONE upstream connection to Finnhub
/// (see FinnhubPriceStreamService) no matter how many phones are
/// connected — this class is what multiplies that single feed out to
/// many clients.
/// </summary>
public class PriceBroadcaster
{
    private readonly ConcurrentDictionary<string, PriceTick> _latestPrices = new();
    private readonly ConcurrentDictionary<Guid, WebSocket> _clients = new();

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase
    };

    public IEnumerable<PriceTick> GetSnapshot() => _latestPrices.Values;

    /// <summary>
    /// Called by FinnhubPriceStreamService whenever a new trade price
    /// arrives. Updates in-memory state then pushes it to every
    /// connected client immediately.
    /// </summary>
    public async Task UpdatePriceAsync(PriceTick tick)
    {
        _latestPrices[tick.Symbol] = tick;

        var payload = JsonSerializer.Serialize(new { type = "tick", data = tick }, JsonOptions);
        var bytes = Encoding.UTF8.GetBytes(payload);

        foreach (var (id, socket) in _clients)
        {
            if (socket.State != WebSocketState.Open)
            {
                _clients.TryRemove(id, out _);
                continue;
            }

            try
            {
                await socket.SendAsync(bytes, WebSocketMessageType.Text, true, CancellationToken.None);
            }
            catch
            {
                _clients.TryRemove(id, out _);
            }
        }
    }

    /// <summary>
    /// Registers a newly-connected Flutter client, immediately sends it
    /// the current snapshot (so the UI has data before the next tick
    /// arrives), then blocks until the client disconnects.
    /// </summary>
    public async Task HandleClientAsync(WebSocket socket, CancellationToken cancellationToken)
    {
        var id = Guid.NewGuid();
        _clients[id] = socket;

        try
        {
            var snapshotPayload = JsonSerializer.Serialize(
                new { type = "snapshot", data = _latestPrices.Values }, JsonOptions);
            var snapshotBytes = Encoding.UTF8.GetBytes(snapshotPayload);
            await socket.SendAsync(snapshotBytes, WebSocketMessageType.Text, true, cancellationToken);

            var buffer = new byte[1024];
            while (socket.State == WebSocketState.Open)
            {
                var result = await socket.ReceiveAsync(buffer, cancellationToken);
                if (result.MessageType == WebSocketMessageType.Close)
                {
                    await socket.CloseAsync(WebSocketCloseStatus.NormalClosure, "Closed", cancellationToken);
                }
            }
        }
        catch (OperationCanceledException)
        {
            // Server shutting down or client cancelled — nothing to do.
        }
        catch (WebSocketException)
        {
            // Client dropped the connection abruptly — nothing to do.
        }
        finally
        {
            _clients.TryRemove(id, out _);
        }
    }
}
