# ClawChat 开发总结（更新版）

最后更新：2026-02-21

本文件用于记录项目阶段性成果；完整开发说明请优先查看 `README.md`。

## 当前阶段

项目已进入「可用 + 可维护」阶段，核心聊天链路与服务器管理链路可稳定工作。

## 里程碑

### M1：基础连接能力

- 实现 SSH 隧道连接（本地端口转发到远端 Gateway）。
- 实现 Gateway WebSocket 协议握手与请求响应。
- 完成 Provider 架构接入，支持真实消息发送与历史加载。

### M2：会话与状态管理

- 会话列表加载、切换、新建。
- 会话本地备注（仅本机可见）。
- 按服务器恢复上次会话，不再每次强制新建会话。
- 连接状态与错误状态在 UI 中可视化。

### M3：附件与输入体验

- 相机/相册/文件入口统一。
- 图片附件发送链路打通（Base64 + 元信息）。
- 快捷指令面板与上下文用量展示。

### M4：运维与部署能力

- Gateway 配置自动检测与自动修复。
- 支持 `allowedOrigins` 与 `allowInsecureAuth` 自动补齐。
- 支持 Gateway 重启与远程历史清理。
- 一键部署直连模式（可选 Caddy + WSS）。

### M5：渲染与可读性优化（最新）

- Markdown 表格可稳定显示（支持横向滚动）。
- 普通文本限制在聊天气泡内，不再整体溢出。
- 保留代码复制能力与消息长按复制。

## 关键技术结论

- OpenClaw 流式结束信号不只 `done`，`agent lifecycle end` 也需要处理。
- `sessions.patch` / `sessions.delete` 需要 `operator.admin` scope。
- 若无设备身份且未开启 `allowInsecureAuth`，可能出现缺少 `operator.write`。

## 当前限制

- 附件目前仅支持图片发送。
- 历史中的图片缩略图依赖本地路径，跨设备不可完全还原。
- Markdown 依赖仍为 `flutter_markdown`，后续建议迁移到 `flutter_markdown_plus`。

## 下一步建议

1. 迁移 Markdown 渲染库到 `flutter_markdown_plus`。
2. 继续细化块级滚动策略（表格/代码块分离控制）。
3. 增加断线重连和弱网恢复策略。
