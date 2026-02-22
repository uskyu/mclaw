# MClaw

面向 Android 的 Flutter OpenClaw Gateway 客户端。

> 语言: [English](./README.md) | **简体中文**

## 项目初衷

这个项目来自真实使用痛点：Telegram 的 Markdown 兼容性不稳定，而飞书 API 在调用上也有实际限制。为了获得更稳定的渲染、更可控的连接体验和移动端优先工作流，我们做了一个独立的 OpenClaw 移动客户端。

## 主要功能

- 双连接模式：`sshTunnel` 与 `direct`（`ws://` / `wss://`）
- 一键部署直连（点击后立即部署，不再要求域名输入）
- 真流式显示与自动跟随
- Markdown 稳定渲染（表格横向滚动、普通文本不溢出）
- Android 后台运行与完成通知
- 版本检测与红点提示
- 中英文支持（默认跟随系统语言，可手动切换）

## 界面预览

<p align="center">
  <img src="./update_hosting/PNG/index.jpg" alt="首页" width="32%" />
  <img src="./update_hosting/PNG/sever.jpg" alt="服务器配置" width="32%" />
  <img src="./update_hosting/PNG/insder.jpg" alt="侧边栏" width="32%" />
</p>

## 快速开始

```bash
flutter pub get
flutter run
```

打包 Release APK：

```bash
flutter build apk --release
```

输出路径：

- `build/app/outputs/flutter-apk/app-release.apk`

## 连接模式

- `sshTunnel`：通过本地端口转发连接远端 Gateway
- `direct`：直接连接 Gateway（`ws://` / `wss://`）

在服务器页面可使用“一键部署直连”，流程会自动检测运行态、修正关键配置、重启服务并验收，然后切换到直连模式。

## 更新分发

项目支持托管式版本检测（例如 Cloudflare Pages）：

- 清单文件：`update_hosting/update.json`
- 下载落地页：`update_hosting/update.html`

App 检测到新版本后会显示红点并打开托管下载页。

## 开发文档

- 开发总结：[`DEVELOPMENT_SUMMARY.md`](./DEVELOPMENT_SUMMARY.md)
- 更新托管说明：[`update_hosting/README.md`](./update_hosting/README.md)

## OpenClaw 说明

- 无设备身份场景下，Gateway 通常需要 `controlUi.allowInsecureAuth: true` 才能获得写权限。
- `sessions.patch` / `sessions.delete` 通常需要 `operator.admin`。
- 流结束信号可能来自 `done` 或 `agent lifecycle end`。

## README 添加图片

标准 Markdown 写法：

```md
![首页](./assets/screenshots/home.png)
```

横向排列可用 HTML：

```html
<p>
  <img src="./assets/screenshots/home.png" width="32%" />
  <img src="./assets/screenshots/server.png" width="32%" />
  <img src="./assets/screenshots/sidebar.png" width="32%" />
</p>
```

## 开源协议

MIT，详见 [LICENSE](./LICENSE)。
