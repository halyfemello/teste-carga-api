#!/bin/bash

# ============================================================================
# Diagnóstico Completo do SigNoz - Script Central
# ============================================================================
# Versão: 2.0
# Compatível com: SigNoz 0.64.0+ / OTel Collector 0.111.16+
# 
# Este é o ÚNICO script necessário para diagnosticar, corrigir e testar
# todo o ambiente SigNoz. Consolida todas as funcionalidades em um só lugar.
#
# Uso:
#   bash diagnostico-completo.sh [opção]
#
# Opções:
#   status      - Verificar status geral do sistema
#   schema      - Corrigir schema do ClickHouse
#   config      - Atualizar configuração do OTel Collector
#   test        - Testar geração de traces
#   full        - Diagnóstico completo (padrão)
# ============================================================================

set -e

# Configurações
VPS_HOST="195.200.1.129"
VPS_USER="root"
SIGNOZ_DIR="/root/docker/signoz"
API_URL="https://api.hmti.com.br"
SIGNOZ_URL="https://signoz.hmti.com.br"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para logging
log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERRO]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[AVISO]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# ============================================================================
# Função: Status do Sistema
# ============================================================================
check_status() {
    log "📊 Verificando Status do Sistema"
    echo "=================================="
    echo ""

    # 1. Status dos Containers
    echo "1️⃣ Status dos Containers:"
    echo ""
    ssh ${VPS_USER}@${VPS_HOST} "cd ${SIGNOZ_DIR} && docker compose ps"
    echo ""

    # 2. Schema do ClickHouse
    echo "2️⃣ Schema do ClickHouse:"
    echo ""
    ssh ${VPS_USER}@${VPS_HOST} << 'ENDSSH'
    echo "   📊 Tabelas por database:"
    docker exec signoz-clickhouse clickhouse-client --query "
        SELECT 
            database,
            count() as total_tables
        FROM system.tables 
        WHERE database IN ('signoz_traces', 'signoz_logs', 'signoz_metrics')
        GROUP BY database
        ORDER BY database
        FORMAT PrettyCompact
    "

    echo ""
    echo "   📋 Tabelas V2/V3/V4:"
    docker exec signoz-clickhouse clickhouse-client --query "
        SELECT 
            database,
            name
        FROM system.tables 
        WHERE database IN ('signoz_traces', 'signoz_logs', 'signoz_metrics')
            AND (name LIKE '%_v2' OR name LIKE '%_v3' OR name LIKE '%_v4%')
        ORDER BY database, name
        FORMAT PrettyCompact
    "
ENDSSH

    echo ""

    # 3. Verificar coluna temporality
    echo "3️⃣ Verificando coluna 'temporality':"
    echo ""
    if ssh ${VPS_USER}@${VPS_HOST} "docker exec signoz-clickhouse clickhouse-client --query \"DESCRIBE signoz_metrics.time_series_v4\" | grep -q temporality"; then
        info "   ✅ Coluna 'temporality' existe"
    else
        error "   ❌ Coluna 'temporality' NÃO existe!"
    fi

    echo ""

    # 4. API do SigNoz
    echo "4️⃣ Testando API do SigNoz:"
    echo ""
    response=$(curl -s ${SIGNOZ_URL}/api/v1/version)
    if [[ $response == *"version"* ]]; then
        info "   ✅ API respondendo: $response"
    else
        error "   ❌ API não respondendo corretamente"
    fi

    echo ""

    # 5. Logs de erro
    echo "5️⃣ Últimos erros do OTel Collector:"
    echo ""
    ssh ${VPS_USER}@${VPS_HOST} "docker logs signoz-otel-collector --tail 10 2>&1 | grep -E '(error|Error|ERROR)' | tail -5 || echo '   ✅ Sem erros recentes'"

    echo ""
}

# ============================================================================
# Função: Corrigir Schema
# ============================================================================
fix_schema() {
    log "🔧 Corrigindo Schema do ClickHouse"
    echo "=================================="
    echo ""

    # 1. Parar serviços dependentes
    echo "1️⃣ Parando serviços temporariamente..."
    ssh ${VPS_USER}@${VPS_HOST} << 'ENDSSH'
cd /root/docker/signoz
docker compose stop signoz-otel-collector signoz-query-service
echo "   ✅ Serviços parados"
ENDSSH

    echo ""

    # 2. Executar migrações
    echo "2️⃣ Executando migrações completas..."
    echo ""

    ssh ${VPS_USER}@${VPS_HOST} << 'ENDSSH'
cd /root/docker/signoz

echo "   🔄 Migração SYNC..."
docker compose run --rm \
    otel-collector-migrator-sync \
    /signoz-schema-migrator \
    --dsn=tcp://clickhouse:9000 \
    sync \
    --up

echo ""
echo "   🔄 Migração ASYNC..."
docker compose run --rm \
    otel-collector-migrator-async \
    /signoz-schema-migrator \
    --dsn=tcp://clickhouse:9000 \
    async \
    --up
ENDSSH

    echo ""

    # 3. Corrigir coluna temporality
    echo "3️⃣ Corrigindo coluna 'temporality'..."
    ssh ${VPS_USER}@${VPS_HOST} << 'ENDSSH'
if ! docker exec signoz-clickhouse clickhouse-client --query "DESCRIBE signoz_metrics.time_series_v4" | grep -q "temporality"; then
    echo "   🔧 Adicionando coluna 'temporality'..."
    docker exec signoz-clickhouse clickhouse-client --query "
        ALTER TABLE signoz_metrics.time_series_v4 
        ADD COLUMN IF NOT EXISTS temporality LowCardinality(String) DEFAULT 'Unspecified'
    "
    docker exec signoz-clickhouse clickhouse-client --query "
        ALTER TABLE signoz_metrics.time_series_v4_1hour 
        ADD COLUMN IF NOT EXISTS temporality LowCardinality(String) DEFAULT 'Unspecified'
    "
    docker exec signoz-clickhouse clickhouse-client --query "
        ALTER TABLE signoz_metrics.time_series_v4_1day 
        ADD COLUMN IF NOT EXISTS temporality LowCardinality(String) DEFAULT 'Unspecified'
    "
    echo "   ✅ Coluna 'temporality' adicionada"
else
    echo "   ✅ Coluna 'temporality' já existe"
fi
ENDSSH

    echo ""

    # 4. Reiniciar serviços
    echo "4️⃣ Reiniciando serviços..."
    ssh ${VPS_USER}@${VPS_HOST} << 'ENDSSH'
cd /root/docker/signoz
docker compose up -d
echo "   ✅ Serviços reiniciados"
ENDSSH

    echo ""
    echo "5️⃣ Aguardando serviços inicializarem..."
    sleep 20

    info "✅ Correção de schema concluída!"
    echo ""
}

# ============================================================================
# Função: Atualizar Configuração OTel Collector
# ============================================================================
update_config() {
    log "⚙️ Atualizando Configuração do OTel Collector"
    echo "=============================================="
    echo ""

    # Criar configuração temporária com exporters corretos para V4
    cat > /tmp/otel-collector-config.yaml << 'EOF'
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

processors:
  batch:
    send_batch_size: 10000
    send_batch_max_size: 11000
    timeout: 10s

exporters:
  clickhousetraces:
    datasource: tcp://clickhouse:9000/signoz_traces
  
  clickhousemetricswritev2:
    dsn: tcp://clickhouse:9000/signoz_metrics
  
  clickhouselogsexporter:
    dsn: tcp://clickhouse:9000/signoz_logs
    timeout: 10s

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [clickhousetraces]
    
    metrics:
      receivers: [otlp]
      processors: [batch]
      exporters: [clickhousemetricswritev2]
    
    logs:
      receivers: [otlp]
      processors: [batch]
      exporters: [clickhouselogsexporter]
EOF

    # Fazer backup e aplicar nova configuração
    echo "1️⃣ Fazendo backup da configuração atual..."
    ssh ${VPS_USER}@${VPS_HOST} "cd ${SIGNOZ_DIR} && cp otel-collector-config.yaml otel-collector-config.yaml.bak"

    echo ""
    echo "2️⃣ Aplicando nova configuração..."
    scp /tmp/otel-collector-config.yaml ${VPS_USER}@${VPS_HOST}:${SIGNOZ_DIR}/otel-collector-config.yaml

    echo ""
    echo "3️⃣ Reiniciando OTel Collector..."
    ssh ${VPS_USER}@${VPS_HOST} "cd ${SIGNOZ_DIR} && docker compose restart signoz-otel-collector"

    echo ""
    echo "4️⃣ Aguardando inicialização..."
    sleep 15

    # Verificar se funcionou
    if ssh ${VPS_USER}@${VPS_HOST} "docker logs signoz-otel-collector --tail 5 2>&1 | grep -q 'Everything is ready'"; then
        info "✅ Configuração aplicada com sucesso!"
    else
        error "❌ Erro na configuração. Verificar logs."
    fi

    rm -f /tmp/otel-collector-config.yaml
    echo ""
}

# ============================================================================
# Função: Testar Traces
# ============================================================================
test_traces() {
    log "🧪 Testando Geração de Traces"
    echo "=============================="
    echo ""

    echo "1️⃣ Reiniciando API para gerar novos traces..."
    ssh ${VPS_USER}@${VPS_HOST} "cd /root/docker && docker compose restart api-teste"

    echo ""
    echo "2️⃣ Aguardando API inicializar..."
    sleep 10

    echo ""
    echo "3️⃣ Gerando trace de teste..."
    response=$(curl -s ${API_URL}/observabilidade/testar)
    if [[ $response == *"traceId"* ]]; then
        trace_id=$(echo $response | grep -o '"traceId":"[^"]*"' | cut -d'"' -f4)
        info "   📊 Trace gerado: $trace_id"
    else
        error "   ❌ Falha ao gerar trace"
        return 1
    fi

    echo ""
    echo "4️⃣ Aguardando processamento..."
    sleep 15

    echo ""
    echo "5️⃣ Verificando se trace chegou ao ClickHouse..."
    count=$(ssh ${VPS_USER}@${VPS_HOST} "docker exec signoz-clickhouse clickhouse-client --query \"SELECT count() FROM signoz_traces.signoz_index_v2 WHERE trace_id = '$trace_id'\" 2>/dev/null || echo 0")
    
    if [[ $count -gt 0 ]]; then
        info "   ✅ Trace encontrado no ClickHouse!"
    else
        error "   ❌ Trace não encontrado no ClickHouse"
    fi

    echo ""
}

# ============================================================================
# Função: Diagnóstico Completo
# ============================================================================
full_diagnosis() {
    log "🔍 Diagnóstico Completo do SigNoz"
    echo "================================="
    echo ""

    check_status
    
    # Verificar se precisa corrigir schema
    if ! ssh ${VPS_USER}@${VPS_HOST} "docker exec signoz-clickhouse clickhouse-client --query \"DESCRIBE signoz_metrics.time_series_v4\" | grep -q temporality"; then
        warning "Schema precisa ser corrigido!"
        echo ""
        fix_schema
    fi

    # Verificar se OTel Collector está com erro
    if ssh ${VPS_USER}@${VPS_HOST} "docker logs signoz-otel-collector --tail 5 2>&1 | grep -q error"; then
        warning "OTel Collector com erros!"
        echo ""
        update_config
    fi

    # Testar traces
    test_traces

    echo ""
    log "📋 Resumo Final:"
    echo "   🔗 SigNoz: ${SIGNOZ_URL}"
    echo "   📊 Traces: ${SIGNOZ_URL}/traces"
    echo "   📋 Logs: ${SIGNOZ_URL}/logs"
    echo ""
    info "✅ Diagnóstico completo finalizado!"
}

# ============================================================================
# Menu Principal
# ============================================================================
show_help() {
    echo "Diagnóstico Completo do SigNoz"
    echo ""
    echo "Uso: bash diagnostico-completo.sh [opção]"
    echo ""
    echo "Opções:"
    echo "  status    - Verificar status geral do sistema"
    echo "  schema    - Corrigir schema do ClickHouse"
    echo "  config    - Atualizar configuração do OTel Collector"
    echo "  test      - Testar geração de traces"
    echo "  full      - Diagnóstico completo (padrão)"
    echo "  help      - Mostrar esta ajuda"
    echo ""
}

# ============================================================================
# Execução Principal
# ============================================================================
case "${1:-full}" in
    "status")
        check_status
        ;;
    "schema")
        fix_schema
        ;;
    "config")
        update_config
        ;;
    "test")
        test_traces
        ;;
    "full")
        full_diagnosis
        ;;
    "help"|"-h"|"--help")
        show_help
        ;;
    *)
        error "Opção inválida: $1"
        echo ""
        show_help
        exit 1
        ;;
esac