# ClawChat App - 开发笔记

## 项目概述

Flutter ChatGPT-like 聊天应用，通过 SSH 隧道连接 OpenClaw Gateway。

**GitHub Repo**: https://github.com/uskyu/mclaw (private)

---

## 重要配置说明

### Gateway 权限配置（关键！）

OpenClaw Gateway 需要 `allowInsecureAuth: true` 才能给无设备身份的客户端完整权限。

**问题**: 连接成功但发送消息报错 `missing scope: operator.write`

**原因**: 没有设备身份(device identity)时，scopes 会被清空，导致没有写权限。

**解决方案**: 在 Gateway 配置中添加：

```json
{
  "gateway": {
    "controlUi": {
      "allowedOrigins": ["*"],
      "allowInsecureAuth": true
    }
  }
}
```

配置文件路径: `/root/.openclaw/openclaw.json` 或 `~/.openclaw/openclaw.json`

**修改后必须重启 Gateway**:
```bash
systemctl restart openclaw
# 或者
pkill -f "openclaw gateway" && openclaw gateway &
```

---

## 操作步骤

### 1. 添加服务器并连接

1. 进入"服务器管理"页面
2. 输入服务器 IP 和 SSH 密码
3. 点击"自动检测 Gateway 配置"
4. 如果检测到问题，点击"自动修复"
5. 等待自动重启 Gateway 服务
6. 返回聊天页面开始对话

### 2. 手动修复 Gateway 配置

如果需要手动修复，通过 SSH 执行：

```bash
# 1. 编辑配置文件
nano ~/.openclaw/openclaw.json

# 2. 添加 controlUi 配置
# 在 gateway 节点下添加:
#   "controlUi": {
#     "allowedOrigins": ["*"],
#     "allowInsecureAuth": true
#   }

# 3. 重启 Gateway
systemctl restart openclaw
```

---

## OpenClaw 协议要点

### WebSocket 连接流程

1. 建立 SSH 隧道 → 本地端口转发到远程 Gateway
2. WebSocket 连接 `ws://127.0.0.1:18789`
3. 等待 `connect.challenge` 事件
4. 发送 `connect` 请求（包含 token、scopes 等）
5. 收到 `hello-ok` 响应，连接完成

### 关键参数

```json
{
  "minProtocol": 3,
  "maxProtocol": 3,
  "client": {
    "id": "webchat-ui",
    "version": "1.0.0",
    "platform": "android",
    "mode": "ui"
  },
  "role": "operator",
  "scopes": ["operator.read", "operator.write"],
  "auth": { "token": "YOUR_TOKEN" }
}
```

### Scope 权限说明

| Scope | 权限 |
|-------|------|
| `operator.read` | 读取状态、历史等 |
| `operator.write` | 发送消息、执行命令等 |
| `operator.admin` | 修改配置、管理代理等 |
| `operator.approvals` | 审批执行请求 |
| `operator.pairing` | 设备配对管理 |

### 常用方法

- `chat.send` - 发送聊天消息
- `chat.history` - 获取聊天历史
- `chat.abort` - 中止当前运行
- `health` - 健康检查
- `sessions.list` - 列出会话

### 事件类型

- `tick` - 心跳
- `health` - 健康状态
- `chat` - 聊天事件（state: delta/final/error/aborted）
- `agent` - 流式输出（stream: assistant/done/usage）

---

## 文件结构

```
lib/
├── main.dart
├── models/
│   ├── server.dart
│   ├── message.dart
│   └── agent.dart
├── providers/
│   ├── chat_provider.dart      # 聊天状态管理
│   └── theme_provider.dart
├── screens/
│   ├── chat_screen.dart
│   ├── server_management_screen.dart
│   └── settings_screen.dart
├── services/
│   ├── gateway_service.dart    # 主服务
│   ├── gateway_protocol_service.dart  # WebSocket 协议
│   ├── ssh_tunnel_service.dart
│   ├── ssh_config_service.dart # 配置检测与修复
│   └── secure_storage_service.dart
├── theme/
│   └── app_theme.dart
└── widgets/
    ├── input_toolbar.dart
    ├── message_bubble.dart
    └── sidebar.dart
```

---

## 参考文档

- OpenClaw 官方文档: https://docs.openclaw.ai/
- Gateway 协议: https://docs.openclaw.ai/gateway/protocol
- 配置参考: https://docs.openclaw.ai/gateway/configuration-reference
