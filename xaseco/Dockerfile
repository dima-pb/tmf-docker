# XAseco 1.16. It uses PHP's old mysql_* functions, which only exist up to PHP 5.6.
# The source comes from the build context "xaseco_src" (XASECO_DIR in .env).
FROM php:5.6-cli
RUN docker-php-ext-install mysql

WORKDIR /opt/xaseco
COPY --from=xaseco_src . .
# third-party plugins (see xaseco/addons/README.md)
COPY xaseco/addons/plugins/ plugins/
# monthly log files in logs/ (a volume) instead of logfile.txt in the program directory
RUN sed -i "s/define('MONTHLY_LOGSDIR', false);/define('MONTHLY_LOGSDIR', true);/" aseco.php \
 && grep -q "define('MONTHLY_LOGSDIR', true);" aseco.php \
 && mkdir -p logs \
 && chmod 777 . includes logs
COPY scripts/render.sh xaseco/entrypoint.sh /usr/local/bin/
ENTRYPOINT ["entrypoint.sh"]
