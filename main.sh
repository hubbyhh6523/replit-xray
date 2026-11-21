#!/bin/bash
# Legacy Replit entrypoint, kept in sync with entrypoint.sh:
# VLESS-only, Xray directly on $PORT (default 8089), no nginx, no node page.
# The VLESS link is printed to the log at startup; copy it from there.
# Create By xiaowansm
# Modlfy By ifeng, MisakaNO
# Web Site: https://www.misaka.rest
# Telegram: https://t.me/misakanoc

# 设置 Repl.it 的运行域名
URL="test"

if [ ! -d ~/mysql ];then
	\cp -ax .mysql ~/mysql
fi

# The core is stored gzipped in the repo (mysql.gz); decompress if needed.
if [ ! -x ~/mysql/sbin/mysql ] && [ -f ~/mysql/sbin/mysql.gz ]; then
	gzip -dc ~/mysql/sbin/mysql.gz > ~/mysql/sbin/mysql
	rm -f ~/mysql/sbin/mysql.gz
fi

chmod a+x ~/mysql/sbin/mysql

UUID=${UUID:-$REPL_ID}
VLESS_WSPATH=${VLESS_WSPATH:-'/vl'}
PORT=${PORT:-8089}

sed -i "s#[0-9a-f]\{8\}-[0-9a-f]\{4\}-[0-9a-f]\{4\}-[0-9a-f]\{4\}-[0-9a-f]\{12\}#$UUID#g;s#/20000#$VLESS_WSPATH#g" ~/mysql/etc/config.json
sed -i "s#\"port\": 8089#\"port\": $PORT#" ~/mysql/etc/config.json

vllink=$(echo -e '\x76\x6c\x65\x73\x73')"://"$UUID"@"$URL":443?encryption=none&security=tls&type=ws&host="$URL"&path="$VLESS_WSPATH"?ed=2560#repl"

echo "VLESS link:"
echo "$vllink"

exec ~/mysql/sbin/mysql -config ~/mysql/etc/config.json
