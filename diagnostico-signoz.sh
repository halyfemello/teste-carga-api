#!/bin/bash

echo "🔍 Diagnóstico detalhado do OpenTelemetry..."
echo ""

# 1. Ver logs de inicialização da API
echo "1️⃣ Logs de inicialização da API (procurando config OpenTelemetry)..."
ssh root@195.200.1.129 "docker logs api-teste 2>&1 | grep -A 2 -B 2 'OpenTelemetry\|OTLP\|🔧'"
echo ""

# 2. Gerar trace e ver logs em tempo real
echo "2️⃣ Gerando trace e monitorando collector..."
ssh root@195.200.1.129 "docker logs signoz-otel-collector --tail 50 --follow &
COLLECTOR_PID=\$!
sleep 2
curl -s https://app.hmti.com.br/api/Observabilidade/trace-simples > /dev/null
sleep 3
kill \$COLLECTOR_PID 2>/dev/null
" 2>&1 | grep -E "ResourceSpans|testecarga|error|received|export" | head -30

echo ""
echo "3️⃣ Verificando erros no collector..."
ssh root@195.200.1.129 "docker logs signoz-otel-collector --tail 100 2>&1 | grep -i error | tail -10"

echo ""
echo "✅ Diagnóstico concluído!"
