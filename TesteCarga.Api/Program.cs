using Prometheus;
using Prometheus.HttpMetrics;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

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
