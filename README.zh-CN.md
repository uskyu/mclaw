# MClaw

> 语言: [English](./README.md) | **简体中文**

MClaw 是一个 Android 优先的 Flutter OpenClaw Gateway 客户端。

## 主要功能

- 支持 `sshTunnel` 与 `direct`（`ws://` / `wss://`）两种连接模式
- 一键部署直连（已改为点击后直接部署，无需域名输入）
- 流式聊天 + 自动跟随
- Markdown 稳定渲染（表格可横向滚动，普通文本限制在气泡内）
- 图片附件发送（相机/相册）
- Android 后台运行与完成通知
- 版本检测与红点提示
- 中英文支持（默认跟随系统语言）

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

## OpenClaw 相关说明

- 无设备身份场景通常需要开启 `controlUi.allowInsecureAuth: true` 才有写权限。
- 会话修改接口（`sessions.patch` / `sessions.delete`）需要 `operator.admin`。
- 流结束信号可能来自 `agent done` 或 `agent lifecycle end`。

## README 添加图片

使用标准 Markdown 语法：

```md
![首页](./assets/screenshots/home.png)
```

建议：

- 截图统一放在 `assets/screenshots/`
- 使用相对路径（`./assets/screenshots/xxx.png`）
- 文件名用小写加中划线（如 `server-dialog-en.png`）

可点击放大写法：

```md
[![首页](./assets/screenshots/home.png)](./assets/screenshots/home.png)
```

## 界面预览

![首页](./update_hosting/PNG/index.jpg)

![服务器配置](./update_hosting/PNG/sever.jpg)

![侧边栏](./update_hosting/PNG/insder.jpg)

## 开源协议

MIT，详见 [LICENSE](./LICENSE)。
