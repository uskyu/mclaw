# ClawChat App

> Language: **English** | [简体中文](./README.zh-CN.md)

A Flutter OpenClaw chat client (Android-first) that connects to OpenClaw Gateway via **SSH tunnel** or **direct WS/WSS**.

## 1) Goals

- Deliver a ChatGPT-like mobile chat experience.
- Keep OpenClaw integration stable (connect, handshake, streaming, history, sessions).
- Reduce ops burden with auto-detect, auto-fix, and one-click direct deployment.

## 2) Implemented Features

- Connection modes
  - SSH tunnel (local forward to remote Gateway)
  - Direct mode (`ws://` / `wss://`)
- Gateway protocol support
  - `connect.challenge -> connect -> hello-ok`
  - `chat.send`, `chat.history`
  - `sessions.list`, `sessions.patch`, `sessions.delete`
  - `health`
  - Streaming event handling for `chat` / `agent`
- Chat UX
  - Streaming output, loading state, error state
  - Session list, switching, and new session
  - Local-only conversation notes
  - Last session restore per server
- Input and attachments
  - Quick commands (e.g. `/status`, `/new`, `/stop`, `/model`)
  - Image attachments (camera/gallery/file picker)
  - Limits: max 3 images, ~4.8MB per image, image type only
- Markdown rendering
  - Regular text stays constrained inside bubble
  - Tables can scroll horizontally
  - Copy button for code blocks
- Server maintenance tools
  - Auto-detect Gateway config
  - Auto-fix `controlUi.allowedOrigins` + `allowInsecureAuth`
  - Restart Gateway
  - One-click direct deployment (optional Caddy + WSS)

## 3) Important Protocol Notes

- If Gateway does not enable `allowInsecureAuth: true`, you may connect but still miss write permission (e.g. `missing scope: operator.write`).
- Session management APIs (`sessions.patch` / `sessions.delete`) typically require `operator.admin` scope.
- Stream completion may come from `done` or `agent lifecycle end`; client handles both.

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

## 5) Core Data Flow

1. UI calls `ChatProvider.sendMessage()`.
2. `GatewayService.sendMessage()` forwards to protocol layer `chat.send`.
3. Gateway returns `runId`, then streams updates via `chat` / `agent` events.
4. `ChatProvider` merges chunks and updates message/session state.

## 6) Local Secure Storage

Using `flutter_secure_storage` for:

- Server list (including token and connection config)
- Active server ID
- Local conversation notes
- Last session key per server

## 7) Development

### Requirements

- Flutter SDK (Dart 3.9+)
- Android Studio / Android SDK

### Run

```bash
flutter pub get
flutter run
```

### Check

```bash
flutter analyze
```

## 8) Recommended Usage Flow

1. Open Server Management and add a server (IP + SSH password + token).
2. Run "Auto detect Gateway config".
3. If issues are found, run "Auto fix" and restart Gateway.
4. Return to chat page and confirm online status.

## 9) Tooling Scripts

- `tool/openclaw_bootstrap_direct.sh`: one-click remote direct deployment (optional WSS).
- `tool/probe_transports.dart`: validate direct and SSH-tunnel transport paths.
- See `tool/README_DIRECT_SETUP.md` for details.

## 10) Known Limitations

- Attachment sending currently supports images only.
- History image thumbnails mainly rely on local paths and cannot be fully restored across devices/reinstall.
- `flutter_markdown` is discontinued; migrate to `flutter_markdown_plus` for long-term compatibility.

## 11) Next Suggestions

- Migrate to `flutter_markdown_plus`.
- Further refine block-level rendering behavior (table/code-only horizontal scroll).
- Add reconnect and unstable-network recovery strategy.

## 12) References

- OpenClaw Docs: https://docs.openclaw.ai/
- Gateway Protocol: https://docs.openclaw.ai/gateway/protocol
- Gateway Config: https://docs.openclaw.ai/gateway/configuration-reference
