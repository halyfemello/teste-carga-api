#!/bin/bash

VPS_USER="root"
VPS_HOST="195.200.1.129"
SIGNOZ_PATH="/root/docker/signoz"

case "$1" in
  start)
    echo "🚀 Iniciando SigNoz na VPS..."
    ssh $VPS_USER@$VPS_HOST << EOF
      cd $SIGNOZ_PATH
      docker compose up -d
      echo "✅ SigNoz iniciado!"
      echo "📊 Acesse: http://$VPS_HOST:3301"
EOF
    ;;
    
  stop)
    echo "🛑 Parando SigNoz na VPS..."
    ssh $VPS_USER@$VPS_HOST << EOF
      cd $SIGNOZ_PATH
      docker compose down
      echo "✅ SigNoz parado!"
EOF
    ;;
    
  restart)
    echo "🔄 Reiniciando SigNoz na VPS..."
    ssh $VPS_USER@$VPS_HOST << EOF
      cd $SIGNOZ_PATH
      docker compose restart
      echo "✅ SigNoz reiniciado!"
EOF
    ;;
    
  logs)
    echo "📋 Mostrando logs do SigNoz..."
    ssh $VPS_USER@$VPS_HOST << EOF
      cd $SIGNOZ_PATH
      docker compose logs -f --tail=100
EOF
    ;;
    
  status)
    echo "📊 Status dos containers do SigNoz..."
    ssh $VPS_USER@$VPS_HOST << EOF
      cd $SIGNOZ_PATH
      docker compose ps
EOF
    ;;
    
  setup)
    echo "⚙️ Configurando SigNoz pela primeira vez..."
    
    echo "📦 Enviando configurações para VPS..."
    ssh $VPS_USER@$VPS_HOST "mkdir -p $SIGNOZ_PATH"
    scp infra/signoz/* $VPS_USER@$VPS_HOST:$SIGNOZ_PATH/
    
    echo "🚀 Subindo SigNoz..."
    ssh $VPS_USER@$VPS_HOST << EOF
      cd $SIGNOZ_PATH
      docker compose pull
      docker compose up -d
      echo ""
      echo "✅ SigNoz configurado e rodando!"
      echo ""
      echo "📊 Acesse o dashboard em: http://$VPS_HOST:3301"
      echo "🔧 Endpoint OTLP: http://$VPS_HOST:4317 (gRPC) e http://$VPS_HOST:4318 (HTTP)"
      echo ""
      echo "⏳ Aguarde 1-2 minutos para todos os serviços iniciarem completamente."
EOF
    ;;
    
  update)
    echo "🔄 Atualizando configurações do SigNoz..."
    echo "📦 Removendo arquivos antigos da VPS..."
    ssh $VPS_USER@$VPS_HOST "rm -rf $SIGNOZ_PATH/*"
    
    echo "📤 Enviando arquivos atualizados..."
    scp infra/signoz/* $VPS_USER@$VPS_HOST:$SIGNOZ_PATH/
    
    echo "🔄 Reiniciando serviços..."
    ssh $VPS_USER@$VPS_HOST << EOF
      cd $SIGNOZ_PATH
      docker compose down
      docker compose up -d
      echo "✅ Configurações atualizadas!"
EOF
    ;;
    
  clean)
    echo "🧹 Removendo dados antigos do SigNoz (cuidado!)..."
    read -p "Tem certeza? Isso apagará TODOS os dados! (yes/no): " -r
    if [[ $REPLY == "yes" ]]; then
      ssh $VPS_USER@$VPS_HOST << EOF
        cd $SIGNOZ_PATH
        docker compose down -v
        echo "✅ Dados removidos!"
EOF
    else
      echo "❌ Operação cancelada."
    fi
    ;;
    
  *)
    echo "🔧 Gerenciador do SigNoz"
    echo ""
    echo "Uso: ./signoz.sh [comando]"
    echo ""
    echo "Comandos disponíveis:"
    echo "  setup     - Configurar e subir o SigNoz pela primeira vez"
    echo "  start     - Iniciar o SigNoz"
    echo "  stop      - Parar o SigNoz"
    echo "  restart   - Reiniciar o SigNoz"
    echo "  status    - Ver status dos containers"
    echo "  logs      - Ver logs em tempo real"
    echo "  update    - Atualizar configurações"
    echo "  clean     - Remover todos os dados (cuidado!)"
    echo ""
    echo "Exemplo: ./signoz.sh setup"
    ;;
esac
