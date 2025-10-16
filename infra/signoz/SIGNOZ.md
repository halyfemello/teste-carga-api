# 📊 Monitoramento com SigNoz

Este projeto está configurado para enviar métricas, traces e logs para o **SigNoz**, uma plataforma open-source de observabilidade.

## 🚀 O que você vai monitorar

### 📦 Métricas de Infraestrutura (Docker)

- ✅ **CPU**: Uso de cada container em %
- ✅ **Memória**: Uso e limite de cada container
- ✅ **Disco**: I/O de leitura/escrita
- ✅ **Rede**: Tráfego de entrada e saída
- ✅ **Host**: CPU, memória, disco e rede do servidor

### 🔍 Métricas de Aplicação (.NET API)

- ✅ **Requisições HTTP**: Total, duração, erros
- ✅ **Latência**: P50, P95, P99
- ✅ **Runtime .NET**: Garbage Collection, threads, exceções
- ✅ **Traces distribuídos**: Rastreamento completo de requisições

---

## 🛠️ Setup Inicial

### 1️⃣ Subir o SigNoz na VPS (primeira vez)

```bash
bash signoz.sh setup
```

Esse comando vai:

- Enviar as configurações para a VPS
- Baixar as imagens Docker necessárias
- Subir todos os containers (ClickHouse, Query Service, Frontend, OTel Collector)
- Inicializar o schema do banco de dados

**⏳ Aguarde 1-2 minutos** para todos os serviços iniciarem completamente.

**✅ Containers incluídos:**

- `signoz-clickhouse` - Banco de dados para métricas e traces
- `signoz-query-service` - Backend API
- `signoz-frontend` - Interface web
- `signoz-otel-collector` - Coletor de métricas

### 2️⃣ Acessar o Dashboard

Abra no navegador:

```
https://signoz.hmti.com.br
```

**Primeiro acesso:**

- Crie uma conta (dados ficam locais na VPS)
- Escolha um email e senha

**⚠️ Importante:** Se a interface estiver mostrando erros 500, execute:

```bash
bash signoz.sh logs query-service
```

Caso veja erros sobre "Table does not exist", execute o comando de inicialização do schema:

```bash
ssh root@195.200.1.129 "docker exec -i signoz-clickhouse clickhouse-client --multiquery < /root/docker/signoz/init-schema.sql"
```

---

## 🎯 Como usar

### Ver métricas dos containers Docker

1. Acesse o SigNoz: `http://195.200.1.129:3301`
2. Vá em **Dashboard** → **+ New Dashboard**
3. Adicione painéis com as seguintes métricas:

**CPU por container:**

```
container.cpu.percent
```

**Memória por container:**

```
container.memory.percent
```

**Tráfego de rede:**

```
container.network.io.usage.rx_bytes (entrada)
container.network.io.usage.tx_bytes (saída)
```

### Ver traces da API

1. Acesse **Traces** no menu lateral
2. Você verá todas as requisições HTTP da API
3. Clique em qualquer trace para ver detalhes:
   - Tempo total
   - Breakdown por operação
   - Erros e exceções
   - Headers e metadata

### Ver métricas da API

1. Acesse **Metrics**
2. Procure por:
   - `http.server.request.duration` - Latência das requisições
   - `http.server.active_requests` - Requisições ativas
   - `process.runtime.dotnet.gc.collections.count` - Garbage Collections

---

## 🔧 Comandos úteis

### Gerenciar o SigNoz

```bash
# Ver status dos containers
bash signoz.sh status

# Ver logs em tempo real
bash signoz.sh logs

# Parar o SigNoz
bash signoz.sh stop

# Iniciar novamente
bash signoz.sh start

# Reiniciar
bash signoz.sh restart

# Atualizar configurações
bash signoz.sh update

# Limpar todos os dados (CUIDADO!)
bash signoz.sh clean
```

### Deploy da API com monitoramento

Quando você rodar o deploy normal, as configurações do SigNoz também serão enviadas:

```bash
bash deploy.sh
```

---

## 📈 Dashboards recomendados

### 1. Overview de Infraestrutura

Crie um dashboard com:

- CPU total do host
- Memória total do host
- Disco usado/disponível
- Top 5 containers por CPU
- Top 5 containers por memória

### 2. Performance da API

- Taxa de requisições (req/s)
- Latência P50, P95, P99
- Taxa de erros (4xx, 5xx)
- Requisições por endpoint
- Tempo de resposta por endpoint

### 3. Saúde dos Containers

- Status (running/stopped)
- Uptime
- Restarts
- CPU e memória de cada container

---

## 🔍 Exemplos de queries

### CPU média de um container específico

```
avg(container.cpu.percent{container.name="api-teste"})
```

### Requisições HTTP por minuto

```
rate(http.server.request.count[1m])
```

### P95 de latência da API

```
histogram_quantile(0.95, http.server.request.duration)
```

---

## 🐛 Troubleshooting

### SigNoz não inicia

```bash
# Ver logs de todos os serviços
bash signoz.sh logs

# Verificar se as portas estão em uso
ssh root@195.200.1.129 "netstat -tulpn | grep -E '3301|4317|4318'"
```

### API não envia métricas

1. Verifique se o endpoint está correto em `appsettings.json`:

```json
"OtlpEndpoint": "http://195.200.1.129:4317"
```

2. Verifique se o container do OTel Collector está rodando:

```bash
ssh root@195.200.1.129 "docker ps | grep signoz-otel-collector"
```

3. Veja os logs do collector:

```bash
ssh root@195.200.1.129 "docker logs signoz-otel-collector -f"
```

### Métricas de Docker não aparecem

1. Verifique se o socket do Docker está montado:

```bash
ssh root@195.200.1.129 "docker inspect signoz-otel-collector | grep docker.sock"
```

2. Verifique o arquivo de configuração:

```bash
ssh root@195.200.1.129 "cat /root/docker/signoz/otel-collector-config.yaml"
```

---

## 📚 Recursos úteis

- [Documentação oficial do SigNoz](https://signoz.io/docs/)
- [OpenTelemetry para .NET](https://opentelemetry.io/docs/instrumentation/net/)
- [Query language do SigNoz](https://signoz.io/docs/userguide/query-builder/)

---

## 🔍 Troubleshooting

### Erro 500 nas páginas Services/Traces/Logs

**Sintoma:** Ao acessar Services, Traces ou Logs, aparece erro 500.

**Causa:** Tabelas do ClickHouse não foram criadas automaticamente.

**Solução:**

1. Execute o script de inicialização do schema:

```bash
ssh root@195.200.1.129 "docker exec -i signoz-clickhouse clickhouse-client --multiquery < /root/docker/signoz/init-schema.sql"
```

2. Reinicie o query-service:

```bash
ssh root@195.200.1.129 "docker restart signoz-query-service"
```

3. Aguarde 30 segundos e acesse novamente https://signoz.hmti.com.br

**Verificar se funcionou:**

```bash
ssh root@195.200.1.129 "docker exec signoz-clickhouse clickhouse-client --query 'SHOW TABLES FROM signoz_traces'"
```

Deve mostrar:

- `distributed_top_level_operations`
- `signoz_index_v2`
- `top_level_operations`

### Containers não iniciam

Verifique os logs:

```bash
bash signoz.sh logs clickhouse
bash signoz.sh logs query-service
```

---

## 🎨 Customização

### Adicionar mais métricas

Edite `infra/signoz/otel-collector-config.yaml` e adicione novos receivers ou processors.

Depois atualize:

```bash
bash signoz.sh update
```

### Configurar alertas

1. Acesse **Alerts** no SigNoz
2. Crie regras como:
   - CPU > 80% por 5 minutos
   - Memória > 90%
   - Taxa de erro > 5%
   - Latência P95 > 1s

### Integrar com webhook/Slack

Edite `infra/signoz/alertmanager-config.yaml` e configure seu webhook ou Slack:

```yaml
receivers:
  - name: "slack"
    slack_configs:
      - api_url: "https://hooks.slack.com/services/SEU/WEBHOOK/AQUI"
        channel: "#alerts"
```

---

## 🏆 Resultado final

Você terá um dashboard completo mostrando:

| Métrica         | Exemplo         |
| --------------- | --------------- |
| CPU (%)         | 1.2%            |
| Memória         | 350 MB / 2 GB   |
| Disco           | 10 GB usados    |
| Rede in/out     | 3.5 MB / 0.6 MB |
| Bandwidth total | 0.003 TB / 4 TB |
| Requisições/s   | 45 req/s        |
| Latência P95    | 125ms           |
| Taxa de erro    | 0.1%            |

**100% Open Source • Self-Hosted • Sem custos de SaaS** 🎉
