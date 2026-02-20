# OpenClaw 直连部署脚本

脚本：`tool/openclaw_bootstrap_direct.sh`

## 作用

- 把 Gateway 配置为 `loopback + token`
- 自动补齐 `controlUi.allowedOrigins` 和 `allowInsecureAuth`
- 重启 OpenClaw Gateway
- 可选：配置 Caddy 反向代理，启用 `wss://<domain>`

## 用法

```bash
# 仅直连 WS（不配置域名）
bash tool/openclaw_bootstrap_direct.sh

# 配置域名并启用 WSS
bash tool/openclaw_bootstrap_direct.sh --domain gateway.example.com

# 指定 Gateway 端口
bash tool/openclaw_bootstrap_direct.sh --port 18789
```

## 输出

脚本结束会输出 JSON，包含：

- `gatewayUrl`（如 `ws://x.x.x.x:18789` 或 `wss://gateway.example.com`）
- `gatewayToken`
- `configPath`
- `backupPath`

App 可以直接读取这几个字段自动关联服务器配置。
