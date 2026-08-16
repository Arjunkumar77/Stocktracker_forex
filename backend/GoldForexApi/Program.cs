using GoldForexApi.Services;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddSingleton<PriceBroadcaster>();
builder.Services.AddHostedService<FinnhubPriceStreamService>();

// Dev-friendly CORS so the Flutter app (running on an emulator or a
// physical phone, on a different origin) can call this API.
// Tighten this before shipping to production.
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
    {
        policy.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod();
    });
});

var app = builder.Build();

app.UseCors("AllowAll");
app.UseWebSockets();

// GET /api/prices -> current snapshot of both instruments.
// The Flutter app calls this once on startup so it has something to
// show immediately, before the websocket delivers the next live tick.
app.MapGet("/api/prices", (PriceBroadcaster broadcaster) =>
{
    return Results.Ok(broadcaster.GetSnapshot());
});

app.MapGet("/api/health", () => Results.Ok(new { status = "ok", time = DateTime.UtcNow }));

// WS /ws/prices -> live push feed. Every connected client gets every
// price tick the instant FinnhubPriceStreamService receives it.
app.Map("/ws/prices", async (HttpContext context, PriceBroadcaster broadcaster) =>
{
    if (!context.WebSockets.IsWebSocketRequest)
    {
        context.Response.StatusCode = StatusCodes.Status400BadRequest;
        return;
    }

    var socket = await context.WebSockets.AcceptWebSocketAsync();
    await broadcaster.HandleClientAsync(socket, context.RequestAborted);
});

app.Run();
