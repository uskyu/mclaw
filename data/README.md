# OpenClaw 数据备份

备份时间: $(date -u +"%Y-%m-%dT%H:%M:%SZ")

## 目录结构

- **config/** - OpenClaw 主配置文件
  - `openclaw.json` - 包含模型配置、API密钥、通道设置等

- **memory/** - 长期记忆文件（每日记录）
  - `2026-03-09.md` 等日期文件 - 每日要点和学习记录

- **sessions/** - 会话索引
  - `sessions.json` - 会话元数据和索引信息

## 说明

此备份包含 OpenClaw Gateway 的核心配置和记忆数据。
会话历史文件 (.jsonl) 因文件较大未包含在此备份中。
