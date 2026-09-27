#!/bin/sh
set -e
cd /opt/tmserver
TRACKS=GameData/Tracks

# first start: default tracks and the match settings from config/
# (a marker file, because the server itself creates empty directories like Campaigns/)
if [ ! -f "$TRACKS/.defaults-copied" ]; then
  echo "First start: copying default tracks"
  cp -r /opt/defaults/Tracks/. "$TRACKS/"
  touch "$TRACKS/.defaults-copied"
fi
if [ ! -f "$TRACKS/$TMF_MATCHSETTINGS" ]; then
  echo "Creating $TMF_MATCHSETTINGS from config/tmserver/matchsettings.txt"
  mkdir -p "$(dirname "$TRACKS/$TMF_MATCHSETTINGS")"
  cp /config/matchsettings.txt "$TRACKS/$TMF_MATCHSETTINGS"
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
