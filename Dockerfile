FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY .mysql /app/.mysql
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh /app/.mysql/sbin/mysql

# blitz.cloud routes the app's public HTTPS to this port
ENV PORT=8089
EXPOSE 8089

ENTRYPOINT ["/app/entrypoint.sh"]
