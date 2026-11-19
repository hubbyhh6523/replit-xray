# xray-node

在 [blitz.cloud](https://blitz.cloud) 上容器化部署 xray 节点（vmess / vless / trojan / shadowsocks），Dockerfile 包装 + 自动构建 + 免运维。

> 本仓库是 [Misaka-blog/replit-xray](https://github.com/Misaka-blog/replit-xray) 的 fork，原项目面向 Replit 平台；本 fork 改造为标准 Docker 容器，可部署到 blitz.cloud 或任何支持 Dockerfile 构建的 PaaS。

## 架构

```
客户端 ──TLS/WS──> blitz 边缘 (443) ──HTTP──> nginx:8089 ──WS──> Xray (127.0.0.1:10000-40000)
                                                  │
                                                  └── 静态页: /<UUID>.html + 三张二维码
```

| 组件 | 说明 |
|------|------|
| `.nginx/` | 预编译 nginx 1.20.2（x86_64，prefix=`/home/runner/nginx`），反代 4 条 WS 路径 |
| `.mysql/sbin/mysql` | Xray 1.8.10 核心（Go 静态编译，伪装命名），vmess/vless/trojan/ss 四入站 |
| `.mysql/sbin/qrencode` | 二维码生成器（nix 构建，entrypoint 运行时 patchelf 修复解释器） |
| `Dockerfile` | `debian:bookworm-slim` + libqrencode4/libpng16/patchelf |
| `entrypoint.sh` | 容器启动逻辑（替代原 `main.sh`），生成节点页与二维码 |

## 部署到 blitz.cloud

1. Fork 本仓库
2. blitz 面板连接 GitHub（MCP 用 `apps_deploy_github`，面板直接选仓库）
3. 部署应用，blitz 自动识别 `Dockerfile` 构建并运行
4. 默认监听 8089，blitz 边缘自动提供 HTTPS 与公网域名

### 环境变量（blitz Settings → Environment，或 MCP `env_set`）

| 变量 | 必须 | 默认值 | 说明 |
|------|------|--------|------|
| `UUID` | 否 | 仓库内置值 | 节点凭据，vmess/vless id 与 trojan/ss 密码共用 |
| `BLITZ_URL` | **建议** | `localhost:8089` | 公网域名（如 `xray-node.<account>.prod.page`），节点页链接用它 |
| `VMESS_WSPATH` | 否 | `/10000` | vmess WS 路径，以 / 开头 |
| `VLESS_WSPATH` | 否 | `/20000` | vless WS 路径 |
| `TROJAN_WSPATH` | 否 | `/30000` | trojan WS 路径 |
| `SS_WSPATH` | 否 | `/40000` | shadowsocks WS 路径 |

> 改完环境变量后必须**完整重启**应用（blitz 的 env_set 只做 graceful 重启，容器 env 不刷新；面板 Restart 或 MCP `apps_restart confirm:true` 才生效）。

## 节点接入

部署完成后打开 `https://<你的域名>/<UUID>.html`：

- vmess / vless / trojan：直接复制链接导入客户端，或扫对应二维码
- shadowsocks：页面显示明文参数（服务器 / 端口 443 / 密码 = UUID / `chacha20-ietf-poly1305` / ws / TLS）

全部协议均为 **TLS + WebSocket** 传输，`ed=2560` 表示启用 0-RTT 分片。

## 免费计划注意事项

- blitz 免费应用 **15 分钟无访问自动休眠**，首个请求会自动唤醒（约 10 秒），期间表现为 503
- WS 长连接在容器唤醒后重试 1-2 次即可恢复
- 内存限额 512 MB（账户级），本应用占用 128 MB

## 本地构建

```bash
docker build -t xray-node .
docker run --rm -p 8089:8089 \
  -e UUID=$(uuidgen) \
  -e BLITZ_URL=localhost:8089 \
  xray-node
```

打开 `http://localhost:8089/<UUID>.html` 查看节点信息。

## 致谢

- 原项目：[Misaka-blog/replit-xray](https://github.com/Misaka-blog/replit-xray)（Creator: xiaowansm，Modify: ifeng / MisakaNO）
- [XTLS/Xray-core](https://github.com/XTLS/Xray-core)
