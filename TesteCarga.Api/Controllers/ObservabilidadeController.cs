using Microsoft.AspNetCore.Mvc;
using System.Diagnostics;
using OpenTelemetry.Trace;

namespace TesteCarga.Api.Controllers
{
    /// <summary>
    /// Controller para testar observabilidade com SigNoz
    /// Gera traces, logs e métricas para monitoramento
    /// </summary>
    [ApiController]
    [Route("api/[controller]")]
    public class ObservabilidadeController : ControllerBase
    {
        private readonly ILogger<ObservabilidadeController> _logger;
        private readonly IHttpClientFactory _httpClientFactory;
        private static readonly ActivitySource ActivitySource = new("TesteCarga.Api");

        public ObservabilidadeController(
            ILogger<ObservabilidadeController> logger,
            IHttpClientFactory httpClientFactory)
        {
            _logger = logger;
            _httpClientFactory = httpClientFactory;
        }

        /// <summary>
        /// 🔍 TRACES - Endpoint para testar rastreamento de requisições
        /// Aparece em: SigNoz > Traces
        /// Mostra: Tempo de execução, status code, endpoints chamados
        /// </summary>
        [HttpGet("trace-simples")]
        [ProducesResponseType(200)]
        public async Task<IActionResult> TraceSimples()
        {
            using var activity = ActivitySource.StartActivity("TraceSimples");
            activity?.SetTag("usuario.id", "12345");
            activity?.SetTag("acao", "consulta-simples");

            _logger.LogInformation("📊 Executando trace simples - ID: {TraceId}", Activity.Current?.TraceId);

            await Task.Delay(100); // Simula processamento

            return Ok(new
            {
                Mensagem = "Trace simples executado com sucesso!",
                TraceId = Activity.Current?.TraceId.ToString(),
                Timestamp = DateTime.UtcNow,
                Detalhes = "Este trace aparecerá no SigNoz > Traces mostrando o tempo de execução"
            });
        }

        /// <summary>
        /// 🔍 TRACES - Endpoint com múltiplos spans (chamadas internas)
        /// Aparece em: SigNoz > Traces
        /// Mostra: Breakdown de tempo em cada operação
        /// </summary>
        [HttpGet("trace-complexo")]
        [ProducesResponseType(200)]
        public async Task<IActionResult> TraceComplexo()
        {
            using var activity = ActivitySource.StartActivity("TraceComplexo");

            _logger.LogInformation("🔍 Iniciando trace complexo com múltiplos spans");

            // Span 1: Buscar dados
            using (var span1 = ActivitySource.StartActivity("BuscarDados"))
            {
                span1?.SetTag("database", "postgresql");
                _logger.LogInformation("📦 Buscando dados do banco de dados");
                await Task.Delay(150);
            }

            // Span 2: Processar dados
            using (var span2 = ActivitySource.StartActivity("ProcessarDados"))
            {
                span2?.SetTag("quantidade_registros", 100);
                _logger.LogInformation("⚙️ Processando {Quantidade} registros", 100);
                await Task.Delay(200);
            }

            // Span 3: Chamar API externa
            using (var span3 = ActivitySource.StartActivity("ChamarAPIExterna"))
            {
                span3?.SetTag("api.endpoint", "https://api.exemplo.com");
                _logger.LogInformation("🌐 Chamando API externa");
                await Task.Delay(300);
            }

            _logger.LogInformation("✅ Trace complexo finalizado com sucesso");

            return Ok(new
            {
                Mensagem = "Trace complexo com 3 spans executado!",
                TraceId = Activity.Current?.TraceId.ToString(),
                Spans = new[] { "BuscarDados (150ms)", "ProcessarDados (200ms)", "ChamarAPIExterna (300ms)" },
                TempoTotal = "~650ms",
                Detalhes = "No SigNoz você verá um breakdown detalhado de cada span"
            });
        }

        /// <summary>
        /// 🔍 TRACES - Endpoint que simula erro (gera trace com erro)
        /// Aparece em: SigNoz > Traces (marcado como erro)
        /// Mostra: Stack trace, mensagem de erro, tags de erro
        /// </summary>
        [HttpGet("trace-erro")]
        [ProducesResponseType(500)]
        public async Task<IActionResult> TraceComErro()
        {
            using var activity = ActivitySource.StartActivity("TraceComErro");

            try
            {
                _logger.LogWarning("⚠️ Simulando operação que irá falhar");

                await Task.Delay(50);

                // Simula erro
                throw new InvalidOperationException("Erro simulado para teste de observabilidade!");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "❌ Erro capturado no trace: {Mensagem}", ex.Message);

                activity?.SetTag("error", true);
                activity?.SetTag("error.type", ex.GetType().Name);
                activity?.SetTag("error.message", ex.Message);
                activity?.RecordException(ex);

                return StatusCode(500, new
                {
                    Erro = ex.Message,
                    TraceId = Activity.Current?.TraceId.ToString(),
                    Detalhes = "Este trace aparecerá em vermelho no SigNoz indicando erro"
                });
            }
        }

        /// <summary>
        /// 🔍 TRACES - Endpoint com chamada HTTP real
        /// Aparece em: SigNoz > Traces
        /// Mostra: Tempo da chamada HTTP, latência de rede
        /// </summary>
        [HttpGet("trace-http")]
        [ProducesResponseType(200)]
        public async Task<IActionResult> TraceComHttp()
        {
            using var activity = ActivitySource.StartActivity("TraceComHttp");

            _logger.LogInformation("🌐 Iniciando chamada HTTP externa");

            var client = _httpClientFactory.CreateClient();

            try
            {
                var response = await client.GetAsync("https://jsonplaceholder.typicode.com/posts/1");
                var content = await response.Content.ReadAsStringAsync();

                _logger.LogInformation("✅ Chamada HTTP concluída com status: {StatusCode}", response.StatusCode);

                return Ok(new
                {
                    Mensagem = "Chamada HTTP rastreada com sucesso!",
                    StatusCode = (int)response.StatusCode,
                    TraceId = Activity.Current?.TraceId.ToString(),
                    Detalhes = "No SigNoz você verá 2 spans: request principal + HTTP client"
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "❌ Erro na chamada HTTP");
                activity?.RecordException(ex);
                throw;
            }
        }

        /// <summary>
        /// 📝 LOGS - Endpoint para testar diferentes níveis de log
        /// Aparece em: SigNoz > Logs
        /// Mostra: Todos os logs gerados com níveis, timestamps e contexto
        /// </summary>
        [HttpGet("logs-exemplo")]
        [ProducesResponseType(200)]
        public IActionResult LogsExemplo()
        {
            _logger.LogTrace("🔍 TRACE: Log de rastreamento detalhado (geralmente desabilitado)");

            _logger.LogDebug("🐛 DEBUG: Informação de debug para desenvolvimento");

            _logger.LogInformation("ℹ️ INFO: Usuário {Usuario} acessou o sistema às {Hora}",
                "joao.silva", DateTime.Now);

            _logger.LogWarning("⚠️ WARNING: Taxa de uso está em {Percentual}%", 85);

            _logger.LogError("❌ ERROR: Falha ao conectar no banco de dados: {Erro}",
                "Connection timeout");

            _logger.LogCritical("🚨 CRITICAL: Sistema está sem memória! Memória livre: {MB}MB", 50);

            // Log com scope
            using (_logger.BeginScope("Contexto da Operação"))
            {
                _logger.LogInformation("📦 Processando pedido {PedidoId} do cliente {ClienteId}",
                    "PED-12345", "CLI-9876");
            }

            return Ok(new
            {
                Mensagem = "6 logs foram gerados em diferentes níveis!",
                TraceId = Activity.Current?.TraceId.ToString(),
                NiveisGerados = new[] { "Trace", "Debug", "Information", "Warning", "Error", "Critical" },
                Detalhes = "Vá em SigNoz > Logs e filtre pelo TraceId para ver todos os logs desta requisição"
            });
        }

        /// <summary>
        /// 📝 LOGS - Endpoint que gera logs estruturados
        /// Aparece em: SigNoz > Logs
        /// Mostra: Logs com propriedades estruturadas para facilitar filtros
        /// </summary>
        [HttpPost("log-estruturado")]
        [ProducesResponseType(200)]
        public IActionResult LogEstruturado([FromBody] LogRequest request)
        {
            using (_logger.BeginScope(new Dictionary<string, object>
            {
                ["UsuarioId"] = request.UsuarioId,
                ["Tenant"] = request.Tenant,
                ["Ambiente"] = "Production"
            }))
            {
                _logger.LogInformation(
                    "🎯 Ação realizada: {Acao} | Usuario: {Usuario} | Detalhes: {@Detalhes}",
                    request.Acao,
                    request.UsuarioId,
                    request.Detalhes);
            }

            return Ok(new
            {
                Mensagem = "Log estruturado criado!",
                Filtros = "No SigNoz > Logs você pode filtrar por: UsuarioId, Tenant, Acao, Ambiente",
                Detalhes = "Logs estruturados facilitam queries e análises"
            });
        }

        /// <summary>
        /// 📊 SERVICES - Informações sobre este serviço
        /// Aparece em: SigNoz > Services (visão geral do serviço)
        /// Mostra: Nome do serviço, versão, instância
        /// </summary>
        [HttpGet("info-servico")]
        [ProducesResponseType(200)]
        public IActionResult InfoServico()
        {
            return Ok(new
            {
                NomeServico = "testecarga-api-dev",
                Versao = "1.0.0",
                Instancia = Environment.MachineName,
                Ambiente = "Development",
                Observabilidade = new
                {
                    TraceId = Activity.Current?.TraceId.ToString(),
                    SpanId = Activity.Current?.SpanId.ToString()
                },
                Detalhes = "No SigNoz > Services você verá este serviço listado com todas as suas métricas"
            });
        }

        /// <summary>
        /// 🔄 SERVICES - Endpoint para gerar carga e testar métricas
        /// Aparece em: SigNoz > Services (métricas de latência, throughput)
        /// </summary>
        [HttpGet("carga/{segundos}")]
        [ProducesResponseType(200)]
        public async Task<IActionResult> GerarCarga(int segundos = 5)
        {
            if (segundos < 1 || segundos > 30)
            {
                return BadRequest("Segundos deve estar entre 1 e 30");
            }

            var requisicoes = 0;
            var stopwatch = Stopwatch.StartNew();
            var random = new Random();

            _logger.LogInformation("🚀 Iniciando geração de carga por {Segundos} segundos", segundos);

            while (stopwatch.Elapsed.TotalSeconds < segundos)
            {
                using var activity = ActivitySource.StartActivity($"CargaRequisicao_{requisicoes}");

                // Simula processamento variável
                var delay = random.Next(10, 200);
                await Task.Delay(delay);

                requisicoes++;

                if (requisicoes % 10 == 0)
                {
                    _logger.LogInformation("📈 Processadas {Requisicoes} requisições", requisicoes);
                }
            }

            stopwatch.Stop();

            _logger.LogInformation("✅ Carga finalizada: {Requisicoes} requisições em {Tempo}s",
                requisicoes, stopwatch.Elapsed.TotalSeconds);

            return Ok(new
            {
                RequisicoesProcessadas = requisicoes,
                TempoTotal = $"{stopwatch.Elapsed.TotalSeconds:F2}s",
                ThroughputMedio = $"{requisicoes / stopwatch.Elapsed.TotalSeconds:F2} req/s",
                Detalhes = "Vá em SigNoz > Services e veja o gráfico de throughput aumentando!"
            });
        }
    }

    public class LogRequest
    {
        public string UsuarioId { get; set; } = string.Empty;
        public string Tenant { get; set; } = string.Empty;
        public string Acao { get; set; } = string.Empty;
        public Dictionary<string, object>? Detalhes { get; set; }
    }
}