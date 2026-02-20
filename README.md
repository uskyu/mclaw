# ClawChat App

Flutter 版 OpenClaw 聊天客户端（Android 优先），支持通过 **SSH 隧道** 或 **直连 WS/WSS** 接入 OpenClaw Gateway。

## 1) 项目目标

- 提供接近 ChatGPT 的移动端聊天体验。
- 稳定接入 OpenClaw Gateway（连接、握手、流式消息、历史、会话管理）。
- 降低运维门槛：支持服务器配置检测、自动修复和一键直连部署。

## 2) 当前能力（已实现）

- 连接模式
  - SSH 隧道模式（本地转发到远端 Gateway）
  - 直连模式（`ws://` / `wss://`）
- Gateway 协议能力
  - `connect.challenge -> connect -> hello-ok`
  - `chat.send`、`chat.history`
  - `sessions.list`、`sessions.patch`、`sessions.delete`
  - `health`
  - `chat`/`agent` 流式事件处理
- 聊天体验
  - 流式输出、加载态、错误态
  - 会话列表与切换、创建新会话
  - 会话本地备注（仅本机）
  - 上次会话按服务器维度恢复
- 输入与附件
  - 快捷指令面板（如 `/status`、`/new`、`/stop`、`/model`）
  - 图片附件发送（相机/相册/文件）
  - 限制：最多 3 张、单张约 4.8MB，仅图片类型
- Markdown 渲染
  - 普通文本限制在气泡内
  - 表格支持横向滚动显示
  - 代码块复制按钮
- 服务器维护工具
  - 自动检测 Gateway 配置
  - 自动修复 `controlUi.allowedOrigins` + `allowInsecureAuth`
  - 重启 Gateway
  - 一键部署直连（可选自动配置 Caddy + WSS）

## 3) 关键约束与协议注意事项

- 若 Gateway 未开启 `allowInsecureAuth: true`，可能出现连接成功但缺少写权限（如 `missing scope: operator.write`）。
- 会话管理相关接口（`sessions.patch` / `sessions.delete`）通常需要 `operator.admin` scope。
- 流结束信号不只 `done`，也可能来自 `agent lifecycle end`，客户端已兼容这两种路径。

推荐 Gateway 配置片段（`~/.openclaw/openclaw.json`）：

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

修改后请重启：

```bash
systemctl restart openclaw
```

## 4) 项目结构

```text
lib/
├── main.dart
├── models/
│   ├── server.dart
│   ├── message.dart
│   ├── chat_attachment.dart
│   └── agent.dart
├── providers/
│   ├── chat_provider.dart
│   └── theme_provider.dart
├── services/
│   ├── gateway_service.dart
│   ├── gateway_protocol_service.dart
│   ├── ssh_tunnel_service.dart
│   ├── ssh_config_service.dart
│   └── secure_storage_service.dart
├── screens/
│   ├── chat_screen.dart
│   ├── server_management_screen.dart
│   └── settings_screen.dart
├── widgets/
│   ├── message_bubble.dart
│   ├── input_toolbar.dart
│   ├── sidebar.dart
│   ├── attachment_menu.dart
│   └── right_drawers.dart
└── theme/
    └── app_theme.dart
```

## 5) 核心数据流

1. UI 调用 `ChatProvider.sendMessage()`。
2. `GatewayService.sendMessage()` 透传到协议层 `chat.send`。
3. Gateway 返回 `runId`，后续通过 `chat`/`agent` 事件流更新内容。
4. `ChatProvider` 合并流式片段，落地到消息列表并刷新会话信息。

## 6) 本地存储（安全）

通过 `flutter_secure_storage` 保存：

- 服务器列表（含 token、连接参数）
- 当前活跃服务器 ID
- 会话本地备注
- 各服务器上次会话 key

## 7) 开发与运行

### 环境要求

- Flutter SDK（Dart 3.9+）
- Android Studio / Android SDK

### 启动

```bash
flutter pub get
flutter run
```

### 质量检查

```bash
flutter analyze
```

## 8) 使用流程（推荐）

1. 打开「服务器管理」，添加服务器（IP + SSH 密码 + Token）。
2. 点击「自动检测 Gateway 配置」。
3. 若提示异常，点击「自动修复」并重启 Gateway。
4. 返回聊天页，确认状态为在线后开始对话。

## 9) 工具脚本

- `tool/openclaw_bootstrap_direct.sh`：远端一键部署直连（可选 WSS）。
- `tool/probe_transports.dart`：验证直连与 SSH 隧道两种链路可用性。
- 详情见 `tool/README_DIRECT_SETUP.md`。

## 10) 已知限制

- 当前附件发送只支持图片类型。
- 历史消息中的图片缩略图以本地路径为主，跨设备/重装后无法完整还原缩略图。
- `flutter_markdown` 已停止维护，后续建议迁移到 `flutter_markdown_plus`。

## 11) 后续建议

- 迁移到 `flutter_markdown_plus`，提升长期兼容性。
- 完善消息块级渲染策略（仅表格/代码块横向滚动）。
- 增加连接重试与网络抖动恢复策略。

## 12) 参考资料

- OpenClaw Docs: https://docs.openclaw.ai/
- Gateway Protocol: https://docs.openclaw.ai/gateway/protocol
- Gateway Config: https://docs.openclaw.ai/gateway/configuration-reference
