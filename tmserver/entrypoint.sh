#!/bin/sh
set -e
cd /opt/tmserver
TRACKS=GameData/Tracks

# default tracks: on every start the missing ones are copied, nothing that exists is overwritten
# (so a default track that got deleted comes back)
cp -rn /opt/defaults/Tracks/. "$TRACKS/"
if [ ! -f "$TRACKS/$TMF_MATCHSETTINGS" ]; then
  echo "Creating $TMF_MATCHSETTINGS from config/tmserver/matchsettings.txt"
  mkdir -p "$(dirname "$TRACKS/$TMF_MATCHSETTINGS")"
  cp /config/matchsettings.txt "$TRACKS/$TMF_MATCHSETTINGS"
fi
# the maps of the match settings, as paths below the tracks directory
maps=$(sed -n 's:.*<file>\(.*\)</file>.*:\1:p' "$TRACKS/$TMF_MATCHSETTINGS" | tr '\\' '/' | tr -d '\r')
# maps the match settings list but that don't exist; the server only says it can't load them
printf '%s\n' "$maps" | while IFS= read -r map; do
  [ -z "$map" ] || [ -f "$TRACKS/$map" ] || echo "WARNING: $TMF_MATCHSETTINGS lists $map, which does not exist in data/tmserver/tracks"
done
# maps from TMX (pyseco's /add, /rtmx) that are not in the match settings were for one play: their files go
# (/addthis saves a map in the match settings, it stays)
if [ "${TMF_CLEAN_TMX:-1}" = 1 ]; then
  for file in "$TRACKS"/Challenges/TMX/*; do
    [ -f "$file" ] || continue
    if ! printf '%s\n' "$maps" | grep -qixF "${file#"$TRACKS"/}"; then
      echo "Removing ${file#"$TRACKS"/} (a TMX map that is not in $TMF_MATCHSETTINGS)"
      rm -f "$file"
    fi
  done
fi

render.sh --xml /config/dedicated_cfg.txt GameData/Config/dedicated_cfg.txt

set -- /dedicated_cfg=dedicated_cfg.txt "/game_settings=$TMF_MATCHSETTINGS" /nodaemon
if [ -z "$TMF_SERVER_LOGIN" ]; then
  echo "No server login configured: starting as LAN server"
  set -- "$@" /lan
fi

# The container usually gives the server the same pid, and it appends to an existing
# Logs/ConsoleLog.<pid>.txt. Older logs get the time of their last change as prefix instead.
for log in Logs/ConsoleLog.*.txt; do
  [ -f "$log" ] && mv "$log" "Logs/$(date -r "$log" +%Y-%m-%d_%H%M%S)_$(basename "$log")"
done

# The server buffers its console output when it is not attached to a terminal, but writes the same
# lines to Logs/ConsoleLog.<pid>.txt. So it runs in the background, its log is followed for
# "docker logs", and stop signals are passed on so it can shut down cleanly.
./TrackmaniaServer "$@" &
pid=$!
trap 'kill -TERM "$pid" 2>/dev/null' TERM INT
tail -n +1 -F "Logs/ConsoleLog.$pid.txt" 2>/dev/null &
tail_pid=$!

status=0
while kill -0 "$pid" 2>/dev/null; do
  # wait also returns when a signal arrives, so loop until the server has really exited
  if wait "$pid"; then status=0; else status=$?; fi
done
kill "$tail_pid" 2>/dev/null
exit "$status"
