# MClaw

Android-first Flutter client for OpenClaw Gateway.

> Language: **English** | [简体中文](./README.zh-CN.md)

## Motivation

This project started from real channel pain points: Telegram markdown rendering was often incompatible, and Feishu API usage had practical limits. To get stable rendering, better control, and a mobile-first workflow, we built an independent OpenClaw client.

## Highlights

- Dual connection modes: `sshTunnel` and `direct` (`ws://` / `wss://`)
- One-click direct deployment (starts immediately, no domain prompt)
- True streaming UI with auto-follow
- Stable markdown rendering (table horizontal scroll, text constrained in bubble)
- Android background runtime + completion notifications
- In-app update check with red-dot indicators
- System-language-aware i18n (`en` / `zh`) with manual override

## Screenshots

<p align="center">
  <img src="./update_hosting/PNG/index.jpg" alt="Home" width="32%" />
  <img src="./update_hosting/PNG/sever.jpg" alt="Server Setup" width="32%" />
  <img src="./update_hosting/PNG/insder.jpg" alt="Sidebar" width="32%" />
</p>

## Quick Start

```bash
flutter pub get
flutter run
```

Build release APK:

```bash
flutter build apk --release
```

Output:

- `build/app/outputs/flutter-apk/app-release.apk`

## Connection Modes

- `sshTunnel`: local forwarded tunnel to remote Gateway
- `direct`: connect directly to Gateway (`ws://` or `wss://`)

For direct mode, you can use **One-click Deploy Direct** in server setup. It will detect runtime status, patch required Gateway config, restart service, verify readiness, and then switch to direct mode.

## Update Distribution

This project supports hosted update checks (for example Cloudflare Pages):

- Manifest: `update_hosting/update.json`
- Download page: `update_hosting/update.html`

The app checks manifest metadata and opens the hosted download page when an update is available.

## Development Docs

- Product/dev summary: [DEVELOPMENT_SUMMARY.md](./DEVELOPMENT_SUMMARY.md)
- Update hosting notes: [update_hosting/README.md](./update_hosting/README.md)

## OpenClaw Notes

- In no-device-identity setups, Gateway may require `controlUi.allowInsecureAuth: true` for write scope.
- `sessions.patch` / `sessions.delete` usually require `operator.admin`.
- Stream completion can come from both `done` and `agent lifecycle end`.

## README Image Usage

Use standard Markdown:

```md
![Home](./assets/screenshots/home.png)
```

Or inline HTML for row layout:

```html
<p>
  <img src="./assets/screenshots/home.png" width="32%" />
  <img src="./assets/screenshots/server.png" width="32%" />
  <img src="./assets/screenshots/sidebar.png" width="32%" />
</p>
```

## License

MIT. See [LICENSE](./LICENSE).
