#!/bin/bash

###########################################################
# Instalador WordPress Template
# WooCommerce + Elementor + Cloudflare + Tema variável
###########################################################

if [ "$#" -ne 6 ]; then
  echo "Uso: bash install.sh dominio.com dbname dbuser dbpass cloudflare_zone_id tema"
  echo "Exemplo:"
  echo "bash install.sh dominio.com wpdb wpuser wppass 123456789abcdef astra"
  exit 1
fi

DOMAIN=$1
DB_NAME=$2
DB_USER=$3
DB_PASS=$4
CF_ZONE=$5
THEME=$6

ROOT="public"

echo "=============================================="
echo "→ Iniciando instalação para domínio: $DOMAIN"
echo "→ Tema selecionado: $THEME"
echo "=============================================="

cd $ROOT

echo "→ Criando wp-config.php..."
wp config create \
  --dbname="$DB_NAME" \
  --dbuser="$DB_USER" \
  --dbpass="$DB_PASS" \
  --dbhost="127.0.0.1" \
  --allow-root \
  --skip-check

echo "→ Importando banco template.sql..."
wp db import ../template.sql --allow-root

OLD_URL=$(wp option get siteurl --allow-root)

echo "→ Atualizando URLs ($OLD_URL → https://$DOMAIN)..."
wp search-replace "$OLD_URL" "https://$DOMAIN" --skip-columns=guid --allow-root
wp search-replace "$OLD_URL/wp-content/uploads" "https://$DOMAIN/wp-content/uploads" --allow-root

echo "→ Forçando HTTPS..."
wp option update home "https://$DOMAIN" --allow-root
wp option update siteurl "https://$DOMAIN" --allow-root

wp config set FORCE_SSL_ADMIN true --allow-root
wp config set WP_HOME "https://$DOMAIN" --allow-root
wp config set WP_SITEURL "https://$DOMAIN" --allow-root

echo "→ Ativando plugins..."
wp plugin activate --all --allow-root

echo "→ Ativando tema: $THEME"
wp theme activate $THEME --allow-root || echo "⚠ Tema $THEME não encontrado!"

echo "→ Ajustando Elementor..."
wp elementor flush-css --allow-root
wp elementor regenerate-css --allow-root

echo "→ Ajustando WooCommerce..."
wp wc tool run install_pages --allow-root || true
wp transient delete --all --allow-root

echo "→ Ajustando permalinks..."
wp rewrite structure "/%postname%/" --allow-root
wp rewrite flush --hard --allow-root

echo "→ Limpando cache WordPress..."
wp cache flush --allow-root

###############################################
# CLOUDFlARE CACHE PURGE
###############################################

CF_TOKEN="jJBMaI1sZVPSsF-z1RE1sU2Qwjljixs0bOEMbvdr"

echo "→ Limpando cache Cloudflare..."

curl -X POST "https://api.cloudflare.com/client/v4/zones/$CF_ZONE/purge_cache" \
  -H "Authorization: Bearer $CF_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{"purge_everything":true}' \
  --silent

echo "=============================================="
echo "✔ Instalação finalizada!"
echo "Acesse: https://$DOMAIN/wp-admin"
echo "=============================================="
