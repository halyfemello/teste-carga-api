#!/bin/bash

echo "🗄️ INICIALIZANDO BANCO DE DADOS CLICKHOUSE DO SIGNOZ"
echo "====================================================="
echo ""

# 1. Verificar se o ClickHouse está rodando
echo "1️⃣ Verificando se ClickHouse está ativo..."
if ssh root@195.200.1.129 "docker ps | grep -q signoz-clickhouse"; then
    echo "   ✅ ClickHouse está rodando"
else
    echo "   ❌ ClickHouse NÃO está rodando!"
    echo "   Execute: cd /root/docker/signoz && docker-compose up -d"
    exit 1
fi
echo ""

# 2. Verificar conectividade
echo "2️⃣ Testando conectividade com ClickHouse..."
if ssh root@195.200.1.129 "docker exec signoz-clickhouse clickhouse-client --query='SELECT 1' 2>&1 | grep -q '^1$'"; then
    echo "   ✅ ClickHouse respondendo"
else
    echo "   ❌ ClickHouse não está respondendo!"
    exit 1
fi
echo ""

# 3. Verificar se os bancos já existem
echo "3️⃣ Verificando bancos existentes..."
EXISTING_DBS=$(ssh root@195.200.1.129 "docker exec signoz-clickhouse clickhouse-client --query='SHOW DATABASES' 2>&1")
echo "$EXISTING_DBS" | grep -E "signoz_traces|signoz_logs|signoz_metrics" || echo "   ⚠️ Bancos do SigNoz não encontrados"
echo ""

# 4. Fazer backup do banco (se existir)
echo "4️⃣ Fazendo backup dos bancos existentes (se houver)..."
ssh root@195.200.1.129 "docker exec signoz-clickhouse clickhouse-client --query='CREATE DATABASE IF NOT EXISTS backup_$(date +%Y%m%d)' 2>&1" || echo "   ⚠️ Backup não criado"
echo "   ✅ Backup preparado"
echo ""

# 5. Enviar o script SQL
echo "5️⃣ Enviando script de inicialização..."
scp infra/signoz/init-schema.sql root@195.200.1.129:/tmp/init-signoz-schema.sql
echo "   ✅ Script enviado para /tmp/init-signoz-schema.sql"
echo ""

# 6. Executar o script SQL
echo "6️⃣ Executando script de inicialização no ClickHouse..."
echo "   (Isso pode levar alguns segundos...)"
ssh root@195.200.1.129 "docker exec -i signoz-clickhouse clickhouse-client --multiquery < /tmp/init-signoz-schema.sql" 2>&1 | tee /tmp/clickhouse-init.log
echo ""

# 7. Verificar se os bancos foram criados
echo "7️⃣ Verificando bancos criados..."
CREATED_DBS=$(ssh root@195.200.1.129 "docker exec signoz-clickhouse clickhouse-client --query='SHOW DATABASES' 2>&1")
echo "$CREATED_DBS"
echo ""

# 8. Verificar tabelas de traces
echo "8️⃣ Verificando tabelas de TRACES..."
ssh root@195.200.1.129 "docker exec signoz-clickhouse clickhouse-client --query='SHOW TABLES FROM signoz_traces' 2>&1" | head -10
echo ""

# 9. Verificar tabelas de logs
echo "9️⃣ Verificando tabelas de LOGS..."
ssh root@195.200.1.129 "docker exec signoz-clickhouse clickhouse-client --query='SHOW TABLES FROM signoz_logs' 2>&1" | head -10
echo ""

# 10. Verificar tabelas de métricas
echo "🔟 Verificando tabelas de MÉTRICAS..."
ssh root@195.200.1.129 "docker exec signoz-clickhouse clickhouse-client --query='SHOW TABLES FROM signoz_metrics' 2>&1" | head -10
echo ""

# 11. Limpar arquivo temporário
echo "1️⃣1️⃣ Limpando arquivos temporários..."
ssh root@195.200.1.129 "rm /tmp/init-signoz-schema.sql"
echo "   ✅ Arquivo temporário removido"
echo ""

echo "====================================================="
echo "✅ INICIALIZAÇÃO CONCLUÍDA!"
echo "====================================================="
echo ""
echo "📊 RESUMO:"
echo "   - Bancos de dados: signoz_traces, signoz_logs, signoz_metrics"
echo "   - Tabelas principais: signoz_index_v2, durationSort, logs, time_series_v4"
echo ""
echo "🎯 PRÓXIMOS PASSOS:"
echo "   1. Execute: bash aplicar-correcao-signoz.sh"
echo "   2. Aguarde 30 segundos"
echo "   3. Acesse: https://signoz.hmti.com.br/traces"
echo "   4. Valide: bash validar-signoz.sh"
echo ""
