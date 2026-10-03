# TrackMania Forever dedicated server (Linux build 2011-02-21).
# The server files are not part of this repo: they come from the build context "tmserver_src"
# (TMSERVER_DIR in .env), so this image must only be built locally, never published.

FROM python:3.14-slim AS binary
COPY --from=tmserver_src TrackmaniaServer /build/TrackmaniaServer
COPY tmserver/patch_tiebreak.py /build/
ARG TMF_TIEBREAK_PATCH=1
RUN if [ "$TMF_TIEBREAK_PATCH" = "1" ]; then \
      python /build/patch_tiebreak.py /build/TrackmaniaServer /build/server; \
    else \
      cp /build/TrackmaniaServer /build/server; \
    fi

FROM debian:bookworm-slim
WORKDIR /opt/tmserver
COPY --from=binary --chmod=755 /build/server TrackmaniaServer
COPY --from=tmserver_src GameData/DedicatedTrackMania.TrackMania.gbx GameData/NationsList.xml GameData/
# default tracks, missing ones are copied into the tracks volume on every start; maps from TMX are no defaults
COPY --from=tmserver_src GameData/Tracks /opt/defaults/Tracks
RUN rm -rf /opt/defaults/Tracks/Challenges/TMX
COPY scripts/render.sh tmserver/entrypoint.sh /usr/local/bin/
# the server runs as the host user (see compose) and writes temporary files and its cache into GameData
RUN mkdir -p GameData/Cache GameData/Config GameData/Tracks Logs && chmod 777 GameData GameData/Cache

EXPOSE 2350/tcp 2350/udp 3450/tcp 3450/udp
ENTRYPOINT ["entrypoint.sh"]
