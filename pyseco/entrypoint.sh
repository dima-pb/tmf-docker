#!/bin/sh
set -e
# pyseco.toml from config/pyseco with the ${TMF_...} values from .env filled in
export TMF_DISCORD_CHANNEL_ID="${TMF_DISCORD_CHANNEL_ID:-0}" # a number in TOML, empty would be invalid
export TMF_DEDIMANIA_CODE="${TMF_DEDIMANIA_CODE:-$TMF_SERVER_PASSWORD}"
# how the players' games reach pyseco's web server; without a public address it stays off (text instead of images)
if [ -z "$TMF_HTTP_URL" ] && [ -n "$TMF_PUBLIC_IP" ]; then
  export TMF_HTTP_URL="http://$TMF_PUBLIC_IP:${TMF_HTTP_PORT:-8080}"
fi

# the plugins: TMF_PLUGINS, plus discord and dedimania when they can work
plugins="${TMF_PLUGINS:-welcome flexitime local_records session tmx jukebox custom_votes admin_panel karma}"
if [ -n "$TMF_DISCORD_TOKEN" ]; then plugins="$plugins discord"; fi
if [ -n "$TMF_SERVER_LOGIN" ] && [ -n "$TMF_DEDIMANIA_CODE" ]; then plugins="$plugins dedimania"; fi
list=$(printf '"%s", ' $plugins)
echo "pyseco plugins: $plugins"

sed "s/@PLUGINS@/${list%, }/" /config/pyseco.toml > /run/pyseco/template.toml
render.sh --toml /run/pyseco/template.toml /run/pyseco/pyseco.toml
exec python -u pyseco.py --config /run/pyseco/pyseco.toml
