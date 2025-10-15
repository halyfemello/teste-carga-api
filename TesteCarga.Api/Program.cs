using Prometheus;
using Prometheus.HttpMetrics;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;
using OpenTelemetry.Metrics;
using OpenTelemetry.Logs;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
builder.Services.AddHttpClient(); // Para testes de HTTP com rastreamento

// Configure CORS properly
builder.Services.AddCors(options =>
{
    options.AddPolicy("Publico", policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyHeader()
              .AllowAnyMethod();
    });
});

builder.Services.AddAuthorization();

// ────────────────────────────────────────────────────────────────────────────────
// Adicionar o serviço de métricas Prometheus
// Não é necessário registrar AddHttpMetrics no IServiceCollection
// ────────────────────────────────────────────────────────────────────────────────

// ────────────────────────────────────────────────────────────────────────────────
// Configuração OpenTelemetry para SigNoz
// ────────────────────────────────────────────────────────────────────────────────
// Prioriza variáveis de ambiente OTEL_* (do docker-compose) sobre appsettings.json
var serviceName = Environment.GetEnvironmentVariable("OTEL_SERVICE_NAME")
    ?? builder.Configuration.GetValue<string>("ServiceName")
    ?? "testecarga-api";

var otlpEndpoint = Environment.GetEnvironmentVariable("OTEL_EXPORTER_OTLP_ENDPOINT")
    ?? builder.Configuration.GetValue<string>("OtlpEndpoint")
    ?? "http://signoz-otel-collector:4317";

Console.WriteLine($"🔧 OpenTelemetry configurado:");
Console.WriteLine($"   Service Name: {serviceName}");
Console.WriteLine($"   OTLP Endpoint: {otlpEndpoint}");

builder.Services.AddOpenTelemetry()
    .ConfigureResource(resource => resource
        .AddService(
            serviceName: serviceName,
            serviceVersion: "1.0.0",
            serviceInstanceId: Environment.MachineName))
    .WithTracing(tracing => tracing
        .AddSource("TesteCarga.Api") // Adiciona nosso ActivitySource customizado
        .AddAspNetCoreInstrumentation(options =>
        {
            options.RecordException = true;
            options.Filter = (httpContext) =>
            {
                // Não rastrear health checks e métricas
                return !httpContext.Request.Path.StartsWithSegments("/health") &&
                       !httpContext.Request.Path.StartsWithSegments("/metrics");
            };
        })
        .AddHttpClientInstrumentation(options =>
        {
            options.RecordException = true;
        })
        .AddOtlpExporter(options =>
        {
            options.Endpoint = new Uri(otlpEndpoint);
        }))
    .WithMetrics(metrics => metrics
        .AddAspNetCoreInstrumentation()
        .AddHttpClientInstrumentation()
        .AddRuntimeInstrumentation()
        .AddOtlpExporter(options =>
        {
            options.Endpoint = new Uri(otlpEndpoint);
        }));

// Adicionar suporte a Logs para o OpenTelemetry
builder.Logging.AddOpenTelemetry(logging =>
{
    logging.IncludeFormattedMessage = true;
    logging.IncludeScopes = true;
    logging.ParseStateValues = true;

    logging.AddOtlpExporter(options =>
    {
        options.Endpoint = new Uri(otlpEndpoint);
    });
});
// ────────────────────────────────────────────────────────────────────────────────

var app = builder.Build();

// ────────────────────────────────────────────────────────────────────────────────
// Mapear o endpoint /metrics automaticamente
app.UseHttpMetrics();
// ────────────────────────────────────────────────────────────────────────────────

// Remova o redirecionamento para HTTPS
// app.UseHttpsRedirection();

app.UseSwagger();
app.UseSwaggerUI(c =>
{
    c.SwaggerEndpoint("/swagger/v1/swagger.json", "TesteCarga API V1");
    c.RoutePrefix = string.Empty; // Set Swagger UI at the root
});

app.UseCors("Publico");
app.UseRouting();

app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

// ────────────────────────────────────────────────────────────────────────────────
// Expor o endpoint /metrics para o Prometheus raspar
app.MapMetrics();
// ────────────────────────────────────────────────────────────────────────────────

app.Run();
