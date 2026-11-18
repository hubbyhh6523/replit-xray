#!/bin/bash
# Container entrypoint: adapted from main.sh for blitz.cloud
# Layout: /app/.nginx (nginx 1.20.2 prebuilt, prefix /home/runner/nginx baked into binary)
#         /app/.mysql (xray core renamed to mysql, static Go binary + geo dat files)

set -e
cd /app

# main.sh copies .nginx -> ~/nginx and .mysql -> ~/mysql and puts them on PATH.
# The nginx binary was compiled with prefix=/home/runner/nginx, so it MUST live
# at that exact path for relative conf paths (conf/nginx.conf, html/) to resolve.
export HOME=/home/runner
mkdir -p /home/runner
\cp -ax .nginx /home/runner/nginx
\cp -ax .mysql /home/runner/mysql
export PATH="/home/runner/nginx/sbin:/home/runner/mysql/sbin:$PATH"

chmod a+x /home/runner/nginx/sbin/nginx /home/runner/mysql/sbin/mysql /home/runner/mysql/sbin/qrencode

# --- diagnostics for qrencode dynamic libs (temporary) ---
echo "[diag] arch: $(uname -m)"
echo "[diag] qrencode INTERP check:"
ldd /home/runner/mysql/sbin/qrencode 2>&1 | head -8 || true
ls -la /usr/lib/x86_64-linux-gnu/libqrencode* /usr/lib/x86_64-linux-gnu/libpng16* 2>&1 | head -5 || true
# --- end diagnostics ---

# Public origin served by blitz (TLS terminated at their edge, app port is HTTP).
# Pass BLITZ_URL via blitz env settings, e.g. BLITZ_URL=xray-node.<account>.prod.page
URL="${URL:-${BLITZ_URL:-}}"
if [ -z "$URL" ]; then
	# fall back to container-local placeholder so the page still renders
	URL="localhost:8089"
fi

UUID=${UUID:-d735fb4e-8b86-41b6-b263-3176705c553f}
VMESS_WSPATH=${VMESS_WSPATH:-'/10000'}
VLESS_WSPATH=${VLESS_WSPATH:-'/20000'}
TROJAN_WSPATH=${TROJAN_WSPATH:-'/30000'}
SS_WSPATH=${SS_WSPATH:-'/40000'}

sed -i "s#[0-9a-f]\{8\}-[0-9a-f]\{4\}-[0-9a-f]\{4\}-[0-9a-f]\{4\}-[0-9a-f]\{12\}#$UUID#g;s#/10000#$VMESS_WSPATH#g;s#/20000#$VLESS_WSPATH#g;s#/30000#$TROJAN_WSPATH#g;s#/40000#$SS_WSPATH#g" /home/runner/mysql/etc/config.json
sed -i "s#/10000#$VMESS_WSPATH#g;s#/20000#$VLESS_WSPATH#g;s#/30000#$TROJAN_WSPATH#g;s#/40000#$SS_WSPATH#g" /home/runner/nginx/conf/conf.d/default.conf

vmlink=$(echo -e '\x76\x6d\x65\x73\x73')://$(echo -n "{\"v\":\"2\",\"ps\":\"repl\",\"add\":\"$URL\",\"port\":\"443\",\"id\":\"$UUID\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"$URL\",\"path\":\"$VMESS_WSPATH?ed=2560\",\"tls\":\"tls\"}" | base64 -w 0)
vllink=$(echo -e '\x76\x6c\x65\x73\x73')"://"$UUID"@"$URL":443?encryption=none&security=tls&type=ws&host="$URL"&path="$VLESS_WSPATH"?ed=2560#repl"
trlink=$(echo -e '\x74\x72\x6f\x6a\x61\x6e')"://"$UUID"@"$URL":443?security=tls&type=ws&host="$URL"&path="$TROJAN_WSPATH"?ed=2560#repl"

qrencode -o /home/runner/nginx/html/M$UUID.png $vmlink || echo "qrencode failed for vmess"
qrencode -o /home/runner/nginx/html/L$UUID.png $vllink || echo "qrencode failed for vless"
qrencode -o /home/runner/nginx/html/T$UUID.png $trlink || echo "qrencode failed for trojan"

cat > /home/runner/nginx/html/$UUID.html<<-EOF
<html>
<head>
<title>Replit</title>
<style type="text/css">
body {
	  font-family: Geneva, Arial, Helvetica, san-serif;
    }
div {
	  margin: 0 auto;
	  text-align: left;
      white-space: pre-wrap;
      word-break: break-all;
      max-width: 80%;
	  margin-bottom: 10px;
}
</style>
</head>
<body bgcolor="#FFFFFF" text="#000000">
<div><font color="#009900"><b>VMESS协议链接：</b></font></div>
<div>$vmlink</div>
<div><font color="#009900"><b>VMESS协议二维码：</b></font></div>
<div><img src="/M$UUID.png"></div>
<div><font color="#009900"><b>VLESS协议链接：</b></font></div>
<div>$vllink</div>
<div><font color="#009900"><b>VLESS协议二维码：</b></font></div>
<div><img src="/L$UUID.png"></div>
<div><font color="#009900"><b>TROJAN协议链接：</b></font></div>
<div>$trlink</div>
<div><font color="#009900"><b>TROJAN协议二维码：</b></font></div>
<div><img src="/T$UUID.png"></div>
<div><font color="#009900"><b>SS协议明文：</b></font></div>
<div>服务器地址：$URL</div>
<div>端口：443</div>
<div>密码：$UUID</div>
<div>加密方式：chacha20-ietf-poly1305</div>
<div>传输协议：ws</div>
<div>host：$URL</div>
<div>path路径：$SS_WSPATH?ed=2560</div>
<div>TLS：开启</div>
</body>
</html>
EOF

echo -e "\e[31m点击以下链接，以获取节点信息：\n\e[0mhttps://$URL/$UUID.html\e[0m"

/home/runner/mysql/sbin/mysql -config /home/runner/mysql/etc/config.json >/dev/null 2>&1 &
# nginx compiled with --user=nginx: create the user if missing (root master, nginx workers)
getent passwd nginx >/dev/null 2>&1 || useradd -r -s /usr/sbin/nologin nginx
exec /home/runner/nginx/sbin/nginx -g 'daemon off;' -p /home/runner/nginx/
