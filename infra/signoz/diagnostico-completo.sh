#!/bin/bash

# ============================================================================
# Diagnóstico Completo do SigNoz - Script Central
# ============================================================================
# Versão: 3.0
# Compatível com: SigNoz v0.97.0 / OTel Collector v0.129.7 (Instalação Oficial)
# 
# Este é o ÚNICO script necessário para diagnosticar, corrigir e testar
# todo o ambiente SigNoz. Consolida todas as funcionalidades em um só lugar.
#
# Uso:
#   bash diagnostico-completo.sh [opção]
#
# Opções:
#   status      - Verificar status geral do sistema
#   logs        - Ver logs dos containers
#   restart     - Reiniciar todos os serviços
#   test        - Testar geração de traces da API
#   full        - Diagnóstico completo (padrão)
# ============================================================================

set -e

# Configurações
VPS_HOST="195.200.1.129"
VPS_USER="root"
SIGNOZ_DIR="/root/signoz/deploy/docker"
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

    # 2. Verificar Redes
    echo "2️⃣ Verificando Redes Docker:"
    echo ""
    ssh ${VPS_USER}@${VPS_HOST} << 'ENDSSH'
    echo "   🌐 Rede web:"
    docker network inspect web --format '{{.Name}}: {{len .Containers}} containers' 2>/dev/null || echo "   ❌ Rede web não encontrada"
    
    echo "   🌐 Rede signoz-net:"
    docker network inspect signoz-net --format '{{.Name}}: {{len .Containers}} containers' 2>/dev/null || echo "   ❌ Rede signoz-net não encontrada"
ENDSSH

    echo ""

    # 3. Schema do ClickHouse
    echo "3️⃣ Schema do ClickHouse:"
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
    " 2>/dev/null || echo "   ⚠️  Não foi possível acessar o ClickHouse"
ENDSSH

    echo ""

    # 4. Health Check dos Serviços
    echo "4️⃣ Health Check dos Serviços:"
    echo ""
    
    # SigNoz Frontend/Backend
    response=$(curl -s -o /dev/null -w "%{http_code}" ${SIGNOZ_URL} 2>/dev/null || echo "000")
    if [[ $response == "200" ]]; then
        info "   ✅ SigNoz Frontend: OK ($response)"
    else
        error "   ❌ SigNoz Frontend: FALHOU ($response)"
    fi
    
    # SigNoz API
    response=$(curl -s ${SIGNOZ_URL}/api/v1/version 2>/dev/null || echo "error")
    if [[ $response == *"version"* ]]; then
        version=$(echo $response | grep -o '"version":"[^"]*"' | cut -d'"' -f4)
        info "   ✅ SigNoz API: OK (versão: $version)"
    else
        error "   ❌ SigNoz API: não respondendo"
    fi

    echo ""

    # 5. Verificar OTel Collector
    echo "5️⃣ Status do OTel Collector:"
    echo ""
    collector_status=$(ssh ${VPS_USER}@${VPS_HOST} "docker inspect signoz-otel-collector --format '{{.State.Status}}' 2>/dev/null" || echo "não encontrado")
    
    if [[ $collector_status == "running" ]]; then
        info "   ✅ OTel Collector: Rodando"
        
        # Verificar portas
        ports=$(ssh ${VPS_USER}@${VPS_HOST} "docker port signoz-otel-collector 2>/dev/null" || echo "")
        if [[ $ports == *"4317"* ]] && [[ $ports == *"4318"* ]]; then
            info "   ✅ Portas OTLP expostas (4317 gRPC, 4318 HTTP)"
        else
            warning "   ⚠️  Portas OTLP podem não estar expostas"
        fi
        
        # Verificar últimos erros
        errors=$(ssh ${VPS_USER}@${VPS_HOST} "docker logs signoz-otel-collector --tail 20 2>&1 | grep -i error | wc -l")
        if [[ $errors -eq 0 ]]; then
            info "   ✅ Sem erros recentes nos logs"
        else
            warning "   ⚠️  Encontrados $errors erros nos logs recentes"
        fi
    else
        error "   ❌ OTel Collector: $collector_status"
    fi

    echo ""
}

# ============================================================================
# Função: Ver Logs
# ============================================================================
view_logs() {
    log "� Visualizando Logs dos Containers"
    echo "===================================="
    echo ""
    
    echo "Escolha qual log deseja ver:"
    echo "1) signoz (backend/frontend)"
    echo "2) signoz-otel-collector"
    echo "3) signoz-clickhouse"
    echo "4) signoz-zookeeper-1"
    echo "5) Todos (últimas 20 linhas de cada)"
    echo ""
    
    read -p "Opção (1-5): " opcao
    
    case $opcao in
        1)
            ssh ${VPS_USER}@${VPS_HOST} "docker logs signoz --tail 50 -f"
            ;;
        2)
            ssh ${VPS_USER}@${VPS_HOST} "docker logs signoz-otel-collector --tail 50 -f"
            ;;
        3)
            ssh ${VPS_USER}@${VPS_HOST} "docker logs signoz-clickhouse --tail 50 -f"
            ;;
        4)
            ssh ${VPS_USER}@${VPS_HOST} "docker logs signoz-zookeeper-1 --tail 50 -f"
            ;;
        5)
            echo ""
            echo "=== SIGNOZ ==="
            ssh ${VPS_USER}@${VPS_HOST} "docker logs signoz --tail 20 2>&1"
            echo ""
            echo "=== OTEL COLLECTOR ==="
            ssh ${VPS_USER}@${VPS_HOST} "docker logs signoz-otel-collector --tail 20 2>&1"
            echo ""
            echo "=== CLICKHOUSE ==="
            ssh ${VPS_USER}@${VPS_HOST} "docker logs signoz-clickhouse --tail 20 2>&1"
            echo ""
            echo "=== ZOOKEEPER ==="
            ssh ${VPS_USER}@${VPS_HOST} "docker logs signoz-zookeeper-1 --tail 20 2>&1"
            ;;
        *)
            error "Opção inválida!"
            ;;
    esac
}

# ============================================================================
# Função: Reiniciar Serviços
# ============================================================================
restart_services() {
    log "🔄 Reiniciando Serviços do SigNoz"
    echo "=================================="
    echo ""

    echo "1️⃣ Parando todos os containers..."
    ssh ${VPS_USER}@${VPS_HOST} "cd ${SIGNOZ_DIR} && docker compose down"

    echo ""
    echo "2️⃣ Aguardando containers pararem..."
    sleep 5

    echo ""
    echo "3️⃣ Iniciando todos os containers..."
    ssh ${VPS_USER}@${VPS_HOST} "cd ${SIGNOZ_DIR} && docker compose up -d"

    echo ""
    echo "4️⃣ Aguardando inicialização (30 segundos)..."
    sleep 30

    echo ""
    echo "5️⃣ Verificando status..."
    ssh ${VPS_USER}@${VPS_HOST} "cd ${SIGNOZ_DIR} && docker compose ps"

    echo ""
    info "✅ Serviços reiniciados!"
    echo ""
}

# ============================================================================
# Função: Testar Traces
# ============================================================================
test_traces() {
    log "🧪 Testando Geração e Envio de Traces"
    echo "======================================"
    echo ""

    # Verificar se a API está rodando
    echo "1️⃣ Verificando se a API está rodando..."
    api_status=$(ssh ${VPS_USER}@${VPS_HOST} "docker inspect api-teste --format '{{.State.Status}}' 2>/dev/null" || echo "não encontrado")
    
    if [[ $api_status != "running" ]]; then
        warning "   ⚠️  API não está rodando. Iniciando..."
        ssh ${VPS_USER}@${VPS_HOST} "cd /root/docker && docker compose up -d api-teste"
        sleep 10
    else
        info "   ✅ API está rodando"
    fi

    echo ""
    echo "2️⃣ Verificando conectividade da API com o SigNoz..."
    
    # Verificar se a API está na mesma rede que o OTel Collector
    api_networks=$(ssh ${VPS_USER}@${VPS_HOST} "docker inspect api-teste --format '{{range \$k, \$v := .NetworkSettings.Networks}}{{println \$k}}{{end}}' 2>/dev/null" || echo "")
    
    if [[ $api_networks == *"web"* ]]; then
        info "   ✅ API está na rede 'web'"
    else
        error "   ❌ API NÃO está na rede 'web'"
    fi
    
    if [[ $api_networks == *"signoz-net"* ]]; then
        info "   ✅ API está na rede 'signoz-net'"
    else
        warning "   ⚠️  API não está na rede 'signoz-net' (opcional, mas recomendado)"
    fi

    echo ""
    echo "3️⃣ Testando endpoint da API..."
    api_response=$(curl -s -o /dev/null -w "%{http_code}" ${API_URL}/health 2>/dev/null || curl -s -o /dev/null -w "%{http_code}" ${API_URL}/ 2>/dev/null || echo "000")
    
    if [[ $api_response == "200" ]] || [[ $api_response == "404" ]]; then
        info "   ✅ API respondendo (HTTP $api_response)"
    else
        error "   ❌ API não está respondendo corretamente (HTTP $api_response)"
        return 1
    fi

    echo ""
    echo "4️⃣ Gerando requisições para criar traces..."
    
    # Fazer várias requisições para garantir que traces sejam gerados
    for i in {1..5}; do
        echo "   📡 Requisição $i/5..."
        curl -s -X GET ${API_URL}/ > /dev/null 2>&1 &
        sleep 1
    done
    
    wait
    info "   ✅ 5 requisições enviadas"

    echo ""
    echo "5️⃣ Aguardando processamento dos traces (20 segundos)..."
    sleep 20

    echo ""
    echo "6️⃣ Verificando traces no ClickHouse..."
    
    # Buscar traces recentes (últimos 5 minutos)
    trace_count=$(ssh ${VPS_USER}@${VPS_HOST} "docker exec signoz-clickhouse clickhouse-client --query \"SELECT count() FROM signoz_traces.signoz_index_v2 WHERE timestamp >= now() - INTERVAL 5 MINUTE\" 2>/dev/null" || echo "0")
    
    if [[ $trace_count -gt 0 ]]; then
        info "   ✅ Encontrados $trace_count traces recentes no ClickHouse!"
        
        echo ""
        echo "   📊 Últimos 5 traces:"
        ssh ${VPS_USER}@${VPS_HOST} "docker exec signoz-clickhouse clickhouse-client --query \"
            SELECT 
                trace_id,
                service_name,
                name,
                timestamp
            FROM signoz_traces.signoz_index_v2 
            WHERE timestamp >= now() - INTERVAL 5 MINUTE
            ORDER BY timestamp DESC
            LIMIT 5
            FORMAT PrettyCompact
        \" 2>/dev/null" || echo "   ⚠️  Não foi possível listar os traces"
    else
        error "   ❌ Nenhum trace encontrado nos últimos 5 minutos"
        
        echo ""
        warning "   🔍 Verificando logs do OTel Collector para possíveis erros..."
        ssh ${VPS_USER}@${VPS_HOST} "docker logs signoz-otel-collector --tail 10 2>&1 | grep -i error" || echo "   ℹ️  Sem erros aparentes nos logs"
    fi

    echo ""
    echo "7️⃣ Verificando métricas no ClickHouse..."
    metric_count=$(ssh ${VPS_USER}@${VPS_HOST} "docker exec signoz-clickhouse clickhouse-client --query \"SELECT count() FROM signoz_metrics.samples_v4 WHERE unix_milli >= (toUnixTimestamp(now()) - 300) * 1000\" 2>/dev/null" || echo "0")
    
    if [[ $metric_count -gt 0 ]]; then
        info "   ✅ Encontradas $metric_count métricas recentes!"
    else
        warning "   ⚠️  Nenhuma métrica encontrada nos últimos 5 minutos"
    fi

    echo ""
    info "📋 Resumo do Teste:"
    echo "   🔗 Acesse o SigNoz: ${SIGNOZ_URL}"
    echo "   📊 Vá para: Services → APM → Traces"
    echo "   🔍 Filtro sugerido: Últimos 5 minutos"
    echo ""
}

# ============================================================================
# Função: Diagnóstico Completo
# ============================================================================
full_diagnosis() {
    log "🔍 Diagnóstico Completo do SigNoz"
    echo "================================="
    echo ""

    # Verificar status geral
    check_status
    
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    
    # Testar traces da API
    test_traces

    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    log "📋 Resumo Final:"
    echo "   🔗 SigNoz Dashboard: ${SIGNOZ_URL}"
    echo "   📊 Traces: ${SIGNOZ_URL}/services"
    echo "   📈 Metrics: ${SIGNOZ_URL}/metrics"
    echo "   📋 Logs: ${SIGNOZ_URL}/logs"
    echo "   🔧 Alerts: ${SIGNOZ_URL}/alerts"
    echo ""
    echo "   📡 Endpoints OTLP:"
    echo "      - gRPC: ${VPS_HOST}:4317"
    echo "      - HTTP: ${VPS_HOST}:4318"
    echo ""
    info "✅ Diagnóstico completo finalizado!"
    echo ""
}

# ============================================================================
# Menu Principal
# ============================================================================
show_help() {
    echo "════════════════════════════════════════════════════════════════"
    echo "  🔍 Diagnóstico Completo do SigNoz (Instalação Oficial)"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    echo "Uso: bash diagnostico-completo.sh [opção]"
    echo ""
    echo "Opções:"
    echo "  status    - Verificar status geral do sistema"
    echo "  logs      - Ver logs dos containers (interativo)"
    echo "  restart   - Reiniciar todos os serviços do SigNoz"
    echo "  test      - Testar geração e envio de traces da API"
    echo "  full      - Diagnóstico completo (padrão)"
    echo "  help      - Mostrar esta ajuda"
    echo ""
    echo "Exemplos:"
    echo "  bash diagnostico-completo.sh status"
    echo "  bash diagnostico-completo.sh test"
    echo "  bash diagnostico-completo.sh"
    echo ""
    echo "Informações:"
    echo "  VPS: ${VPS_HOST}"
    echo "  SigNoz: ${SIGNOZ_URL}"
    echo "  API: ${API_URL}"
    echo ""
}

# ============================================================================
# Execução Principal
# ============================================================================
case "${1:-full}" in
    "status")
        check_status
        ;;
    "logs")
        view_logs
        ;;
    "restart")
        restart_services
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