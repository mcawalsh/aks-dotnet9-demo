using Microsoft.ApplicationInsights;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddApplicationInsightsTelemetry();
builder.Logging.AddApplicationInsights();

var app = builder.Build();

var telemetryClient = app.Services.GetRequiredService<TelemetryClient>();

app.MapGet("/", () =>
{
    telemetryClient.TrackTrace("Hello World endpoint was hit!");
    telemetryClient.TrackEvent("TestEvent", new Dictionary<string, string> { { "Source", "ManualTest" } });
    telemetryClient.TrackMetric("DemoMetric", 42);

    return "Hello World!";
});

app.Run();
