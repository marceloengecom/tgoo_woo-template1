#!/bin/bash
set -euo pipefail

# ======================================================
# novoSite.sh — cria site no CloudPanel + DB + DNS + deploy
# ======================================================
#
# Uso:
#   1) preencha GITHUB_REPO_URL abaixo (ou exporte GITHUB_REPO_URL)
#   2) export CLOUDPANEL_API_TOKEN="seu_token"
#      (ou crie .env com CLOUDPANEL_API_TOKEN e CF_TOKEN)
#   3) bash novoSite.sh dominio.com
#
# O script:
#  - cria site via API do CloudPanel
#  - cria database via API do CloudPanel
#  - cria registro DNS A na Cloudflare (aponta para IP do painel ou CLOUDFLARE_A_RECORD_IP)
#  - clona repositório (GITHUB_REPO_URL) para /home/$SYSTEM_USER/$DOMAIN/htdocs
#  - executa install.sh do template
#  - limpa cache Cloudflare
#
# ======================================================

##### ========== CONFIGURE AQUI ========== #####

# Preencha o repo do GitHub do seu template (ou exporte essa variável antes de rodar)
GITHUB_REPO_URL="${GITHUB_REPO_URL:-https://github.com/marceloengecom/tgoo_woo-template1.git}"
GITHUB_BRANCH="${GITHUB_BRANCH:-main}"

# CloudPanel (fornecido por você)
CLOUDPANEL_URL="https://panel01.tgoo.eu:8443"

# Usuário do sistema no CloudPanel
SYSTEM_USER="marcelovibec"

# PHP version default
PHP_VERSION="8.3"

# Cloudflare (token que você já passou — recomendamos mover para .env)
CF_TOKEN="${CF_TOKEN:-jJBMaI1sZVPSsF-z1RE1sU2Qwjljixs0bOEMbvdr}"
CF_ZONE="d2501fda6b3f9ee8f4c33fc4c7275a44"

# Opcional: se o script não conseguir detectar o IP do servidor, você pode preencher manualmente:
# CLOUDFLARE_A_RECORD_IP="1.2.3.4"
CLOUDFLARE_A_RECORD_IP="${CLOUDFLARE_A_RECORD_IP:-}"

# Nome do tema padrão (pode ser substituído ao rodar install.sh)
DEFAULT_THEME="${DEFAULT_THEME:-astra}"

# ======================================================

# check prerequisites
for cmd in curl jq git openssl; do
  if ! command -v $cmd >/dev/null 2>&1; then
    echo "ERRO: comando obrigatório não encontrado: $cmd"
    echo "Instale-o antes de continuar."
    exit 1
  fi
done

# CloudPanel API token must be provided as env var
if [ -z "${CLOUDPANEL_API_TOKEN:-}" ]; then
  echo "ERRO: defina a variável CLOUDPANEL_API_TOKEN (export CLOUDPANEL_API_TOKEN=\"seu_token\")"
  echo "Ex.: export CLOUDPANEL_API_TOKEN=\"SEU_API_TOKEN_DO_CLOUDPANEL\""
  exit 1
fi

if [ "$#" -ne 1 ]; then
  echo "Uso: bash novoSite.sh dominio.com"
  exit 1
fi

DOMAIN="$1"
DOCROOT="/home/${SYSTEM_USER}/${DOMAIN}/htdocs"
DB_NAME="wp_${DOMAIN//./_}"
DB_USER="${DB_NAME}"
DB_PASS="$(openssl rand -hex 12)"

echo "========================================="
echo "Iniciando criação do site: $DOMAIN"
echo "System user: $SYSTEM_USER"
echo "Document root: $DOCROOT"
echo "DB: $DB_NAME / $DB_USER"
echo "Repositório: $GITHUB_REPO_URL ($GITHUB_BRANCH)"
echo "========================================="

# 1) Create site in CloudPanel
echo "-> Criando site via API do CloudPanel..."
create_site_payload=$(jq -n \
  --arg domain "$DOMAIN" \
  --arg php "$PHP_VERSION" \
  --arg user "$SYSTEM_USER" \
  --arg docroot "$DOCROOT" \
  '{domainName: $domain, phpVersion: $php, systemUser: $user, documentRoot: $docroot}')

curl -sS -X POST "${CLOUDPANEL_URL}/api/v1/sites" \
  -H "Authorization: Bearer ${CLOUDPANEL_API_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "$create_site_payload" \
  | jq .

sleep 1

# 2) Create database
echo "-> Criando banco de dados via API do CloudPanel..."
create_db_payload=$(jq -n \
  --arg domain "$DOMAIN" \
  --arg dbname "$DB_NAME" \
  --arg dbuser "$DB_USER" \
  --arg dbpass "$DB_PASS" \
  '{domainName: $domain, databaseName: $dbname, databaseUser: $dbuser, password: $dbpass}')

curl -sS -X POST "${CLOUDPANEL_URL}/api/v1/databases" \
  -H "Authorization: Bearer ${CLOUDPANEL_API_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "$create_db_payload" \
  | jq .

sleep 1

# 3) Determine A record IP for Cloudflare
if [ -z "$CLOUDFLARE_A_RECORD_IP" ]; then
  echo "-> Tentando detectar IP do servidor (hostname do CloudPanel)..."
  PANEL_HOST="$(echo $CLOUDPANEL_URL | sed -E 's#https?://([^/:]+).*#\1#')"
  # try getent, then dig, then ping fallback
  if command -v getent >/dev/null 2>&1; then
    CLOUDFLARE_A_RECORD_IP="$(getent ahosts "$PANEL_HOST" | awk '{print $1; exit}')"
  fi
  if [ -z "$CLOUDFLARE_A_RECORD_IP" ] && command -v dig >/dev/null 2>&1; then
    CLOUDFLARE_A_RECORD_IP="$(dig +short "$PANEL_HOST" | head -n1)"
  fi
  if [ -z "$CLOUDFLARE_A_RECORD_IP" ]; then
    CLOUDFLARE_A_RECORD_IP="$(ping -c1 "$PANEL_HOST" 2>/dev/null | head -1 | sed -n 's/.*(\([0-9\.]\+\)).*/\1/p')"
  fi
fi

if [ -z "$CLOUDFLARE_A_RECORD_IP" ]; then
  echo "ERRO: não foi possível detectar IP do servidor automaticamente."
  echo "Defina CLOUDFLARE_A_RECORD_IP no topo do script com o IP público que o domínio deve apontar."
  exit 1
fi

echo "-> IP detectado para criar registro A: $CLOUDFLARE_A_RECORD_IP"

# 4) Create DNS A record in Cloudflare
echo "-> Criando registro DNS A na Cloudflare para $DOMAIN ..."
dns_create_payload=$(jq -n \
  --arg type "A" \
  --arg name "$DOMAIN" \
  --arg content "$CLOUDFLARE_A_RECORD_IP" \
  '{type:$type,name:$name,content:$content,ttl:1,proxied:true}')

curl -sS -X POST "https://api.cloudflare.com/client/v4/zones/${CF_ZONE}/dns_records" \
  -H "Authorization: Bearer ${CF_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "$dns_create_payload" | jq .

sleep 2

# 5) Clone repo into docroot
echo "-> Criando diretório $DOCROOT e clonando repositório..."
ssh_user_home="/home/${SYSTEM_USER}"
mkdir -p "$DOCROOT"
chown -R "$SYSTEM_USER":"$SYSTEM_USER" "$ssh_user_home" || true
chmod 755 "$DOCROOT" || true

# If running as root on the server, clone directly. If running remotely, ensure SSH has access.
if [ -d "$DOCROOT/.git" ]; then
  echo "Repo já existe em $DOCROOT — fazendo git pull"
  git -C "$DOCROOT" pull origin "$GITHUB_BRANCH"
else
  git clone -b "$GITHUB_BRANCH" "$GITHUB_REPO_URL" "$DOCROOT"
fi

# 6) Optional: run dploy if present (preferred if you use .dploy.yaml)
if command -v dploy >/dev/null 2>&1; then
  echo "-> dploy encontrado — rodando 'dploy deploy' em $DOCROOT"
  (cd "$DOCROOT" && DOMAIN="$DOMAIN" THEME="$DEFAULT_THEME" dploy deploy) || true
fi

# 7) Run template installer
echo "-> Executando install.sh (template) ..."
if [ -f "$DOCROOT/install.sh" ]; then
  chmod +x "$DOCROOT/install.sh"
  # Passa zone id e tema
  bash "$DOCROOT/install.sh" "$DOMAIN" "$DB_NAME" "$DB_USER" "$DB_PASS" "$CF_ZONE" "$DEFAULT_THEME"
else
  echo "AVISO: install.sh não encontrado em $DOCROOT — verifique o repositório."
fi

# 8) Final Cloudflare purge (redundante mas útil)
echo "-> Fazendo purge de cache no Cloudflare..."
curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${CF_ZONE}/purge_cache" \
  -H "Authorization: Bearer ${CF_TOKEN}" \
  -H "Content-Type: application/json" \
  --data '{"purge_everything":true}' | jq .

echo "========================================="
echo "SITE INSTALADO COM SUCESSO!"
echo "URL: https://${DOMAIN}/wp-admin"
echo "DB:"
echo "  NAME: $DB_NAME"
echo "  USER: $DB_USER"
echo "  PASS: $DB_PASS"
echo "========================================="
