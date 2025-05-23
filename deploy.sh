#!/bin/bash

PROJECT_NAME="minhaapi"
IMAGE_NAME="minhaapi:latest"
TAR_FILE="minhaapi.tar"
VPS_USER="root"
VPS_HOST="195.200.1.129"
VPS_DEST="/root"

echo "🔨 Buildando imagem Docker local..."
docker build -t $IMAGE_NAME -f Dockerfile .

echo "📦 Salvando imagem local em $TAR_FILE..."
docker save -o $TAR_FILE $IMAGE_NAME

echo "🚀 Enviando arquivos para VPS..."
scp $TAR_FILE $VPS_USER@$VPS_HOST:$VPS_DEST
scp docker-compose.yml $VPS_USER@$VPS_HOST:$VPS_DEST

echo "🔁 Executando deploy remoto via SSH..."
ssh $VPS_USER@$VPS_HOST << EOF
  set -e
  echo "🛑 Parando e removendo container antigo (se existir)..."
  docker stop api-teste || true
  docker rm api-teste || true

  echo "🧼 Removendo imagem antiga..."
  docker rmi -f minhaapi:latest || true

  echo "♻️ Carregando nova imagem..."
  docker load -i $TAR_FILE

  echo "📦 Subindo com docker-compose..."
  docker compose -f docker-compose.yml up -d

  echo "✅ Deploy concluído na VPS!"
EOF

echo "🧹 Limpando imagem exportada localmente..."
rm $TAR_FILE

echo "✅ Tudo feito com sucesso!"
