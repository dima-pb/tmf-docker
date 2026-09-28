#!/bin/sh
set -e
cd /opt/xaseco

if [ -z "$TMF_MASTERADMIN_LOGIN" ]; then
  echo "TMF_MASTERADMIN_LOGIN is not set in .env - XAseco does not start without a MasterAdmin" >&2
  exit 1
fi

# Dedimania accepts a community code instead of the server password
# (the other two are used by the track list saving and Records-Eyepiece's clock)
export TMF_DEDIMANIA_PASSWORD="${TMF_DEDIMANIA_CODE:-$TMF_SERVER_PASSWORD}"
export TMF_TRACKLIST="${TMF_MATCHSETTINGS#MatchSettings/}"
export TMF_TZ="${TZ:-UTC}"

# settings from config/xaseco with the ${TMF_...} values from .env filled in;
# the *.php settings belong into includes/, everything else into the program directory
for f in /config/*; do
  name=$(basename "$f")
  case "$name" in
    *.php) render.sh "$f" "includes/$name" ;;
    *.xml) render.sh --xaseco "$f" "$name" ;;
    *) render.sh "$f" "$name" ;;
  esac
done

# Dedimania needs a server account, a LAN server (no login in .env) runs without it
if [ -z "$TMF_SERVER_LOGIN" ]; then
  echo "No server login configured: Dedimania plugins disabled"
  sed -i '/<plugin>plugin\.dedimania\.php<\/plugin>/d; /<plugin>chat\.dedimania\.php<\/plugin>/d' plugins.xml
  # Records-Eyepiece refuses to start with Dedimania widgets but without the Dedimania plugin
  perl -0 -pi -e 's{(<dedimania_records>.*?</dedimania_records>)}{ (my $b = $1) =~ s/<enabled>true</<enabled>false</g; $b }gse;
                  s{<dedimania_records>true</dedimania_records>}{<dedimania_records>false</dedimania_records>}g' records_eyepiece.xml
fi

# files XAseco changes itself (admin lists, bans, jfreu settings) live in the data volume
for f in adminops.xml bannedips.xml; do
  [ -f "/data/$f" ] || cp "newinstall/$f" "/data/$f"
done
mkdir -p /data/jfreu
for f in plugins/jfreu/*.xml; do
  [ -f "/data/jfreu/$(basename "$f")" ] || cp "$f" /data/jfreu/
done

exec php -d date.timezone="${TZ:-UTC}" aseco.php TMF
