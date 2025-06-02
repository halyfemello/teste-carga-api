# Projeto para realizar teste de grande volume "carga"

- Rodar o teste com o k6

# Executar

- k6 run teste.js

# Docker comandos rapidos

🐋 Verificar se a Imagem foi Carregada

docker images

🔍 Como verificar os containers rodando?

docker ps -a

🧼 Remover a imagem Docker

- Se o container estiver ativo, pare ele:
  docker stop api-teste
  docker rm api-teste

- Agora remova a imagem:
  docker rmi minhaapi:latest

# Criar um certificado para ssh no windows para fazer o deploy sem senha

✅ O que você pode fazer agora
✅ 🔐 Opção recomendada (sem senha): usar chave SSH
Essa é a mais segura, automatizável e compatível com Windows (Git Bash, PowerShell, etc).

🧰 Passo a passo completo:

1. Gerar uma chave SSH no Git Bash:
   bash
   Copiar
   Editar
   ssh-keygen -t rsa -b 4096 -C "seu@email.com"
   Quando pedir caminho para salvar, pressione ENTER.

Quando pedir senha, deixe em branco (só ENTER).

Isso vai gerar:

~/.ssh/id_rsa → chave privada

~/.ssh/id_rsa.pub → chave pública

2. Enviar a chave para sua VPS (substitua o IP)
   bash
   Copiar
   Editar
   cat ~/.ssh/id_rsa.pub | ssh root@VPS_IP "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
   Vai pedir sua senha da VPS uma última vez.

3. Teste se funciona sem senha:
   bash
   Copiar
   Editar
   ssh root@VPS_IP
   Se conectar direto ✅, está pronto!

# ==============================================================================

# Estrutura de infra pra vps com deploy via docker

# ==============================================================================

├── infra/
│ └── dev/
│ └── docker-compose.yml # Apenas serviços de infra (MongoDB, Portainer, n8n)
├── services/
│ └── minhaapi/
│ ├── docker-compose.yml # Compose da aplicação em si (minhaapi)
│ └── minhaapi.tar # Imagem exportada (ou código da API)
├── shared/
│ ├── mongodb/
│ │ └── data/ # Volume do MongoDB
│ └── .env # Arquivo .env comum, se necessário
└── deploy.sh (opcional) # Script para orquestrar deploys

✅ 1. Estruturar pastas na VPS
Execute os seguintes comandos na sua VPS para criar a estrutura:

mkdir -p /root/infra/dev
mkdir -p /root/services/api-auth
mkdir -p /root/services/api-orders
mkdir -p /root/shared/mongodb/data

✅ 2. Enviar um arquivo/diretorio local para a vps
scp -r infra root@195.200.1.129:/root/

$ scp -r \* root@195.200.1.129:/root/traefik/ <= copia todos os arquivos de dentro da pasta da qual vc está
