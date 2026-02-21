# MClaw App

> 语言: [English](./README.md) | **简体中文**

MClaw 是一个 Android 优先的 Flutter OpenClaw 客户端，支持 **SSH 隧道** 和 **直连 WS/WSS** 两种接入方式。

## 1) 项目能力定位

- 在移动端稳定接入 OpenClaw Gateway
- 提供可用的会话管理与流式聊天体验
- 降低部署门槛（自动检测/修复 + 一键直连部署）

## 2) 当前已实现

- 协议与聊天
  - `connect.challenge -> connect -> hello-ok`
  - `chat.send`、`chat.history`、`chat.abort`
  - `sessions.list`、`sessions.patch`、`sessions.delete`
  - 兼容 `chat` 与 `agent` 流事件
- 聊天体验
  - 真流式显示 + 生成中自动跟随
  - Markdown 稳定渲染：普通文本不溢出，表格可横向滚动
  - 流式阶段先纯文本，完成后切回 Markdown
  - 消息大纲改为倒序（最新在上）
- 输入与附件
  - 快捷指令面板
  - 相机/相册图片发送
  - 文件入口保留并标注开发中
  - 限制：最多 3 张，单张约 4.8MB
- 服务器维护
  - Gateway 配置自动检测与修复
  - 一键部署直连（推荐 WSS）
  - Gateway 重启与远程历史清理
- Android 运行能力
  - 首次通知/后台运行引导
  - 前台服务保活（后台运行）
  - App 在后台时，任务完成可本地通知
- 国际化与设置
  - 默认跟随系统语言（中/英）
  - 手动语言切换并持久化
  - 隐私/帮助/关于弹窗，支持项目地址复制与跳转

## 3) 关键协议说明

- 若 Gateway 未开启 `allowInsecureAuth: true`，可能连接成功但无写权限（`missing scope: operator.write`）。
- 会话修改接口通常需要 `operator.admin`（`sessions.patch` / `sessions.delete`）。
- 流结束信号不止 `done`，还需兼容 `agent lifecycle end`。
- 连接模式为手动选择（`direct` / `sshTunnel`），当前不做自动兜底切换。

推荐 Gateway 配置（`~/.openclaw/openclaw.json`）：

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

修改后重启：

```bash
systemctl restart openclaw
```

## 4) 项目结构

```text
lib/
├── main.dart
├── models/
├── providers/
│   ├── chat_provider.dart
│   └── theme_provider.dart
├── services/
│   ├── gateway_service.dart
│   ├── gateway_protocol_service.dart
│   ├── ssh_tunnel_service.dart
│   ├── ssh_config_service.dart
│   ├── secure_storage_service.dart
│   ├── notification_service.dart
│   └── background_runtime_service.dart
├── screens/
│   ├── chat_screen.dart
│   ├── server_management_screen.dart
│   └── settings_screen.dart
├── widgets/
│   ├── message_bubble.dart
│   ├── input_toolbar.dart
│   ├── sidebar.dart
│   ├── attachment_menu.dart
│   ├── right_drawers.dart
│   └── app_logo.dart
└── theme/
    └── app_theme.dart
```

## 5) 本地安全存储

`flutter_secure_storage` 当前保存：

- 服务器列表与当前激活服务器
- 各服务器上次会话 key
- 会话本地备注
- 主题模式
- 语言偏好（手动覆盖）
- 通知/后台运行开关状态

## 6) 开发运行

```bash
flutter pub get
flutter run
flutter analyze
```

## 7) 已知限制

- 当前 `chat.send` 链路附件仅支持图片。
- 历史图片缩略图依赖本地路径，跨设备恢复有限。
- 上下文百分比无官方实时接口，仅在状态查询时刷新。
- `flutter_markdown` 已停止维护，后续建议迁移 `flutter_markdown_plus`。

## 8) 参考资料

- OpenClaw Docs: https://docs.openclaw.ai/
- Gateway Protocol: https://docs.openclaw.ai/gateway/protocol
- Gateway Config: https://docs.openclaw.ai/gateway/configuration-reference
