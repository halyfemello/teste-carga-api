#!/bin/bash

# ============================================================================
# Script de Inicialização do Schema do SigNoz
# ============================================================================
# Versão: 1.0
# Compatível com: SigNoz 0.64.0+ / OTel Collector 0.111.16+
# 
# Este script cria o schema completo do SigNoz no ClickHouse usando
# o signoz-schema-migrator oficial, garantindo compatibilidade total
# com as versões mais recentes do SigNoz.
#
# Uso:
#   bash infra/signoz/inicializar-schema-signoz.sh
#
# Pré-requisitos:
#   - Docker instalado e em execução
#   - ClickHouse rodando e acessível
#   - Rede Docker configurada
# ============================================================================

set -e

echo "🚀 Inicializando Schema do SigNoz..."
echo ""

# Configurações
VPS_HOST="195.200.1.129"
VPS_USER="root"
SIGNOZ_DIR="/root/docker/signoz"
CLICKHOUSE_DSN="tcp://clickhouse:9000"

echo "📋 Configuração:"
echo "   • VPS: ${VPS_USER}@${VPS_HOST}"
echo "   • Diretório: ${SIGNOZ_DIR}"
echo "   • ClickHouse DSN: ${CLICKHOUSE_DSN}"
echo ""

# ============================================================================
# Etapa 1: Verificar se ClickHouse está rodando
# ============================================================================
echo "1️⃣ Verificando se ClickHouse está rodando..."
if ssh ${VPS_USER}@${VPS_HOST} "cd ${SIGNOZ_DIR} && docker compose ps clickhouse | grep -q 'Up'"; then
    echo "   ✅ ClickHouse está rodando"
else
    echo "   ❌ ClickHouse não está rodando!"
    echo "   Execute: ssh ${VPS_USER}@${VPS_HOST} 'cd ${SIGNOZ_DIR} && docker compose up -d clickhouse'"
    exit 1
fi
echo ""

# ============================================================================
# Etapa 2: Executar Migração SYNC (Schema Base)
# ============================================================================
echo "2️⃣ Executando migração SYNC (schema base)..."
echo "   Esta etapa cria todas as tabelas necessárias..."
echo ""

ssh ${VPS_USER}@${VPS_HOST} << 'ENDSSH'
cd /root/docker/signoz

# Executar migração sync
docker compose run --rm \
    -e DEPLOYMENT_TYPE=docker-standalone-amd \
    otel-collector-migrator-sync \
    /signoz-schema-migrator \
    --dsn=tcp://clickhouse:9000 \
    sync \
    --up

echo ""
echo "   ✅ Migração SYNC concluída"
ENDSSH

echo ""

# ============================================================================
# Etapa 3: Executar Migração ASYNC (Índices e Otimizações)
# ============================================================================
echo "3️⃣ Executando migração ASYNC (índices e otimizações)..."
echo "   Esta etapa cria índices e otimizações..."
echo ""

ssh ${VPS_USER}@${VPS_HOST} << 'ENDSSH'
cd /root/docker/signoz

# Executar migração async
docker compose run --rm \
    -e DEPLOYMENT_TYPE=docker-standalone-amd \
    otel-collector-migrator-async \
    /signoz-schema-migrator \
    --dsn=tcp://clickhouse:9000 \
    async \
    --up

echo ""
echo "   ✅ Migração ASYNC concluída"
ENDSSH

echo ""

# ============================================================================
# Etapa 4: Verificar Schema Criado
# ============================================================================
echo "4️⃣ Verificando schema criado no ClickHouse..."
echo ""

ssh ${VPS_USER}@${VPS_HOST} << 'ENDSSH'
docker exec signoz-clickhouse clickhouse-client --query "
    SELECT 
        database,
        name as table_name,
        engine,
        total_rows,
        formatReadableSize(total_bytes) as size
    FROM system.tables 
    WHERE database IN ('signoz_traces', 'signoz_logs', 'signoz_metrics')
    ORDER BY database, name
    FORMAT PrettyCompact
"
ENDSSH

echo ""

# ============================================================================
# Etapa 5: Validar Tabelas Críticas
# ============================================================================
echo "5️⃣ Validando tabelas críticas..."
echo ""

REQUIRED_TABLES=(
    "signoz_traces.distributed_signoz_index_v2"
    "signoz_traces.distributed_tag_attributes_v2"
    "signoz_logs.distributed_logs_v2"
    "signoz_logs.distributed_tag_attributes_v2"
    "signoz_metrics.time_series_v4"
    "signoz_metrics.distributed_time_series_v4"
)

for table in "${REQUIRED_TABLES[@]}"; do
    if ssh ${VPS_USER}@${VPS_HOST} "docker exec signoz-clickhouse clickhouse-client --query \"EXISTS ${table}\" 2>/dev/null | grep -q 1"; then
        echo "   ✅ ${table}"
    else
        echo "   ⚠️  ${table} - NÃO ENCONTRADA"
    fi
done

echo ""

# ============================================================================
# Etapa 6: Exibir Resumo
# ============================================================================
echo "6️⃣ Resumo da inicialização:"
echo ""

ssh ${VPS_USER}@${VPS_HOST} << 'ENDSSH'
echo "   📊 Estatísticas por database:"
docker exec signoz-clickhouse clickhouse-client --query "
    SELECT 
        database,
        count() as total_tables,
        sum(total_rows) as total_rows,
        formatReadableSize(sum(total_bytes)) as total_size
    FROM system.tables 
    WHERE database IN ('signoz_traces', 'signoz_logs', 'signoz_metrics')
    GROUP BY database
    ORDER BY database
    FORMAT PrettyCompact
"
ENDSSH

echo ""
echo "✅ Schema do SigNoz inicializado com sucesso!"
echo ""
echo "📝 Próximos passos:"
echo "   1. Verifique se os serviços do SigNoz estão rodando:"
echo "      ssh ${VPS_USER}@${VPS_HOST} 'cd ${SIGNOZ_DIR} && docker compose ps'"
echo ""
echo "   2. Inicie os serviços se necessário:"
echo "      ssh ${VPS_USER}@${VPS_HOST} 'cd ${SIGNOZ_DIR} && docker compose up -d'"
echo ""
echo "   3. Acesse a interface do SigNoz:"
echo "      https://signoz.hmti.com.br"
echo ""
