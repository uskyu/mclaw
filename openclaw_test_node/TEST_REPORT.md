# OpenClaw Gateway 连接测试报告

**测试时间:** 2026-02-19  
**目标服务器:** 38.55.181.247:18789  
**测试工具:** Node.js + WebSocket

---

## 测试结果摘要

| 测试项 | 状态 | 说明 |
|--------|------|------|
| TCP 网络连通性 | ✅ PASS | 端口 18789 可达，2ms 延迟 |
| HTTP 接口 | ❌ FAIL | 无响应 |
| WebSocket 连接 | ❌ FAIL | 连接超时 (10s) |
| OpenClaw 协议握手 | ⏸️ SKIP | WebSocket 未连接 |

**结论:** 网络层可达，但应用层（HTTP/WebSocket）无响应

---

## 详细分析

### 1. 网络层正常 ✅
```
TCP 连接到 38.55.181.247:18789: SUCCESS (2ms)
```
- 服务器在线
- 端口已开放
- 无防火墙阻断 TCP

### 2. 应用层异常 ❌

**HTTP 测试:**
```bash
curl http://38.55.181.247:18789/
结果: 连接失败 (000)
```

**WebSocket 测试:**
```javascript
ws://38.55.181.247:18789
结果: 连接超时
```

---

## 可能原因

根据 OpenClaw 官方文档，可能的情况：

### 情况 A: Gateway 未运行
OpenClaw Gateway 需要手动启动：
```bash
ssh root@38.55.181.247
openclaw gateway --port 18789 --verbose
```

### 情况 B: Gateway 绑定到 localhost
Gateway 配置可能绑定了 127.0.0.1：
```json
{
  "gateway": {
    "bind": "loopback"  // 或 "127.0.0.1"
  }
}
```
需要修改为：
```json
{
  "gateway": {
    "bind": "0.0.0.0",
    "auth": {
      "mode": "token",
      "token": "30bfd2b063ab78d7054bdc575678f14591209c7a9789767c"
    }
  }
}
```

### 情况 C: 需要 SSH 隧道
OpenClaw 官方推荐远程访问使用 SSH 隧道：
```bash
ssh -N -L 18789:127.0.0.1:18789 root@38.55.181.247
# 然后在本地连接 ws://localhost:18789
```

### 情况 D: Gateway 配置了特定路径
WebSocket 可能需要特定路径：
- `ws://host:18789/ws`
- `ws://host:18789/socket`
- `ws://host:18789/__openclaw__/ws`

---

## 建议的排查步骤

### 步骤 1: SSH 登录服务器检查 Gateway 状态
```bash
ssh root@38.55.181.247

# 检查 Gateway 是否在运行
ps aux | grep openclaw

# 检查端口占用
netstat -tlnp | grep 18789
lsof -i :18789

# 查看 Gateway 日志
journalctl -u openclaw -f
# 或
tail -f ~/.openclaw/logs/gateway.log
```

### 步骤 2: 检查 Gateway 配置
```bash
cat ~/.openclaw/openclaw.json

# 关键配置项:
# - gateway.bind: 应该是 "0.0.0.0" 而不是 "loopback"
# - gateway.port: 应该是 18789
# - gateway.auth.mode: 建议 "token" 或 "password"
```

### 步骤 3: 服务器本地测试
```bash
# 在服务器上测试本地连接
curl http://localhost:18789/

# 测试 WebSocket (需要 wscat)
npm install -g wscat
wscat -c ws://localhost:18789
```

### 步骤 4: 启动 Gateway（如未运行）
```bash
# 前台运行（用于调试）
openclaw gateway --port 18789 --verbose

# 或使用配置
openclaw gateway --config ~/.openclaw/openclaw.json
```

### 步骤 5: 设置 SSH 隧道（推荐）
```bash
# 在本地机器上运行
ssh -N -L 18789:127.0.1:18789 root@38.55.181.247

# 然后测试连接
node test.js
# 修改 config.js 中的 host 为 "localhost"
```

---

## OpenClaw 安全机制说明

根据官方文档，连接 OpenClaw Gateway 需要：

### 1. 协议流程
```
Client → Gateway: WebSocket 连接
Gateway → Client: connect.challenge {nonce, ts}
Client → Gateway: connect {device: {签名后的 nonce}, auth: {token}}
Gateway → Client: hello-ok {deviceToken}
```

### 2. Device Identity
- 非本地连接必须提供设备身份
- 需要 ECDSA 密钥对签名 challenge
- 首次连接需要配对批准（除非本地自动批准）

### 3. 认证方式
- **Token 模式:** 提供 `gateway.token`
- **Password 模式:** 提供共享密码
- **Tailscale 模式:** 使用 tailnet 身份

---

## 下一步行动

在继续开发 Flutter 客户端之前，请确认：

1. ✅ Gateway 已在服务器上运行
2. ✅ Gateway 配置绑定到 0.0.0.0（或设置 SSH 隧道）
3. ✅ Token `30bfd2b063ab78d7054bdc575678f14591209c7a9789767c` 有效
4. ✅ 防火墙允许端口 18789 的入站连接

完成后可以重新运行测试脚本验证连接。

---

## 文件位置

测试脚本位于：`openclaw_test_node/test.js`

运行命令：
```bash
cd openclaw_test_node
npm install
node test.js
```
