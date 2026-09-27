# pyseco controller. The source comes from the build context "pyseco_src" (PYSECO_DIR in .env).
FROM python:3.14-slim
WORKDIR /opt/pyseco
COPY --from=pyseco_src requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY --from=pyseco_src src/ src/
COPY scripts/render.sh pyseco/entrypoint.sh /usr/local/bin/
# rendered settings (see entrypoint), writable for the host user the container runs as
RUN mkdir -m 777 /run/pyseco
WORKDIR /opt/pyseco/src
ENTRYPOINT ["entrypoint.sh"]
