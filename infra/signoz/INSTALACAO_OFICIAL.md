# 📘 Guia Completo de Instalação do SigNoz (Versão Oficial)

> **Versão do SigNoz:** v0.97.0  
> **Versão do OTel Collector:** v0.129.7  
> **ClickHouse:** 25.5.6  
> **Data:** Outubro 2025

Este documento descreve o processo completo para instalar o SigNoz usando a versão oficial do repositório, integrado com Traefik para acesso via HTTPS.

---

## 📋 Índice

1. [Pré-requisitos](#pré-requisitos)
2. [Arquitetura da Solução](#arquitetura-da-solução)
3. [Passo a Passo da Instalação](#passo-a-passo-da-instalação)
4. [Configuração do Traefik](#configuração-do-traefik)
5. [Configuração da API](#configuração-da-api)
6. [Testes e Verificação](#testes-e-verificação)
7. [Manutenção e Troubleshooting](#manutenção-e-troubleshooting)
8. [Comandos Úteis](#comandos-úteis)

---

## 🔧 Pré-requisitos

### Na VPS (Servidor)

- **Sistema Operacional:** Linux (Ubuntu/Debian recomendado)
- **Docker:** v20.10+
- **Docker Compose:** v2.0+
- **Memória RAM:** Mínimo 4GB (recomendado 8GB+)
- **Disco:** Mínimo 20GB livres
- **Portas necessárias:**
  - `4317` - OTLP gRPC
  - `4318` - OTLP HTTP
  - `8080` - SigNoz API/Frontend
  - `443` - HTTPS (Traefik)
  - `80` - HTTP (Traefik)

### Rede Docker

Certifique-se de que as seguintes redes Docker existam:

```bash
# Rede para o Traefik
docker network create web

# Rede interna do SigNoz (será criada durante instalação)
docker network create signoz-net
```

---

## 🏗️ Arquitetura da Solução

```
┌─────────────────────────────────────────────────────────────┐
│                         Internet                             │
└────────────────────┬────────────────────────────────────────┘
                     │ HTTPS
                     ↓
            ┌─────────────────┐
            │     Traefik     │ (Rede: web)
            │  Reverse Proxy  │
            └────────┬────────┘
                     │
         ┌───────────┴───────────┐
         │                       │
         ↓                       ↓
┌─────────────────┐    ┌──────────────────┐
│     SigNoz      │←──→│ OTel Collector   │
│ Frontend/API    │    │   (Port 4317/    │
│   (Port 8080)   │    │      4318)       │
└────────┬────────┘    └────────┬─────────┘
         │                      │
         │      (Rede: signoz-net + web)
         │                      │
         ↓                      ↓
┌─────────────────┐    ┌──────────────────┐
│   ClickHouse    │    │    Zookeeper     │
│  (Métricas &    │    │  (Coordenação)   │
│    Traces)      │    │                  │
└─────────────────┘    └──────────────────┘
         ↑
         │ Envia dados
         │
    ┌────┴─────┐
    │   API    │ (Sua aplicação)
    │ .NET/etc │
    └──────────┘
```

---

## 📝 Passo a Passo da Instalação

### 1. Conectar na VPS

```bash
ssh root@SEU_IP_VPS
```

### 2. Clonar o Repositório Oficial do SigNoz

```bash
cd /root
git clone -b main https://github.com/SigNoz/signoz.git
cd signoz/deploy/docker
```

**Estrutura do diretório:**

```
/root/signoz/deploy/docker/
├── docker-compose.yaml          # Compose principal
├── docker-compose.ha.yaml       # High Availability (não usado)
├── otel-collector-config.yaml   # Configuração do collector
└── clickhouse-setup/            # Scripts de inicialização
```

### 3. Criar Arquivo de Override para Integração com Traefik

Crie o arquivo `docker-compose.override.yaml` para adicionar configurações customizadas:

```bash
cat > /root/signoz/deploy/docker/docker-compose.override.yaml << 'EOF'
version: '3'

services:
  # Serviço principal do SigNoz (Frontend + Backend)
  signoz:
    networks:
      - signoz-net  # Rede interna
      - web         # Rede do Traefik
    labels:
      - 'traefik.enable=true'
      - 'traefik.http.routers.signoz-frontend.rule=Host(`signoz.SEU_DOMINIO.com.br`)'
      - 'traefik.http.routers.signoz-frontend.entrypoints=websecure'
      - 'traefik.http.routers.signoz-frontend.tls=true'
      - 'traefik.http.routers.signoz-frontend.tls.certresolver=lets-encrypt'
      - 'traefik.http.services.signoz-frontend.loadbalancer.server.port=8080'
      - 'traefik.docker.network=web'

  # OTel Collector - recebe dados da aplicação
  otel-collector:
    networks:
      - signoz-net
      - web

  # ClickHouse - banco de dados
  clickhouse:
    networks:
      - signoz-net
      - web

networks:
  web:
    external: true
  signoz-net:
    external: true
EOF
```

**⚠️ IMPORTANTE:** Substitua `signoz.SEU_DOMINIO.com.br` pelo seu domínio real!

### 4. Criar as Redes Docker

```bash
# Criar rede signoz-net se não existir
docker network create signoz-net

# Verificar se a rede web existe (usada pelo Traefik)
docker network ls | grep web
```

### 5. Iniciar o SigNoz

```bash
cd /root/signoz/deploy/docker
docker compose up -d
```

**Aguarde cerca de 1-2 minutos** para todos os containers iniciarem completamente.

### 6. Verificar Status dos Containers

```bash
docker compose ps
```

**Saída esperada:**

```
NAME                    STATUS
signoz                  Up (healthy)
signoz-clickhouse       Up (healthy)
signoz-otel-collector   Up
signoz-zookeeper-1      Up (healthy)
```

---

## 🌐 Configuração do Traefik

### 1. Atualizar o Arquivo de Configuração Dinâmica

Edite o arquivo `/root/docker/traefik/traefik_dynamic.toml` e adicione:

```toml
# SigNoz - Configuração para instalação oficial (serviço unificado)
[http.routers.signoz-https]
  rule = "Host(`signoz.SEU_DOMINIO.com.br`)"
  entrypoints = ["websecure"]
  service = "signoz-service"
  priority = 1
  [http.routers.signoz-https.tls]
    certResolver = "lets-encrypt"

[http.routers.signoz-http]
  rule = "Host(`signoz.SEU_DOMINIO.com.br`)"
  entrypoints = ["web"]
  service = "signoz-service"
  priority = 1

[http.services.signoz-service.loadBalancer]
  [[http.services.signoz-service.loadBalancer.servers]]
    url = "http://signoz:8080"
```

### 2. Reiniciar o Traefik

```bash
docker restart traefik
```

### 3. Verificar Acesso

Aguarde cerca de 30 segundos e acesse:

```
https://signoz.SEU_DOMINIO.com.br
```

**✅ Você deve ver a tela de registro do SigNoz!**

---

## 🔐 Primeiro Acesso e Configuração

### 1. Criar Conta de Administrador

Na tela de registro, crie uma conta com:

- **Email:** seu-email@exemplo.com
- **Nome:** Seu Nome
- **Organização:** Nome da Empresa
- **Senha:** Mínimo 12 caracteres com:
  - Letras maiúsculas (A-Z)
  - Letras minúsculas (a-z)
  - Números (0-9)
  - Símbolos especiais (!, @, #, $, etc.)

**Exemplo de senha válida:** `Admin@123456789`

### 2. Resetar Banco (Se Necessário)

Se precisar criar uma nova conta ou resetar:

```bash
cd /root/signoz/deploy/docker
docker compose stop signoz
docker rm signoz
docker volume rm signoz-sqlite
docker compose up -d signoz
```

---

## 🔌 Configuração da API (.NET/ASP.NET Core)

### 1. Instalar Pacotes NuGet

```bash
dotnet add package OpenTelemetry
dotnet add package OpenTelemetry.Exporter.OpenTelemetryProtocol
dotnet add package OpenTelemetry.Extensions.Hosting
dotnet add package OpenTelemetry.Instrumentation.AspNetCore
dotnet add package OpenTelemetry.Instrumentation.Http
```

### 2. Configurar Program.cs

```csharp
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;
using OpenTelemetry.Metrics;
using OpenTelemetry.Logs;

var builder = WebApplication.CreateBuilder(args);

// Configurar OpenTelemetry
builder.Services.AddOpenTelemetry()
    .ConfigureResource(resource => resource
        .AddService(
            serviceName: "minha-api",
            serviceVersion: "1.0.0"))
    .WithTracing(tracing => tracing
        .AddAspNetCoreInstrumentation()
        .AddHttpClientInstrumentation()
        .AddOtlpExporter(options =>
        {
            options.Endpoint = new Uri("http://signoz-otel-collector:4317");
            options.Protocol = OpenTelemetry.Exporter.OtlpExportProtocol.Grpc;
        }))
    .WithMetrics(metrics => metrics
        .AddAspNetCoreInstrumentation()
        .AddHttpClientInstrumentation()
        .AddOtlpExporter(options =>
        {
            options.Endpoint = new Uri("http://signoz-otel-collector:4317");
            options.Protocol = OpenTelemetry.Exporter.OtlpExportProtocol.Grpc;
        }));

var app = builder.Build();
app.Run();
```

### 3. Configurar docker-compose.yml da API

```yaml
version: "3.8"

services:
  minha-api:
    image: minha-api:latest
    container_name: minha-api
    networks:
      - web
      - signoz-net # Adicionar esta rede
    environment:
      - OTEL_EXPORTER_OTLP_ENDPOINT=http://signoz-otel-collector:4317
      - OTEL_EXPORTER_OTLP_PROTOCOL=grpc
      - OTEL_SERVICE_NAME=minha-api
      - OTEL_RESOURCE_ATTRIBUTES=deployment.environment=production
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.api.rule=Host(`api.SEU_DOMINIO.com.br`)"
      # ... outros labels do Traefik

networks:
  web:
    external: true
  signoz-net:
    external: true
```

### 4. Publicar e Reiniciar a API

```bash
# Na sua máquina local
bash deploy.sh

# Na VPS
cd /root/docker
docker compose restart minha-api
```

---

## 🧪 Testes e Verificação

### 1. Usar o Script de Diagnóstico

```bash
cd /root/signoz/deploy/docker
# Copiar o script diagnostico-completo.sh para a VPS

# Executar diagnóstico completo
bash diagnostico-completo.sh full

# Ou comandos específicos:
bash diagnostico-completo.sh status    # Ver status
bash diagnostico-completo.sh test      # Testar traces
bash diagnostico-completo.sh logs      # Ver logs
bash diagnostico-completo.sh restart   # Reiniciar tudo
```

### 2. Verificação Manual

```bash
# Status dos containers
docker compose ps

# Testar API do SigNoz
curl https://signoz.SEU_DOMINIO.com.br/api/v1/version

# Ver logs do OTel Collector
docker logs signoz-otel-collector --tail 50

# Verificar traces no ClickHouse
docker exec signoz-clickhouse clickhouse-client --query \
  "SELECT count() FROM signoz_traces.signoz_index_v2 WHERE timestamp >= now() - INTERVAL 1 HOUR"
```

### 3. Verificar no Dashboard

1. Acesse `https://signoz.SEU_DOMINIO.com.br`
2. Faça login
3. Vá para **Services** → Você deve ver sua API listada
4. Clique na API para ver traces e métricas

---

## 🛠️ Manutenção e Troubleshooting

### Problemas Comuns

#### 1. Container não inicia

```bash
# Ver logs detalhados
docker logs signoz --tail 100

# Verificar recursos
docker stats

# Reiniciar container específico
docker compose restart signoz
```

#### 2. API não envia dados

**Verificar:**

- API está na rede `signoz-net`?
- Endpoint está correto: `http://signoz-otel-collector:4317`
- Portas 4317/4318 estão expostas?

```bash
# Verificar redes do container da API
docker inspect minha-api | grep -A 10 Networks

# Verificar logs do collector
docker logs signoz-otel-collector --tail 50 | grep error
```

#### 3. Erro 502 no Traefik

**Causa:** Traefik não consegue acessar o SigNoz

**Solução:**

```bash
# Verificar se signoz está na rede web
docker inspect signoz | grep -A 10 Networks

# Recriar containers para aplicar redes
cd /root/signoz/deploy/docker
docker compose down
docker compose up -d
```

#### 4. ClickHouse sem espaço

```bash
# Verificar uso de disco
df -h

# Limpar dados antigos (cuidado!)
docker exec signoz-clickhouse clickhouse-client --query \
  "ALTER TABLE signoz_traces.signoz_index_v2 DELETE WHERE timestamp < now() - INTERVAL 30 DAY"
```

### Backup e Restauração

#### Backup dos Dados

```bash
# Backup do volume do ClickHouse
docker run --rm -v signoz-clickhouse:/data -v $(pwd):/backup \
  alpine tar czf /backup/signoz-clickhouse-backup.tar.gz /data

# Backup do SQLite (usuários e configurações)
docker run --rm -v signoz-sqlite:/data -v $(pwd):/backup \
  alpine tar czf /backup/signoz-sqlite-backup.tar.gz /data
```

#### Restauração

```bash
# Parar serviços
docker compose down

# Restaurar ClickHouse
docker run --rm -v signoz-clickhouse:/data -v $(pwd):/backup \
  alpine tar xzf /backup/signoz-clickhouse-backup.tar.gz -C /

# Restaurar SQLite
docker run --rm -v signoz-sqlite:/data -v $(pwd):/backup \
  alpine tar xzf /backup/signoz-sqlite-backup.tar.gz -C /

# Reiniciar
docker compose up -d
```

---

## 📚 Comandos Úteis

### Gerenciamento de Containers

```bash
# Ver status
docker compose ps

# Ver logs de todos os containers
docker compose logs -f

# Ver logs de um container específico
docker logs signoz -f

# Reiniciar todos os serviços
docker compose restart

# Parar todos os serviços
docker compose down

# Iniciar todos os serviços
docker compose up -d

# Remover tudo (incluindo volumes - CUIDADO!)
docker compose down -v
```

### Monitoramento

```bash
# Uso de recursos
docker stats

# Verificar saúde dos containers
docker ps --format "table {{.Names}}\t{{.Status}}"

# Espaço usado pelos volumes
docker system df -v
```

### Queries Úteis no ClickHouse

```bash
# Total de traces
docker exec signoz-clickhouse clickhouse-client --query \
  "SELECT count() FROM signoz_traces.signoz_index_v2"

# Serviços com mais traces (últimas 24h)
docker exec signoz-clickhouse clickhouse-client --query \
  "SELECT service_name, count() as total FROM signoz_traces.signoz_index_v2
   WHERE timestamp >= now() - INTERVAL 24 HOUR
   GROUP BY service_name ORDER BY total DESC LIMIT 10 FORMAT PrettyCompact"

# Traces com erro (últimas 24h)
docker exec signoz-clickhouse clickhouse-client --query \
  "SELECT count() FROM signoz_traces.signoz_index_v2
   WHERE timestamp >= now() - INTERVAL 24 HOUR AND has_error = 1"
```

---

## 🔄 Atualização do SigNoz

### 1. Backup Antes de Atualizar

```bash
cd /root/signoz/deploy/docker
docker compose down
# Fazer backup dos volumes (ver seção anterior)
```

### 2. Atualizar o Código

```bash
cd /root/signoz
git pull origin main
```

### 3. Atualizar Imagens

```bash
cd deploy/docker
docker compose pull
docker compose up -d
```

### 4. Verificar

```bash
docker compose ps
curl https://signoz.SEU_DOMINIO.com.br/api/v1/version
```

---

## 📊 Configurações Recomendadas

### Limites de Recursos (Produção)

Edite `docker-compose.override.yaml` para adicionar limites:

```yaml
services:
  signoz:
    deploy:
      resources:
        limits:
          cpus: "2"
          memory: 2G
        reservations:
          cpus: "1"
          memory: 1G

  clickhouse:
    deploy:
      resources:
        limits:
          cpus: "4"
          memory: 4G
        reservations:
          cpus: "2"
          memory: 2G
```

### Retenção de Dados

Por padrão, o SigNoz mantém:

- **Traces:** 7 dias
- **Métricas:** 15 dias
- **Logs:** 7 dias

Para alterar, configure via interface web em **Settings → Retention**.

---

## 🆘 Suporte e Referências

- **Documentação Oficial:** https://signoz.io/docs/
- **Repositório GitHub:** https://github.com/SigNoz/signoz
- **Community Slack:** https://signoz.io/slack
- **Issues/Bugs:** https://github.com/SigNoz/signoz/issues

---

## ✅ Checklist de Instalação Completa

- [ ] VPS com Docker e Docker Compose instalados
- [ ] Redes `web` e `signoz-net` criadas
- [ ] Repositório oficial clonado em `/root/signoz`
- [ ] Arquivo `docker-compose.override.yaml` criado
- [ ] Containers iniciados e saudáveis (`docker compose ps`)
- [ ] Traefik configurado com domínio correto
- [ ] Acesso HTTPS funcionando (`https://signoz.SEU_DOMINIO.com.br`)
- [ ] Conta de administrador criada
- [ ] API configurada com OpenTelemetry
- [ ] API conectada às redes `web` e `signoz-net`
- [ ] Traces aparecendo no dashboard
- [ ] Script de diagnóstico testado e funcionando

---

**🎉 Instalação Concluída!**

Agora você tem uma instalação completa e funcional do SigNoz integrada com Traefik para observabilidade de suas aplicações!
