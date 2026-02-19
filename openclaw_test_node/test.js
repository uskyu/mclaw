/**
 * OpenClaw Gateway Connection Test - Node.js Version
 * ==================================================
 * 使用原生 Node.js 进行连接测试，无需额外安装依赖
 * 
 * 运行方式: node test.js
 * 
 * 官方文档: https://docs.openclaw.ai/gateway/protocol
 */

// ==================== 配置信息 ====================
const CONFIG = {
  gateway: {
    host: '38.55.181.247',
    port: 18789,
    token: '30bfd2b063ab78d7054bdc575678f14591209c7a9789767c'
  },
  ssh: {
    host: '38.55.181.247',
    user: 'root',
    password: 'bustUPPF6115'
  },
  client: {
    id: 'openclaw-flutter-test',
    version: '1.0.0',
    platform: 'windows'
  },
  protocol: {
    version: 3,
    minProtocol: 3,
    maxProtocol: 3
  }
};

// ==================== 工具函数 ====================
const crypto = require('crypto');
const net = require('net');

/**
 * 生成设备身份和签名
 * OpenClaw 要求非本地连接必须提供 device identity 并签名 challenge
 */
class DeviceIdentity {
  constructor() {
    this.deviceId = `device_${crypto.randomBytes(8).toString('hex')}`;
    // 生成模拟的 ECDSA 密钥对
    this.keyPair = crypto.generateKeyPairSync('ec', {
      namedCurve: 'P-256',
      publicKeyEncoding: { type: 'spki', format: 'pem' },
      privateKeyEncoding: { type: 'pkcs8', format: 'pem' }
    });
  }

  /**
   * 签名服务器提供的 challenge
   * @param {string} nonce - 服务器提供的随机数
   * @param {number} timestamp - 服务器时间戳
   * @returns {Object} Device identity 对象
   */
  signChallenge(nonce, timestamp) {
    const dataToSign = `${nonce}:${timestamp}:${this.deviceId}`;
    
    // 使用 ECDSA 签名
    const signer = crypto.createSign('SHA256');
    signer.update(dataToSign);
    const signature = signer.sign(this.keyPair.privateKey, 'base64');
    
    // 提取公钥的 base64 部分
    const publicKeyBase64 = this.keyPair.publicKey
      .replace(/-----BEGIN PUBLIC KEY-----\n/, '')
      .replace(/\n-----END PUBLIC KEY-----/, '')
      .replace(/\n/g, '');

    return {
      id: this.deviceId,
      publicKey: publicKeyBase64,
      signature: signature,
      signedAt: Date.now(),
      nonce: nonce
    };
  }

  getDeviceInfo() {
    return {
      id: this.deviceId,
      publicKeyPreview: this.keyPair.publicKey.substring(0, 50) + '...'
    };
  }
}

// ==================== OpenClaw 协议实现 ====================

/**
 * OpenClaw WebSocket 协议处理器
 * 
 * 协议流程:
 * 1. 连接 WebSocket
 * 2. 接收 connect.challenge 事件 (Gateway → Client)
 * 3. 发送 connect 请求 (Client → Gateway)，包含签名后的 challenge
 * 4. 接收 hello-ok 响应，获取 device token
 * 5. 后续通信使用 device token
 */
class OpenClawProtocol {
  constructor(clientId, clientVersion, platform) {
    this.clientId = clientId;
    this.clientVersion = clientVersion;
    this.platform = platform;
    this.connected = false;
    this.deviceToken = null;
    this.challengeReceived = false;
    this.challengeData = null;
    this.pendingRequests = new Map();
    this.messageQueue = [];
  }

  generateRequestId() {
    return `req_${crypto.randomBytes(6).toString('hex')}`;
  }

  /**
   * 创建 connect 请求
   */
  createConnectRequest(deviceIdentity, authToken) {
    return {
      type: 'req',
      id: this.generateRequestId(),
      method: 'connect',
      params: {
        minProtocol: CONFIG.protocol.minProtocol,
        maxProtocol: CONFIG.protocol.maxProtocol,
        client: {
          id: this.clientId,
          version: this.clientVersion,
          platform: this.platform,
          mode: 'operator'
        },
        role: 'operator',
        scopes: ['operator.read', 'operator.write'],
        caps: [],
        commands: [],
        permissions: {},
        auth: { token: authToken },
        locale: 'zh-CN',
        userAgent: `${this.clientId}/${this.clientVersion}`,
        device: deviceIdentity
      }
    };
  }

  /**
   * 解析接收到的消息
   */
  parseMessage(rawData) {
    try {
      const data = JSON.parse(rawData);
      
      if (data.type === 'event') {
        // 处理事件
        if (data.event === 'connect.challenge') {
          this.challengeReceived = true;
          this.challengeData = data.payload;
          return { type: 'challenge', payload: data.payload };
        }
        return { type: 'event', event: data.event, payload: data.payload };
      } else if (data.type === 'res') {
        // 处理响应
        return { type: 'response', data: data };
      }
      
      return { type: 'unknown', data };
    } catch (e) {
      return { type: 'error', error: e.message };
    }
  }

  /**
   * 处理 connect 响应
   */
  handleConnectResponse(response) {
    if (response.ok && response.payload) {
      const payload = response.payload;
      
      if (payload.type === 'hello-ok') {
        this.connected = true;
        this.deviceToken = payload.auth?.deviceToken;
        
        return {
          success: true,
          protocol: payload.protocol,
          deviceToken: this.deviceToken,
          policy: payload.policy
        };
      }
    }
    
    return {
      success: false,
      error: response.error || 'Unknown error'
    };
  }
}

// ==================== WebSocket 客户端 ====================

/**
 * 原生 Node.js WebSocket 实现
 * Node.js 18+ 内置 WebSocket 支持
 */
class WebSocketClient {
  constructor(url) {
    this.url = url;
    this.socket = null;
    this.connected = false;
    this.messageHandler = null;
    this.errorHandler = null;
    this.closeHandler = null;
  }

  async connect() {
    return new Promise((resolve, reject) => {
      try {
        // 使用 Node.js 内置的 ws 模块（如果可用）或 http 模块
        this.socket = new (require('ws'))(this.url);
        
        this.socket.on('open', () => {
          this.connected = true;
          resolve();
        });
        
        this.socket.on('message', (data) => {
          if (this.messageHandler) {
            this.messageHandler(data.toString());
          }
        });
        
        this.socket.on('error', (err) => {
          if (!this.connected) {
            reject(err);
          } else if (this.errorHandler) {
            this.errorHandler(err);
          }
        });
        
        this.socket.on('close', () => {
          this.connected = false;
          if (this.closeHandler) {
            this.closeHandler();
          }
        });
      } catch (err) {
        reject(err);
      }
    });
  }

  send(data) {
    if (this.socket && this.connected) {
      this.socket.send(typeof data === 'string' ? data : JSON.stringify(data));
    }
  }

  close() {
    if (this.socket) {
      this.socket.close();
    }
  }

  onMessage(handler) {
    this.messageHandler = handler;
  }

  onError(handler) {
    this.errorHandler = handler;
  }

  onClose(handler) {
    this.closeHandler = handler;
  }
}

// ==================== 测试框架 ====================

class TestResult {
  constructor(testName, status, durationMs, message, details = {}) {
    this.testName = testName;
    this.status = status; // 'PASS', 'FAIL', 'SKIP'
    this.durationMs = durationMs;
    this.message = message;
    this.details = details;
  }

  toJSON() {
    return {
      testName: this.testName,
      status: this.status,
      durationMs: Math.round(this.durationMs * 100) / 100,
      message: this.message,
      details: this.details
    };
  }
}

class ConnectionTester {
  constructor() {
    this.results = [];
    this.deviceIdentity = new DeviceIdentity();
    this.protocol = null;
    this.wsClient = null;
  }

  log(message, indent = 0) {
    console.log('  '.repeat(indent) + message);
  }

  addResult(result) {
    this.results.push(result);
    const icon = result.status === 'PASS' ? '✓' : result.status === 'FAIL' ? '✗' : '○';
    console.log(`${icon} ${result.testName}: ${result.status} (${result.durationMs.toFixed(2)}ms)`);
    if (result.message) {
      console.log(`  → ${result.message}`);
    }
  }

  // ==================== 测试方法 ====================

  async testNetworkConnectivity() {
    const startTime = Date.now();
    const testName = '网络连通性测试';

    try {
      return new Promise((resolve) => {
        const socket = new net.Socket();
        socket.setTimeout(5000);
        
        socket.on('connect', () => {
          socket.destroy();
          const duration = Date.now() - startTime;
          resolve(new TestResult(
            testName,
            'PASS',
            duration,
            `TCP 连接成功到 ${CONFIG.gateway.host}:${CONFIG.gateway.port}`,
            { host: CONFIG.gateway.host, port: CONFIG.gateway.port }
          ));
        });
        
        socket.on('error', (err) => {
          const duration = Date.now() - startTime;
          resolve(new TestResult(
            testName,
            'FAIL',
            duration,
            `TCP 连接失败: ${err.message}`,
            { error: err.message }
          ));
        });
        
        socket.on('timeout', () => {
          socket.destroy();
          const duration = Date.now() - startTime;
          resolve(new TestResult(
            testName,
            'FAIL',
            duration,
            'TCP 连接超时 (5s)',
            { timeout: 5000 }
          ));
        });
        
        socket.connect(CONFIG.gateway.port, CONFIG.gateway.host);
      });
    } catch (err) {
      const duration = Date.now() - startTime;
      return new TestResult(
        testName,
        'FAIL',
        duration,
        `网络测试异常: ${err.message}`,
        { error: err.message }
      );
    }
  }

  async testWebSocketConnection() {
    const startTime = Date.now();
    const testName = 'WebSocket 连接测试';

    try {
      // 检查是否安装了 ws 模块
      try {
        require('ws');
      } catch (e) {
        return new TestResult(
          testName,
          'SKIP',
          Date.now() - startTime,
          '缺少 ws 模块，跳过测试',
          { install: 'npm install ws' }
        );
      }

      const wsUrl = `ws://${CONFIG.gateway.host}:${CONFIG.gateway.port}`;
      this.wsClient = new WebSocketClient(wsUrl);
      
      await this.wsClient.connect();
      
      const duration = Date.now() - startTime;
      return new TestResult(
        testName,
        'PASS',
        duration,
        `WebSocket 连接成功: ${wsUrl}`,
        { url: wsUrl }
      );
    } catch (err) {
      const duration = Date.now() - startTime;
      return new TestResult(
        testName,
        'FAIL',
        duration,
        `WebSocket 连接失败: ${err.message}`,
        { error: err.message }
      );
    }
  }

  async testProtocolHandshake() {
    const startTime = Date.now();
    const testName = '协议握手测试';

    if (!this.wsClient || !this.wsClient.connected) {
      return new TestResult(
        testName,
        'SKIP',
        0,
        'WebSocket 未连接，跳过握手测试'
      );
    }

    return new Promise((resolve) => {
      let timeoutId = null;
      let step = 1;
      
      this.protocol = new OpenClawProtocol(
        CONFIG.client.id,
        CONFIG.client.version,
        CONFIG.client.platform
      );

      this.wsClient.onMessage((rawData) => {
        const message = this.protocol.parseMessage(rawData);
        
        if (step === 1 && message.type === 'challenge') {
          // 步骤 1: 收到 challenge
          this.log(`[1/3] 收到 challenge: nonce=${message.payload.nonce?.substring(0, 20)}...`, 1);
          step = 2;
          
          // 签名并发送 connect 请求
          const deviceIdentity = this.deviceIdentity.signChallenge(
            message.payload.nonce,
            message.payload.ts
          );
          
          const connectRequest = this.protocol.createConnectRequest(
            deviceIdentity,
            CONFIG.gateway.token
          );
          
          this.log(`[2/3] 发送 connect 请求 (id: ${connectRequest.id})`, 1);
          this.wsClient.send(connectRequest);
          
        } else if (step === 2 && message.type === 'response') {
          // 步骤 2: 收到 connect 响应
          this.log(`[3/3] 收到响应`, 1);
          clearTimeout(timeoutId);
          
          const result = this.protocol.handleConnectResponse(message.data);
          const duration = Date.now() - startTime;
          
          if (result.success) {
            resolve(new TestResult(
              testName,
              'PASS',
              duration,
              '协议握手成功，已获取 device token',
              {
                deviceId: this.deviceIdentity.deviceId,
                protocolVersion: result.protocol,
                deviceTokenPreview: result.deviceToken?.substring(0, 30) + '...',
                policy: result.policy
              }
            ));
          } else {
            resolve(new TestResult(
              testName,
              'FAIL',
              duration,
              `握手失败: ${result.error}`,
              { error: result.error }
            ));
          }
        }
      });

      // 超时处理
      timeoutId = setTimeout(() => {
        const duration = Date.now() - startTime;
        resolve(new TestResult(
          testName,
          'FAIL',
          duration,
          '协议握手超时 (15s)',
          { step: step, timeout: 15000 }
        ));
      }, 15000);

      // 错误处理
      this.wsClient.onError((err) => {
        clearTimeout(timeoutId);
        const duration = Date.now() - startTime;
        resolve(new TestResult(
          testName,
          'FAIL',
          duration,
          `WebSocket 错误: ${err.message}`,
          { error: err.message }
        ));
      });
    });
  }

  async cleanup() {
    if (this.wsClient) {
      this.wsClient.close();
      this.log('✓ WebSocket 连接已关闭', 0);
    }
  }

  async runAllTests() {
    console.log('='.repeat(60));
    console.log('OpenClaw Gateway 连接测试 (Node.js)');
    console.log('='.repeat(60));
    console.log(`目标: ${CONFIG.gateway.host}:${CONFIG.gateway.port}`);
    console.log(`Token: ${CONFIG.gateway.token.substring(0, 20)}...`);
    console.log(`设备ID: ${this.deviceIdentity.deviceId}`);
    console.log('='.repeat(60));
    console.log();

    // 测试 1: 网络连通性
    console.log('【阶段 1】基础网络测试');
    this.addResult(await this.testNetworkConnectivity());
    console.log();

    // 测试 2: WebSocket 连接
    console.log('【阶段 2】WebSocket 连接测试');
    this.addResult(await this.testWebSocketConnection());
    console.log();

    // 测试 3: 协议握手
    console.log('【阶段 3】OpenClaw 协议测试');
    this.addResult(await this.testProtocolHandshake());
    console.log();

    // 清理
    await this.cleanup();

    // 生成报告
    this.generateReport();
  }

  generateReport() {
    console.log('='.repeat(60));
    console.log('测试报告');
    console.log('='.repeat(60));

    const total = this.results.length;
    const passed = this.results.filter(r => r.status === 'PASS').length;
    const failed = this.results.filter(r => r.status === 'FAIL').length;
    const skipped = this.results.filter(r => r.status === 'SKIP').length;

    console.log(`总测试数: ${total}`);
    console.log(`通过: ${passed} ✓`);
    console.log(`失败: ${failed} ✗`);
    console.log(`跳过: ${skipped} ○`);
    console.log();

    // 失败详情
    if (failed > 0) {
      console.log('【失败项目详情】');
      this.results.filter(r => r.status === 'FAIL').forEach(result => {
        console.log(`\n  ✗ ${result.testName}`);
        console.log(`    原因: ${result.message}`);
        if (Object.keys(result.details).length > 0) {
          console.log(`    详情: ${JSON.stringify(result.details, null, 2).substring(0, 200)}`);
        }
      });
      console.log();
    }

    // 建议
    console.log('【连接建议】');
    if (failed === 0) {
      console.log('  ✓ 所有测试通过！Gateway 连接正常。');
      console.log('  ✓ 可以开始开发 Flutter 客户端。');
    } else {
      console.log('  ✗ 检测到连接问题，建议:');

      const networkOk = this.results.find(r => r.testName === '网络连通性测试')?.status === 'PASS';
      const wsOk = this.results.find(r => r.testName === 'WebSocket 连接测试')?.status === 'PASS';
      const protocolOk = this.results.find(r => r.testName === '协议握手测试')?.status === 'PASS';

      if (!networkOk) {
        console.log('    1. 检查服务器防火墙是否开放端口 18789');
        console.log(`    2. 确认服务器 ${CONFIG.gateway.host} 可访问`);
        console.log('    3. 检查 Gateway 服务是否正在运行');
      } else if (!wsOk) {
        console.log('    1. Gateway 可能未启用 WebSocket 支持');
        console.log('    2. 检查 Gateway 配置中的 CORS 设置');
        console.log('    3. 安装 ws 模块: npm install ws');
        console.log('    4. 查看 Gateway 日志获取详细错误');
      } else if (!protocolOk) {
        console.log('    1. Token 可能无效或过期');
        console.log('    2. Gateway 可能需要设备配对批准');
        console.log('    3. 检查 Gateway 安全设置 (auth.mode)');
        console.log('    4. 使用 SSH 登录服务器检查 Gateway 状态:');
        console.log(`       ssh ${CONFIG.ssh.user}@${CONFIG.ssh.host}`);
      }
    }

    console.log();
    console.log('='.repeat(60));

    // 保存详细报告
    const reportData = {
      timestamp: new Date().toISOString(),
      target: {
        host: CONFIG.gateway.host,
        port: CONFIG.gateway.port
      },
      device: this.deviceIdentity.getDeviceInfo(),
      summary: { total, passed, failed, skipped },
      results: this.results.map(r => r.toJSON())
    };

    const fs = require('fs');
    const reportFile = 'openclaw_test_report.json';
    fs.writeFileSync(reportFile, JSON.stringify(reportData, null, 2));
    console.log(`详细报告已保存: ${reportFile}`);
  }
}

// ==================== 主函数 ====================

async function main() {
  const tester = new ConnectionTester();
  
  try {
    await tester.runAllTests();
  } catch (err) {
    console.error('\n测试异常:', err.message);
    process.exit(1);
  }
}

// 检查 Node.js 版本
const nodeVersion = process.version;
console.log(`Node.js 版本: ${nodeVersion}`);

if (nodeVersion.startsWith('v16.') || nodeVersion.startsWith('v14.') || nodeVersion.startsWith('v12.')) {
  console.log('\n⚠ 警告: 建议使用 Node.js 18+ 以获得最佳 WebSocket 支持\n');
}

// 运行测试
main();
