#!/bin/sh
set -e
# settings from config/pyseco with the ${TMF_...} values from .env filled in
mkdir -p /run/pyseco/plugins
render.sh /config/pyseco.cfg /run/pyseco/pyseco.cfg
for ini in /config/plugins/*.ini; do
  render.sh "$ini" "/run/pyseco/plugins/$(basename "$ini")"
done
exec python -u pyseco.py --config-dir /run/pyseco
