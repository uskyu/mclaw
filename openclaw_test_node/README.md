# OpenClaw Gateway 连接测试

使用 Node.js 测试与 OpenClaw Gateway 的连接性。

## 快速开始

### 1. 运行测试

```bash
# 进入测试目录
cd openclaw_test_node

# 运行测试 (需要安装 ws 模块)
npm install ws
node test.js

# 或者一步到位
npm install && npm test
```

### 2. 查看结果

测试完成后会显示：
- ✓ 通过的测试项
- ✗ 失败的测试项及原因
- 连接建议和诊断报告

详细结果保存在 `openclaw_test_report.json`

## 测试内容

1. **网络连通性测试** - TCP 连接端口 18789
2. **WebSocket 连接测试** - ws://38.55.181.247:18789
3. **协议握手测试** - OpenClaw 认证流程

## OpenClaw 安全机制

根据官方文档，OpenClaw 采用多层安全：

### 1. Challenge-Response 机制
```
Gateway → Client: connect.challenge {nonce, ts}
Client → Gateway: connect {device: {signature(nonce), publicKey}}
Gateway → Client: hello-ok {deviceToken}
```

### 2. Device Identity
- 非本地连接必须提供设备身份
- 设备需要签名服务器提供的 challenge
- 使用 ECDSA P-256 密钥对

### 3. 认证方式
- **Token 认证**: 提供 Gateway Token
- **Password 认证**: 提供共享密码
- **本地自动批准**: 127.0.0.1 或 tailnet 地址可跳过配对

### 4. 配对流程（远程服务器需要）
```bash
# 在服务器上查看待批准设备
openclaw nodes pending

# 批准设备
openclaw nodes approve <requestId>
```

## 配置信息

测试使用以下配置：

```javascript
{
  gateway: {
    host: '38.55.181.247',
    port: 18789,
    token: '30bfd2b063ab78d7054bdc575678f14591209c7a9789767c'
  }
}
```

## 故障排查

### 网络不通
```bash
# 测试端口连通性
telnet 38.55.181.247 18789

# 或者使用 nc
nc -zv 38.55.181.247 18789
```

### WebSocket 连接失败
1. 确认 Gateway 正在运行
2. 检查防火墙设置
3. 查看 Gateway 日志

### 协议握手失败
1. **Token 无效**: 检查 Gateway Token 是否正确
2. **需要配对**: 远程服务器需要手动批准设备
3. **配置问题**: 检查 Gateway 的 auth.mode 设置

```bash
# SSH 到服务器检查 Gateway 状态
ssh root@38.55.181.247

# 查看 Gateway 日志
openclaw gateway --verbose

# 查看配对状态
openclaw nodes status
openclaw nodes pending
```

## 项目结构

```
openclaw_test_node/
├── test.js          # 主测试脚本
├── package.json     # 项目配置
└── README.md        # 说明文档
```

## 参考文档

- [OpenClaw Gateway Protocol](https://docs.openclaw.ai/gateway/protocol)
- [OpenClaw Pairing](https://docs.openclaw.ai/gateway/pairing)
- [OpenClaw Security](https://docs.openclaw.ai/gateway/security)
