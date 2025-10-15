#!/bin/bash

echo "🔍 Testando conectividade do SigNoz..."
echo ""

# 1. Verificar se os containers estão rodando
echo "1️⃣ Verificando containers..."
ssh root@195.200.1.129 "docker ps | grep -E 'api-teste|signoz-otel-collector'" || echo "❌ Containers não encontrados"
echo ""

# 2. Verificar se a API está na rede web
echo "2️⃣ Verificando rede da API..."
ssh root@195.200.1.129 "docker inspect api-teste | grep -A 3 '\"web\"'" || echo "❌ API não está na rede web"
echo ""

# 3. Verificar variáveis de ambiente da API
echo "3️⃣ Verificando variáveis OpenTelemetry na API..."
ssh root@195.200.1.129 "docker exec api-teste env | grep OTEL" || echo "❌ Variáveis OTEL não encontradas"
echo ""

# 4. Testar conectividade DNS
echo "4️⃣ Testando resolução DNS do collector..."
ssh root@195.200.1.129 "docker exec api-teste getent hosts signoz-otel-collector" || echo "❌ DNS não resolve"
echo ""

# 5. Gerar um trace de teste
echo "5️⃣ Gerando trace de teste..."
curl -s https://app.hmti.com.br/api/Observabilidade/trace-simples | grep -o '"traceId":"[^"]*"' || echo "❌ Endpoint não respondeu"
echo ""

# 6. Verificar logs do collector
echo "6️⃣ Logs recentes do OTel Collector (últimas 20 linhas)..."
ssh root@195.200.1.129 "docker logs signoz-otel-collector --tail 20 2>&1" | grep -E "ResourceSpans|testecarga|error" || echo "⚠️ Nenhum trace detectado ainda"
echo ""

# 7. Verificar logs da API
echo "7️⃣ Logs recentes da API (últimas 10 linhas)..."
ssh root@195.200.1.129 "docker logs api-teste --tail 10 2>&1"
echo ""

echo "✅ Teste concluído!"
echo ""
echo "📊 Próximos passos:"
echo "   1. Aguarde 30 segundos"
echo "   2. Acesse: https://signoz.hmti.com.br/traces"
echo "   3. Filtre por serviço: testecarga-api-dev"
echo "   4. Se não aparecer, execute novamente: bash testar-signoz.sh"
