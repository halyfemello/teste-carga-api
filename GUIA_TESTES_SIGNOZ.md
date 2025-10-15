# 🎯 Guia de Testes - SigNoz Observabilidade

## 📊 Entendendo as 3 Visões do SigNoz

### 🔷 **1. SERVICES** (Visão de Serviços)

**O que é:** Visão geral de TODOS os serviços que estão enviando dados para o SigNoz.

**O que você vê:**

- 📋 **Lista de serviços**: `testecarga-api-dev`, `testecarga-api-prod`, etc.
- 📈 **Métricas por serviço**:
  - **Latência P50, P95, P99**: Tempo médio e percentis de resposta
  - **Taxa de erro**: Porcentagem de requisições com erro
  - **Throughput**: Requisições por segundo (req/s)
  - **Requisições ativas**: Quantas requisições estão sendo processadas agora

**Como testar:**

```bash
# 1. Chame qualquer endpoint várias vezes
curl http://localhost/api/observabilidade/trace-simples
curl http://localhost/api/observabilidade/trace-simples
curl http://localhost/api/observabilidade/trace-simples

# 2. Gere carga para ver throughput
curl http://localhost/api/observabilidade/carga/10

# 3. Vá em SigNoz > Services
# Você verá o serviço "testecarga-api-dev" listado
# Clique nele para ver métricas detalhadas
```

---

### 🔷 **2. TRACES** (Rastreamento de Requisições)

**O que é:** Acompanhamento DETALHADO de cada requisição individual, do início ao fim.

**O que você vê:**

- 🔍 **Lista de traces**: Cada requisição é um trace
- ⏱️ **Tempo total**: Quanto tempo levou a requisição completa
- 📊 **Breakdown**: Tempo gasto em cada operação (banco, API externa, processamento)
- 🏷️ **Tags**: Metadados da requisição (usuário, endpoint, status)
- 🔴 **Erros**: Traces com erro aparecem destacados

**Exemplo de Trace:**

```
┌─ Requisição GET /api/observabilidade/trace-complexo (650ms)
│  ├─ BuscarDados (150ms)           ← Span 1
│  ├─ ProcessarDados (200ms)        ← Span 2
│  └─ ChamarAPIExterna (300ms)      ← Span 3
```

**Como testar:**

```bash
# 1. Trace simples (1 span)
curl http://localhost/api/observabilidade/trace-simples

# 2. Trace complexo (3 spans - veja o breakdown!)
curl http://localhost/api/observabilidade/trace-complexo

# 3. Trace com erro (aparece em vermelho)
curl http://localhost/api/observabilidade/trace-erro

# 4. Trace com HTTP (veja chamada externa)
curl http://localhost/api/observabilidade/trace-http

# 5. Vá em SigNoz > Traces
# - Filtre por serviço: "testecarga-api-dev"
# - Clique em qualquer trace para ver detalhes
# - Procure pelo trace com erro (status 500)
```

**Dicas:**

- Traces com erro aparecem com 🔴 status vermelho
- Clique em um trace para ver o "Flamegraph" (gráfico de chama)
- Use o filtro de tempo para ver traces recentes

---

### 🔷 **3. LOGS** (Registros de Eventos)

**O que é:** Todos os logs (console.log, logger, etc.) da aplicação em tempo real.

**O que você vê:**

- 📝 **Lista de logs**: Todos os logs gerados
- 🎨 **Níveis**: Trace, Debug, Info, Warning, Error, Critical
- 🕐 **Timestamp**: Quando o log foi gerado
- 🔗 **TraceId**: Correlação com o trace da requisição
- 📊 **Campos estruturados**: Propriedades como usuarioId, acao, tenant

**Níveis de Log:**

- 🔍 **TRACE**: Detalhes extremamente verbosos (geralmente desligado)
- 🐛 **DEBUG**: Info para desenvolvimento
- ℹ️ **INFO**: Eventos normais (usuário logou, pedido criado)
- ⚠️ **WARNING**: Algo estranho mas não crítico (cache miss, retry)
- ❌ **ERROR**: Erro que precisa atenção (falha na API)
- 🚨 **CRITICAL**: Sistema em risco (sem memória, disco cheio)

**Como testar:**

```bash
# 1. Gerar logs de todos os níveis
curl http://localhost/api/observabilidade/logs-exemplo

# 2. Gerar log estruturado (com filtros)
curl -X POST http://localhost/api/observabilidade/log-estruturado \
  -H "Content-Type: application/json" \
  -d '{
    "usuarioId": "user-123",
    "tenant": "empresa-abc",
    "acao": "criar-pedido",
    "detalhes": {
      "pedidoId": "PED-456",
      "valor": 1500.00
    }
  }'

# 3. Vá em SigNoz > Logs
# - Veja os 6 logs gerados (Trace, Debug, Info, Warning, Error, Critical)
# - Filtre por TraceId para ver apenas logs de uma requisição
# - Filtre por nível (ex: apenas ERROR e CRITICAL)
# - Busque por texto: "usuário", "pedido", etc.
```

**Dicas:**

- Use filtros por **TraceId** para ver todos os logs de uma requisição específica
- Logs estruturados permitem filtrar por campos customizados (usuarioId, tenant)
- Configure alertas para logs CRITICAL ou ERROR

---

## 🧪 Roteiro de Teste Completo

### Passo 1: Subir a API

```bash
# Na VPS, fazer deploy
bash deploy.sh

# Aguardar 30 segundos para a API iniciar
```

### Passo 2: Gerar Traces

```bash
# Trace simples
curl http://localhost/api/observabilidade/trace-simples

# Trace complexo com breakdown
curl http://localhost/api/observabilidade/trace-complexo

# Trace com erro
curl http://localhost/api/observabilidade/trace-erro

# Trace com HTTP externo
curl http://localhost/api/observabilidade/trace-http
```

### Passo 3: Gerar Logs

```bash
# Logs de todos os níveis
curl http://localhost/api/observabilidade/logs-exemplo

# Log estruturado
curl -X POST http://localhost/api/observabilidade/log-estruturado \
  -H "Content-Type: application/json" \
  -d '{"usuarioId":"user-789","tenant":"acme","acao":"teste","detalhes":{}}'
```

### Passo 4: Gerar Carga (Métricas)

```bash
# Gerar carga por 15 segundos
curl http://localhost/api/observabilidade/carga/15

# Enquanto isso, vá em SigNoz > Services
# Você verá o throughput subindo em tempo real!
```

### Passo 5: Explorar no SigNoz

#### 🔷 Services

1. Acesse: https://signoz.hmti.com.br/services
2. Procure: `testecarga-api-dev`
3. Veja: Latência, taxa de erro, throughput

#### 🔷 Traces

1. Acesse: https://signoz.hmti.com.br/traces
2. Filtre por serviço: `testecarga-api-dev`
3. Clique em um trace para ver detalhes
4. Procure pelo trace com erro (status 500)

#### 🔷 Logs

1. Acesse: https://signoz.hmti.com.br/logs
2. Veja todos os logs recentes
3. Filtre por:
   - **Nível**: ERROR, WARNING, INFO
   - **TraceId**: Copie um TraceId de um trace e cole aqui
   - **Texto**: Busque por "erro", "usuário", etc.

---

## 📌 Endpoints Disponíveis

| Endpoint                                | Método | Descrição                        | Aparece em |
| --------------------------------------- | ------ | -------------------------------- | ---------- |
| `/api/observabilidade/trace-simples`    | GET    | Trace básico de 1 span           | Traces     |
| `/api/observabilidade/trace-complexo`   | GET    | Trace com 3 spans (breakdown)    | Traces     |
| `/api/observabilidade/trace-erro`       | GET    | Trace que gera erro 500          | Traces     |
| `/api/observabilidade/trace-http`       | GET    | Trace com chamada HTTP externa   | Traces     |
| `/api/observabilidade/logs-exemplo`     | GET    | Gera 6 logs de níveis diferentes | Logs       |
| `/api/observabilidade/log-estruturado`  | POST   | Log com campos customizados      | Logs       |
| `/api/observabilidade/info-servico`     | GET    | Informações do serviço           | Services   |
| `/api/observabilidade/carga/{segundos}` | GET    | Gera carga para testar métricas  | Services   |

---

## 🎓 Conceitos Importantes

### 📊 **Service vs Trace vs Log**

- **Service**: Sua aplicação como um todo (ex: `testecarga-api-dev`)
- **Trace**: Uma requisição específica (ex: `GET /trace-complexo` com TraceId `abc123`)
- **Log**: Um evento dentro de um trace (ex: "Processando pedido PED-456")

### 🔗 **Correlação**

Todos os logs de um trace têm o mesmo **TraceId**, permitindo ver tudo que aconteceu em uma requisição:

```
TraceId: abc123
├─ Requisição recebida (INFO)
├─ Buscando dados (INFO)
├─ Erro ao conectar (ERROR)
└─ Requisição finalizada (INFO)
```

### 📈 **Percentis de Latência**

- **P50 (mediana)**: 50% das requisições são mais rápidas que isso
- **P95**: 95% das requisições são mais rápidas (ignora picos)
- **P99**: 99% das requisições são mais rápidas (mostra os casos mais lentos)

Exemplo:

- P50 = 100ms → Metade das requisições é rápida
- P99 = 2000ms → 1% das requisições leva 2 segundos (problema!)

---

## 🐛 Troubleshooting

### Não vejo dados no SigNoz?

1. **Verifique se a API está rodando:**

```bash
ssh root@195.200.1.129 "docker ps | grep testecarga"
```

2. **Verifique os logs da API:**

```bash
ssh root@195.200.1.129 "docker logs testecarga-api --tail 50"
```

3. **Verifique se o collector está recebendo dados:**

```bash
ssh root@195.200.1.129 "docker logs signoz-otel-collector --tail 50"
```

4. **Teste a conexão OTLP:**

```bash
ssh root@195.200.1.129 "docker exec testecarga-api curl -v http://signoz-otel-collector:4317"
```

### Dados aparecem com atraso?

- É normal um delay de 10-30 segundos
- Clique em "Refresh" no SigNoz
- Ajuste o filtro de tempo para "Last 5 minutes"

---

## 🚀 Próximos Passos

1. **Configure alertas**: Crie alertas para erros ou latência alta
2. **Crie dashboards**: Visualize múltiplas métricas em um só lugar
3. **Adicione mais tags**: Customize os traces com mais informações
4. **Monitore outros serviços**: Adicione N8N, Traefik, etc.

---

## 📚 Documentação Oficial

- **SigNoz**: https://signoz.io/docs/
- **OpenTelemetry**: https://opentelemetry.io/docs/
- **Traces**: https://signoz.io/docs/userguide/traces/
- **Logs**: https://signoz.io/docs/userguide/logs/
- **Metrics**: https://signoz.io/docs/userguide/metrics/
