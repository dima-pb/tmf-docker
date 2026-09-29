#!/bin/sh
set -e
# pyseco.toml from config/pyseco with the ${TMF_...} values from .env filled in
export TMF_DISCORD_CHANNEL_ID="${TMF_DISCORD_CHANNEL_ID:-0}" # a number in TOML, empty would be invalid
render.sh --toml /config/pyseco.toml /run/pyseco/pyseco.toml
exec python -u pyseco.py --config /run/pyseco/pyseco.toml
