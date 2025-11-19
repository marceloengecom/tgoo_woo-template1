#!/bin/bash
set -euo pipefail

# install.sh — importa SQL + configura WordPress (WooCommerce + Elementor) + Cloudflare purge
# Uso:
#   bash install.sh <DOMAIN> <DB_NAME> <DB_USER> <DB_PASS> <CF_ZONE> <THEME>
#
# Exemplo:
#   bash install.sh meusite.com wp_meusite wp_user wp_pass d2501fda... astra

if [ "$#" -ne 6 ]; then
  echo "Uso: bash install.sh dominio.com dbname dbuser dbpass cloudflare_zone_id tema"
  exit 1
fi

DOMAIN="$1"
DB_NAME="$2"
DB_USER="$3"
DB_PASS="$4"
CF_ZONE="$5"
THEME="$6"

# Preferir token em .env (melhor prática); se não existir, usar fallback embutido
CF_TOKEN="${CF_TOKEN:-${CF_TOKEN_FALLBACK:-jJBMaI1sZVPSsF-z1RE1sU2Qwjljixs0bOEMbvdr}}"

# Detecta onde está o WordPress no repo: public/ ou raiz
if [ -d "./public" ]; then
  ROOT="./public"
else
  ROOT="."
fi

echo "Instalador: ROOT = $ROOT"

cd "$ROOT"

# localizar o arquivo SQL (pode estar em ./woo-template1.sql ou em ../woo-template1.sql)
SQL_PATH=""
if [ -f "./woo-template1.sql" ]; then
  SQL_PATH="./woo-template1.sql"
elif [ -f "../woo-template1.sql" ]; then
  SQL_PATH="../woo-template1.sql"
fi

# 1) criar wp-config (se não existir)
if [ ! -f "wp-config.php" ]; then
  echo "→ Criando wp-config.php..."
  wp config create \
    --dbname="$DB_NAME" \
    --dbuser="$DB_USER" \
    --dbpass="$DB_PASS" \
    --dbhost="127.0.0.1" \
    --skip-check \
    --allow-root
else
  echo "→ wp-config.php já existe, pulando criação."
fi

# 2) importar banco caso exista SQL
if [ -n "$SQL_PATH" ] && [ -f "$SQL_PATH" ]; then
  echo "→ Importando SQL: $SQL_PATH ..."
  wp db import "$SQL_PATH" --allow-root
else
  echo "→ Arquivo SQL não encontrado em ./ ou ../ — pulando import."
fi

# 3) descobrir URL antiga (se existir)
OLD_URL=""
if wp option get siteurl --allow-root >/dev/null 2>&1; then
  OLD_URL="$(wp option get siteurl --allow-root)"
fi

# Se OLD_URL vazio, tentamos extrair de SQL (não garantido), então pulamos
if [ -n "$OLD_URL" ] && [[ "$OLD_URL" != "http"* ]]; then
  OLD_URL=""
fi

echo "→ OLD_URL detectada: ${OLD_URL:-(nenhuma)}"

# 4) realizar search-replace da URL antiga para a nova
if [ -n "$OLD_URL" ]; then
  echo "→ Substituindo URLs no banco: $OLD_URL -> https://$DOMAIN"
  wp search-replace "$OLD_URL" "https://$DOMAIN" --skip-columns=guid --allow-root
  wp search-replace "${OLD_URL}/wp-content/uploads" "https://$DOMAIN/wp-content/uploads" --allow-root || true
fi

# 5) garantir URLs do WP e forçar HTTPS
echo "→ Atualizando opções siteurl/home para https://$DOMAIN"
wp option update home "https://$DOMAIN" --allow-root || true
wp option update siteurl "https://$DOMAIN" --allow-root || true

wp config set FORCE_SSL_ADMIN true --raw --allow-root || true
wp config set WP_HOME "https://$DOMAIN" --allow-root || true
wp config set WP_SITEURL "https://$DOMAIN" --allow-root || true

# 6) ativar plugins e tema
echo "→ Ativando todos os plugins encontrados..."
wp plugin activate --all --allow-root || echo "Alguns plugins não puderam ser ativados (verifique)."

echo "→ Ativando tema: $THEME"
wp theme activate "$THEME" --allow-root || echo "⚠ Tema '$THEME' não encontrado; verifique o nome da pasta em wp-content/themes."

# 7) Elementor ajustes (se estiver presente)
if wp plugin is-active elementor --allow-root >/dev/null 2>&1 || wp plugin is-installed elementor --allow-root >/dev/null 2>&1; then
  echo "→ Regenerando CSS do Elementor..."
  # comandos Elementor via WP-CLI (algumas versões dependem do plugin CLI)
  wp elementor flush-css --allow-root 2>/dev/null || true
  wp elementor regenerate-css --allow-root 2>/dev/null || true
fi

# 8) WooCommerce ajustes
if wp plugin is-active woocommerce --allow-root >/dev/null 2>&1 || wp plugin is-installed woocommerce --allow-root >/dev/null 2>&1; then
  echo "→ Ajustes WooCommerce: recriando páginas padrão (se necessário) e limpando transients..."
  wp wc tool run install_pages --allow-root || true
  wp transient delete --all --allow-root || true
fi

# 9) permalinks and rewrite
echo "→ Configurando permalinks e flush..."
wp rewrite structure "/%postname%/" --allow-root || true
wp rewrite flush --hard --allow-root || true

# 10) limpar cache WP
echo "→ Limpando cache do WordPress..."
wp cache flush --allow-root || true

# 11) purge Cloudflare (se token + zone existentes)
if [ -n "${CF_TOKEN:-}" ] && [ -n "${CF_ZONE:-}" ]; then
  echo "→ Purge Cloudflare para $DOMAIN (zone $CF_ZONE)..."
  curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${CF_ZONE}/purge_cache" \
    -H "Authorization: Bearer ${CF_TOKEN}" \
    -H "Content-Type: application/json" \
    --data '{"purge_everything":true}' >/dev/null || true
  echo "→ Purge Cloudflare enviado."
else
  echo "→ Cloudflare token/zone não configurados — pulando purge."
fi

echo "======================================="
echo "Instalação/Import concluída para https://$DOMAIN"
echo "Acesse: https://$DOMAIN/wp-admin"
echo "======================================="
