#!/bin/bash
set -euo pipefail

# newsite.sh — cria site no CloudPanel + DB + DNS + deploy + executa install.sh
# Uso:
#   export CLOUDPANEL_API_TOKEN="..."   # obrig
#   export GITHUB_REPO_URL="git@github.com:marceloengecom/tgoo_woo-template1.git" # ou https...
#   bash newsite.sh dominio.com

# ========== CONFIG (edite se desejar) ==========
CLOUDPANEL_URL="https://panel01.tgoo.eu:8443"
SYSTEM_USER="marcelovibec"
PHP_VERSION="8.4"
GITHUB_REPO_URL="${GITHUB_REPO_URL:-https://github.com/marceloengecom/tgoo_woo-template1.git}"
GITHUB_BRANCH="${GITHUB_BRANCH:-main}"

# Cloudflare defaults (token foi fornecido por você; ideal usar .env)
CF_TOKEN="${CF_TOKEN:-jJBMaI1sZVPSsF-z1RE1sU2Qwjljixs0bOEMbvdr}"
CF_ZONE="${CF_ZONE:-d2501fda6b3f9ee8f4c33fc4c7275a44}"

# default tema (pode ser alterado ao chamar install.sh)
DEFAULT_THEME="${DEFAULT_THEME:-astra}"

# opcional: IP público para o registro A (detecção automática caso vazio)
CLOUDFLARE_A_RECORD_IP="${CLOUDFLARE_A_RECORD_IP:-}"

# checar pré-requisitos
for cmd in curl jq git openssl wp; do
  if ! command -v $cmd >/dev/null 2>&1; then
    echo "ERRO: comando obrigatório não encontrado: $cmd"
    echo "Instale-o antes de continuar (apt install -y <pkg>)."
    exit 1
  fi
done

if [ -z "${CLOUDPANEL_API_TOKEN:-}" ]; then
  echo "ERRO: export CLOUDPANEL_API_TOKEN=\"SEU_API_TOKEN\" é obrigatório."
  exit 1
fi

if [ "$#" -ne 1 ]; then
  echo "Uso: bash newsite.sh dominio.com"
  exit 1
fi

DOMAIN="$1"
DOCROOT="/home/${SYSTEM_USER}/${DOMAIN}/htdocs"
DB_NAME="wp_${DOMAIN//./_}"
DB_USER="${DB_NAME}"
DB_PASS="$(openssl rand -hex 12)"

echo "Criando site: $DOMAIN"
echo "Document root: $DOCROOT"
echo "DB: $DB_NAME / $DB_USER"

# 1) criar site
create_site_payload=$(jq -n \
  --arg domain "$DOMAIN" \
  --arg php "$PHP_VERSION" \
  --arg user "$SYSTEM_USER" \
  --arg docroot "$DOCROOT" \
  '{domainName: $domain, phpVersion: $php, systemUser: $user, documentRoot: $docroot}')

curl -sS -X POST "${CLOUDPANEL_URL}/api/v1/sites" \
  -H "Authorization: Bearer ${CLOUDPANEL_API_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "$create_site_payload" | jq .

sleep 1

# 2) criar DB
create_db_payload=$(jq -n \
  --arg domain "$DOMAIN" \
  --arg dbname "$DB_NAME" \
  --arg dbuser "$DB_USER" \
  --arg dbpass "$DB_PASS" \
  '{domainName: $domain, databaseName: $dbname, databaseUser: $dbuser, password: $dbpass}')

curl -sS -X POST "${CLOUDPANEL_URL}/api/v1/databases" \
  -H "Authorization: Bearer ${CLOUDPANEL_API_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "$create_db_payload" | jq .

sleep 1

# 3) detectar IP para registro A (tenta automatiquement)
if [ -z "$CLOUDFLARE_A_RECORD_IP" ]; then
  PANEL_HOST="$(echo $CLOUDPANEL_URL | sed -E 's#https?://([^/:]+).*#\1#')"
  if command -v dig >/dev/null 2>&1; then
    CLOUDFLARE_A_RECORD_IP="$(dig +short "$PANEL_HOST" | head -n1)"
  fi
  if [ -z "$CLOUDFLARE_A_RECORD_IP" ]; then
    CLOUDFLARE_A_RECORD_IP="$(ping -c1 "$PANEL_HOST" 2>/dev/null | sed -n 's/.*(\([0-9\.]\+\)).*/\1/p' || true)"
  fi
fi

if [ -z "$CLOUDFLARE_A_RECORD_IP" ]; then
  echo "ERRO: não foi possível detectar IP do painel. Edite CLOUDFLARE_A_RECORD_IP no topo do script."
  exit 1
fi

echo "IP para A record: $CLOUDFLARE_A_RECORD_IP"

# 4) criar registro DNS na Cloudflare
dns_create_payload=$(jq -n --arg type "A" --arg name "$DOMAIN" --arg content "$CLOUDFLARE_A_RECORD_IP" '{type:$type,name:$name,content:$content,ttl:1,proxied:true}')
curl -sS -X POST "https://api.cloudflare.com/client/v4/zones/${CF_ZONE}/dns_records" \
  -H "Authorization: Bearer ${CF_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "$dns_create_payload" | jq .

sleep 2

# 5) clonar repo no docroot
echo "Clonando repositório $GITHUB_REPO_URL → $DOCROOT"
mkdir -p "$DOCROOT"
chown -R "$SYSTEM_USER":"$SYSTEM_USER" "/home/${SYSTEM_USER}" || true
if [ -d "$DOCROOT/.git" ]; then
  git -C "$DOCROOT" pull origin "$GITHUB_BRANCH"
else
  git clone -b "$GITHUB_BRANCH" "$GITHUB_REPO_URL" "$DOCROOT"
fi

# 6) rodar dploy se disponível (opcional)
if command -v dploy >/dev/null 2>&1; then
  echo "Executando dploy deploy (se aplicável)..."
  (cd "$DOCROOT" && DOMAIN="$DOMAIN" THEME="$DEFAULT_THEME" dploy deploy) || true
fi

# 7) executar install.sh do repo (passa zone id e tema)
if [ -f "$DOCROOT/install.sh" ]; then
  chmod +x "$DOCROOT/install.sh"
  echo "Executando install.sh..."
  # passar CF_ZONE e THEME via parâmetros e exportar token (install.sh lê CF_TOKEN do env)
  export CF_TOKEN="$CF_TOKEN"
  bash "$DOCROOT/install.sh" "$DOMAIN" "$DB_NAME" "$DB_USER" "$DB_PASS" "$CF_ZONE" "$DEFAULT_THEME"
else
  echo "AVISO: install.sh não encontrado em $DOCROOT — verifique repositório."
fi

# 8) purge final Cloudflare
curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${CF_ZONE}/purge_cache" \
  -H "Authorization: Bearer ${CF_TOKEN}" \
  -H "Content-Type: application/json" \
  --data '{"purge_everything":true}' | jq .

echo "========================================"
echo "SITE: https://${DOMAIN} criado com sucesso!"
echo "DB: $DB_NAME / $DB_USER / $DB_PASS"
echo "========================================"
