# MClaw App

> Language: **English** | [简体中文](./README.zh-CN.md)

MClaw is an Android-first Flutter client for OpenClaw Gateway, supporting both **SSH tunnel** and **direct WS/WSS** access.

## 1) What It Does

- Chat with OpenClaw through real Gateway protocol flow
- Manage servers/sessions on mobile
- Run with either:
  - `sshTunnel` (forward local port to remote Gateway)
  - `direct` (`ws://` / `wss://`)

## 2) Current Feature Set

- Protocol and chat
  - `connect.challenge -> connect -> hello-ok`
  - `chat.send`, `chat.history`, `chat.abort`
  - `sessions.list`, `sessions.patch`, `sessions.delete`
  - streaming updates from `chat` + `agent`
- Chat UX
  - true streaming display + auto-follow while generating
  - stable markdown: text constrained in bubble, table horizontal scroll
  - stream-time plain-text rendering, final markdown rendering
  - message outline (latest-first)
- Input and attachments
  - quick command panel
  - camera/gallery image sending
  - file entry is kept but marked as “under development”
  - limits: up to 3 images, ~4.8MB each
- Server ops
  - auto detect/fix Gateway config
  - one-click direct deployment (WSS recommended)
  - Gateway restart + remote history cleanup
- Android runtime
  - notification + background runtime onboarding
  - foreground service keep-alive option
  - local notification when long AI task completes in background
- Localization and settings
  - default follows system language (`zh`/`en`)
  - manual language override with persistence
  - privacy/about/help dialogs (project URL copy/open supported)

## 3) Important Notes

- Without `allowInsecureAuth: true`, you may connect but still miss write scope (`missing scope: operator.write`).
- Session mutation APIs usually require `operator.admin` (`sessions.patch` / `sessions.delete`).
- Stream completion can come from both `done` and `agent lifecycle end`.
- Connection mode is selected explicitly (`direct` vs `sshTunnel`), not auto-fallback.

Recommended Gateway snippet (`~/.openclaw/openclaw.json`):

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

Restart after editing:

```bash
systemctl restart openclaw
```

## 4) Project Structure

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

## 5) Storage (Secure)

`flutter_secure_storage` stores:

- server list and active server
- last session key per server
- local conversation notes
- theme mode
- locale override
- notifications/background toggles

## 6) Run and Check

```bash
flutter pub get
flutter run
flutter analyze
```

## 7) Known Limitations

- Attachments are image-only in current `chat.send` path.
- History image thumbnails rely on local paths (cross-device restore is limited).
- Context usage has no official real-time API; UI updates on status query.
- `flutter_markdown` is discontinued; migration to `flutter_markdown_plus` is planned.

## 8) References

- OpenClaw Docs: https://docs.openclaw.ai/
- Gateway Protocol: https://docs.openclaw.ai/gateway/protocol
- Gateway Config: https://docs.openclaw.ai/gateway/configuration-reference
