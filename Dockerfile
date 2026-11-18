FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates libqrencode4 libpng16-16 zlib1g patchelf \
 && rm -rf /var/lib/apt/lists/* \
 && useradd -r -s /usr/sbin/nologin nginx || true

WORKDIR /app
COPY .nginx /app/.nginx
COPY .mysql /app/.mysql
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh /app/.nginx/sbin/nginx /app/.mysql/sbin/mysql /app/.mysql/sbin/qrencode

# blitz.cloud routes the app's public HTTPS to this port
ENV PORT=8089
EXPOSE 8089

ENTRYPOINT ["/app/entrypoint.sh"]
