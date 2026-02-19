# OpenClaw Gateway 连接测试报告

**测试时间:** 2026-02-19  
**目标服务器:** 38.55.181.247:18789 (via SSH 隧道)  
**测试状态:** ✅ **连接成功**

---

## 关键发现

### 1. 正确的 Client ID 和 Mode 值

通过查看 OpenClaw 源码 (`src/gateway/protocol/client-info.ts`)，发现：

**Client IDs:**
- `cli` - CLI 客户端
- `webchat`, `webchat-ui` - Web 聊天界面
- `openclaw-control-ui` - 控制面板
- `openclaw-macos`, `openclaw-ios`, `openclaw-android` - 移动端
- `node-host` - 节点主机
- `test` - 测试用

**Client Modes:**
- `cli` - 命令行模式
- `ui` - 用户界面模式
- `webchat` - Web 聊天模式
- `backend` - 后端模式
- `node` - 节点模式
- `probe` - 探测模式
- `test` - 测试模式

**重要：** 官方文档示例中的 `"operator"` 是错误的！正确的 mode 是 `"cli"`。

### 2. Device Identity 可选

从源码 `frames.ts` 可以看到 device 字段是 `Type.Optional`，说明：
- 如果 Gateway 配置了 `allowInsecureAuth: true`，可以不带 device identity
- 生产环境建议启用 device identity 验证

---

## 连接协议流程

```javascript
1. 建立 SSH 隧道
   ssh -N -L 18789:127.0.0.1:18789 root@38.55.181.247

2. 连接 WebSocket
   ws://localhost:18789

3. 接收 challenge
   Gateway → Client: {type: "event", event: "connect.challenge", payload: {nonce, ts}}

4. 发送 connect 请求
   Client → Gateway: {
     type: "req",
     id: "xxx",
     method: "connect",
     params: {
       minProtocol: 3,
       maxProtocol: 3,
       client: {
         id: "cli",           // ✅ 正确的值
         version: "1.0.0",
         platform: "windows",
         mode: "cli"          // ✅ 正确的值（不是 "operator"）
       },
       role: "operator",
       scopes: ["operator.read", "operator.write"],
       auth: { token: "your-token" },
       locale: "zh-CN",
       userAgent: "openclaw-cli/1.0.0"
       // device 字段可选
     }
   }

5. 接收 hello-ok
   Gateway → Client: {
     type: "res",
     ok: true,
     payload: {
       type: "hello-ok",
       protocol: 3,
       server: { version, host, connId },
       features: { methods: [...], events: [...] },
       snapshot: { ... },
       policy: { maxPayload, tickIntervalMs }
     }
   }
```

---

## 测试结果

| 测试项 | 状态 | 详情 |
|--------|------|------|
| SSH 隧道 | ✅ PASS | 本地端口 18789 转发成功 |
| WebSocket 连接 | ✅ PASS | ws://localhost:18789 连接成功 |
| 协议握手 | ✅ PASS | hello-ok 响应正常 |
| Gateway 信息 | ✅ PASS | Server: dev, Protocol: 3 |
| 可用方法 | ✅ PASS | 获取到 100+ 个 API 方法 |
| 对话测试 | ⚠️ SKIP | 需要 operator.write scope |

---

## Gateway 能力清单

### 支持的 API 方法 (部分)
- `health` - 健康检查
- `status` - 状态查询
- `config.get/set/apply` - 配置管理
- `channels.status` - 频道状态
- `agents.list/create/update` - 代理管理
- `skills.status/install` - 技能管理
- `sessions.list/patch/reset` - 会话管理
- `chat.history/send` - 聊天功能
- `send` - 发送消息
- `agent` - 运行代理
- `cron.list/add/remove` - 定时任务
- `device.pair.list/approve` - 设备配对
- `node.list/invoke` - 节点管理
- `logs.tail` - 日志查看

### 支持的事件
- `connect.challenge` - 连接挑战
- `agent` - 代理事件
- `chat` - 聊天事件
- `presence` - 在线状态
- `tick` - 心跳
- `health` - 健康状态
- `cron` - 定时任务
- `device.pair.requested` - 设备配对请求

---

## 服务器信息

```json
{
  "version": "dev",
  "host": "S4Mgv7nLZmH7f111",
  "platform": "linux 6.8.0-48-generic",
  "deviceFamily": "Linux",
  "modelIdentifier": "x64",
  "mode": "gateway",
  "uptimeMs": 16316747,
  "configPath": "/root/.openclaw/openclaw.json",
  "stateDir": "/root/.openclaw"
}
```

---

## 下一步建议

1. **配置 Scope:**
   当前 Token 可能缺少某些 scope，建议检查 Gateway 配置或生成新的 Token。

2. **Device Identity:**
   为生产环境实现完整的 device identity 生成和签名逻辑。

3. **Flutter 客户端开发:**
   - 使用 `webchat-ui` 作为 client.id
   - 使用 `ui` 作为 client.mode
   - 实现 WebSocket 连接
   - 实现 chat.send 和 chat.history 方法
   - 处理 agent/chat 事件

4. **API 探索:**
   可用方法非常丰富，建议根据需求探索：
   - 对话：chat.send, chat.history
   - 代理：agent, agent.identity.get
   - 会话：sessions.list, sessions.patch
   - 配置：config.get, config.set

---

## 总结

✅ **连接测试成功！** OpenClaw Gateway 可以通过 SSH 隧道正常访问，协议握手成功，服务器功能完整。现在可以开始 Flutter 客户端的开发。

关键要点：
1. 必须使用 SSH 隧道连接远程 Gateway
2. client.id 必须是特定值（如 "cli", "webchat-ui"）
3. client.mode 必须是特定值（如 "cli", "ui"）
4. device 字段可选（取决于 Gateway 配置）
5. Token 需要正确的 scope 才能执行写操作
