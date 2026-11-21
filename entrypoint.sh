#!/bin/bash
# Container entrypoint: VLESS-only, Xray directly on $PORT (default 8089).
# No nginx in the path: blitz terminates TLS at its edge and forwards
# plain HTTP/WS to this port, so Xray serves the WS inbound directly.
# No node page / QR code any more: the VLESS link is printed to the
# container log at startup; copy it from there.
# Layout: /app/.mysql (xray core renamed to mysql, static Go binary + geo dat files)

set -e
cd /app

XRAY=/app/.mysql/sbin/mysql
CONFIG=/app/.mysql/etc/config.json
# The core is stored gzipped in the repo (mysql.gz); the Dockerfile normally
# decompresses it at build time, but handle the case where it wasn't.
if [ ! -x "$XRAY" ] && [ -f "$XRAY.gz" ]; then
	gzip -dc "$XRAY.gz" > "$XRAY"
	rm -f "$XRAY.gz"
fi
chmod +x "$XRAY"

# Public origin served by blitz (TLS terminated at their edge, app port is HTTP).
# Pass BLITZ_URL via blitz env settings, e.g. BLITZ_URL=xray-node.<account>.prod.page
URL="${URL:-${BLITZ_URL:-}}"
if [ -z "$URL" ]; then
	URL="localhost:8089"
fi

UUID=${UUID:-d735fb4e-8b86-41b6-b263-3176705c553f}
VLESS_WSPATH=${VLESS_WSPATH:-'/20000'}
PORT=${PORT:-8089}

sed -i "s#[0-9a-f]\{8\}-[0-9a-f]\{4\}-[0-9a-f]\{4\}-[0-9a-f]\{4\}-[0-9a-f]\{12\}#$UUID#g;s#/20000#$VLESS_WSPATH#g" "$CONFIG"
sed -i "s#\"port\": 8089#\"port\": $PORT#" "$CONFIG"

vllink=$(echo -e '\x76\x6c\x65\x73\x73')"://"$UUID"@"$URL":443?encryption=none&security=tls&type=ws&host="$URL"&path="$VLESS_WSPATH"?ed=2560#repl"

echo "VLESS link:"
echo "$vllink"

exec "$XRAY" -config "$CONFIG"
