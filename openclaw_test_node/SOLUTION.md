# OpenClaw Gateway 连接解决方案

## 🔒 问题原因

根据 [OpenClaw 官方文档](https://docs.openclaw.ai/gateway/remote)，**Gateway 默认绑定到 127.0.0.1 (loopback)**，这是出于安全考虑的设计：

> "The Gateway WebSocket binds to **loopback** on your configured port (defaults to 18789)."
> 
> "For remote use, you forward that loopback port over SSH (or use a tailnet/VPN and tunnel less)."

这就是为什么我们能连通 TCP 端口，但 WebSocket 无法建立连接的原因。

---

## ✅ 解决方案

### 方案 1: SSH 隧道（推荐用于开发测试）⭐

**步骤：**

1. **建立 SSH 隧道**（在本地终端运行，保持运行）：
```bash
ssh -N -L 18789:127.0.0.1:18789 root@38.55.181.247
# 密码: bustUPPF6115
```

2. **测试连接**：
```bash
cd openclaw_test_node
node test_with_tunnel.js
```

**原理：**
```
本地端口 18789 ← SSH 隧道 → 远程 127.0.0.1:18789
              ↑
        加密安全通道
```

**优点：**
- 最安全的方式
- 不需要修改服务器配置
- 符合 OpenClaw 安全最佳实践

---

### 方案 2: 修改 Gateway 配置（不推荐）

**警告：** 这会降低安全性，仅用于测试

1. **SSH 登录服务器**：
```bash
ssh root@38.55.181.247
```

2. **编辑配置**：
```bash
nano ~/.openclaw/openclaw.json
```

3. **修改绑定地址**：
```json
{
  "gateway": {
    "bind": "0.0.0.0",
    "port": 18789,
    "auth": {
      "mode": "token",
      "token": "30bfd2b063ab78d7054bdc575678f14591209c7a9789767c"
    }
  }
}
```

4. **重启 Gateway**：
```bash
openclaw gateway restart
```

---

### 方案 3: 在服务器上直接测试

直接在服务器上运行测试：
```bash
ssh root@38.55.181.247
# 安装 Node.js 和测试脚本
# 运行测试
```

---

## 📋 OpenClaw 安全机制详解

### 1. 默认安全设置
```json
{
  "gateway": {
    "bind": "loopback",      // 仅本地可访问
    "auth": { "mode": "token" }  // 需要认证
  }
}
```

### 2. 远程访问的最佳实践
官方推荐的安全层级：

| 安全级别 | 方案 | 适用场景 |
|---------|------|---------|
| 🔴 最低 | `bind: "0.0.0.0"` | 临时测试 |
| 🟡 中等 | `bind: "tailnet"` | Tailscale 网络 |
| 🟢 最高 | `bind: "loopback"` + SSH 隧道 | 生产环境 |

### 3. 连接流程
```
┌─────────────┐    SSH 隧道     ┌──────────────────┐
│  本地客户端  │ ←────────────→ │  远程服务器       │
│  localhost  │   加密通道      │  127.0.0.1:18789 │
│  :18789     │                │  (Gateway)       │
└─────────────┘                └──────────────────┘
```

---

## 🔧 测试脚本使用说明

### 前置要求

1. **建立 SSH 隧道**（在单独的终端窗口）：
```bash
ssh -N -L 18789:127.0.0.1:18789 root@38.55.181.247
```

2. **运行测试**：
```bash
cd openclaw_test_node
npm install
node test_with_tunnel.js
```

### 预期输出
```
======================================================
OpenClaw Gateway 连接测试 (SSH 隧道模式)
======================================================
目标服务器: 38.55.181.247
本地转发:   localhost:18789
设备ID:     device_xxxxx
======================================================

【步骤 1】检查 SSH 隧道...
✓ 隧道连接正常

【步骤 2】WebSocket 连接测试...
✓ WebSocket 连接成功
  收到消息: event connect.challenge
  收到 challenge，正在签名...
  已发送 connect 请求
  收到消息: res

======================================================
✓ 协议握手成功！
  协议版本: 3
  Device Token: xxxxx...

Gateway 连接正常，可以开始开发 Flutter 客户端。
======================================================
```

---

## 🚀 下一步行动

1. **选择连接方案**：
   - 开发测试：使用 SSH 隧道（方案 1）
   - 长期使用：考虑 Tailscale（更安全）

2. **验证连接**：
   ```bash
   node test_with_tunnel.js
   ```

3. **开发 Flutter 客户端**：
   - 使用 `localhost:18789` 作为 Gateway 地址
   - 实现 WebSocket 连接
   - 实现 challenge-response 握手
   - 实现设备身份签名

---

## 📚 参考文档

- [OpenClaw Remote Access](https://docs.openclaw.ai/gateway/remote)
- [OpenClaw Security](https://docs.openclaw.ai/gateway/security)
- [OpenClaw Gateway Protocol](https://docs.openclaw.ai/gateway/protocol)
- [Tailscale Integration](https://docs.openclaw.ai/gateway/tailscale)

---

## 💡 关键要点

1. **安全设计**：OpenClaw 故意不让 Gateway 直接暴露在外网
2. **SSH 隧道**：推荐的远程访问方式，加密且安全
3. **设备配对**：首次连接需要签名 challenge，后续使用 device token
4. **Token 认证**：必须使用有效的 Gateway Token

现在请建立 SSH 隧道并运行测试脚本验证连接！
