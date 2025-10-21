#!/bin/bash

# ============================================
# Deploy SigNoz para VPS
# ============================================

SERVICE_NAME="signoz"
VPS_USER="root"
VPS_HOST="195.200.1.129"
VPS_DEST="/root/signoz/deploy/docker"

echo "🚀 Iniciando deploy do $SERVICE_NAME para VPS..."

echo "📁 Criando diretório remoto se não existir..."
ssh $VPS_USER@$VPS_HOST "mkdir -p $VPS_DEST"

echo "🛑 Parando containers existentes..."
ssh $VPS_USER@$VPS_HOST "cd $VPS_DEST && docker compose down" || echo "Nenhum container rodando"

echo "📤 Enviando arquivos de configuração..."
scp docker-compose.override.yaml $VPS_USER@$VPS_HOST:$VPS_DEST/
scp docker-compose.yaml $VPS_USER@$VPS_HOST:$VPS_DEST/
scp otel-collector-config.yaml $VPS_USER@$VPS_HOST:$VPS_DEST/

echo "🔧 Executando deploy remoto via SSH..."
ssh $VPS_USER@$VPS_HOST << 'EOF'
  set -e
  cd /root/signoz/deploy/docker
  
  echo "🌐 Verificando se rede 'infra' existe..."
  docker network create infra 2>/dev/null || echo "Rede 'infra' já existe"
  
  echo "🔄 Aplicando configurações..."
  docker compose up -d
  
  echo "✅ SigNoz rodando!"
  docker ps | grep signoz
EOF

echo "🎉 Deploy do $SERVICE_NAME concluído com sucesso!"
