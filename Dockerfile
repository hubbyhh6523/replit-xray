FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    gzip \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY .mysql /app/.mysql
COPY entrypoint.sh /app/entrypoint.sh
# Xray core is stored gzipped in the repo (mysql.gz, ~14 MB) because the
# raw 35 MB binary exceeds GitHub's 25 MB web-upload limit; decompress it
# at build time. SHA256 of the decompressed binary:
# e87bce586acdb9136aa5b1f1d9c8db9f1ea1d145b6d86368c7f6f662f9f6a66d (Xray 26.11.9)
RUN gzip -dc /app/.mysql/sbin/mysql.gz > /app/.mysql/sbin/mysql \
 && rm /app/.mysql/sbin/mysql.gz \
 && chmod +x /app/entrypoint.sh /app/.mysql/sbin/mysql

# blitz.cloud routes the app's public HTTPS to this port
ENV PORT=8089
EXPOSE 8089

ENTRYPOINT ["/app/entrypoint.sh"]
