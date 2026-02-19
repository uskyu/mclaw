/**
 * OpenClaw Gateway Connection Test with SSH Tunnel
 * ================================================
 * 使用 SSH 隧道连接远程 OpenClaw Gateway
 * 
 * 官方文档: https://docs.openclaw.ai/gateway/remote
 * 
 * 使用方法:
 *   1. 先在本地建立 SSH 隧道:
 *      ssh -N -L 18789:127.0.0.1:18789 root@38.55.181.247
 *   
 *   2. 运行测试:
 *      node test_with_tunnel.js
 * 
 * 为什么需要 SSH 隧道?
 *   - OpenClaw Gateway 默认绑定 127.0.0.1（loopback）
 *   - 这是安全设计，防止未授权远程访问
 *   - SSH 隧道将远程端口安全转发到本地
 */

const crypto = require('crypto');
const WebSocket = require('ws');

// ==================== 配置信息 ====================
const CONFIG = {
  // SSH 隧道配置
  ssh: {
    host: '38.55.181.247',
    user: 'root',
    password: 'bustUPPF6115'
  },
  
  // Gateway 配置（通过隧道后连接本地端口）
  gateway: {
    host: 'localhost',  // SSH 隧道转发到本地
    port: 18789,
    token: '30bfd2b063ab78d7054bdc575678f14591209c7a9789767c'
  },
  
  // 客户端信息 (根据 OpenClaw 协议要求)
  client: {
    id: 'cli',           // 官方 CLI 使用 'cli'
    version: '1.0.0',
    platform: 'windows',
    mode: 'operator'     // operator 模式
  }
};

// ==================== 设备身份 ====================
class DeviceIdentity {
  constructor() {
    this.deviceId = `device_${crypto.randomBytes(8).toString('hex')}`;
    this.keyPair = crypto.generateKeyPairSync('ec', {
      namedCurve: 'P-256',
      publicKeyEncoding: { type: 'spki', format: 'pem' },
      privateKeyEncoding: { type: 'pkcs8', format: 'pem' }
    });
  }

  signChallenge(nonce, timestamp) {
    // 使用正确的签名数据格式
    const dataToSign = `${nonce}:${timestamp}:${this.deviceId}`;
    const signer = crypto.createSign('SHA256');
    signer.update(dataToSign);
    const signature = signer.sign(this.keyPair.privateKey, 'base64');
    
    // 提取原始公钥（去除 PEM 头尾和换行）
    const publicKeyBase64 = this.keyPair.publicKey
      .replace('-----BEGIN PUBLIC KEY-----', '')
      .replace('-----END PUBLIC KEY-----', '')
      .replace(/\n/g, '');

    return {
      id: this.deviceId,
      publicKey: publicKeyBase64,
      signature: signature,
      signedAt: timestamp,  // 使用服务器提供的时间戳
      nonce: nonce
    };
  }
}

// ==================== 测试执行 ====================
async function testConnection() {
  console.log('='.repeat(70));
  console.log('OpenClaw Gateway 连接测试 (SSH 隧道模式)');
  console.log('='.repeat(70));
  console.log(`目标服务器: ${CONFIG.ssh.host}`);
  console.log(`本地转发:   ${CONFIG.gateway.host}:${CONFIG.gateway.port}`);
  console.log(`设备ID:     ${new DeviceIdentity().deviceId}`);
  console.log('='.repeat(70));
  console.log();

  // 检查 SSH 隧道是否已建立
  const net = require('net');
  console.log('【步骤 1】检查 SSH 隧道...');
  
  try {
    await new Promise((resolve, reject) => {
      const socket = new net.Socket();
      socket.setTimeout(3000);
      socket.on('connect', () => {
        socket.destroy();
        resolve();
      });
      socket.on('error', reject);
      socket.on('timeout', () => {
        socket.destroy();
        reject(new Error('连接超时'));
      });
      socket.connect(CONFIG.gateway.port, CONFIG.gateway.host);
    });
    console.log('✓ 隧道连接正常');
  } catch (err) {
    console.log('✗ 隧道未建立！');
    console.log();
    console.log('请先运行以下命令建立 SSH 隧道:');
    console.log();
    console.log('  ssh -N -L 18789:127.0.0.1:18789 root@38.55.181.247');
    console.log();
    console.log('或者使用密码:');
    console.log();
    console.log('  ssh -N -L 18789:127.0.0.1:18789 root@38.55.181.247');
    console.log('  密码: bustUPPF6115');
    console.log();
    console.log('然后在另一个终端窗口运行此测试脚本。');
    process.exit(1);
  }

  // WebSocket 连接测试
  console.log();
  console.log('【步骤 2】WebSocket 连接测试...');
  
  const wsUrl = `ws://${CONFIG.gateway.host}:${CONFIG.gateway.port}`;
  const device = new DeviceIdentity();
  
  try {
    const ws = new WebSocket(wsUrl);
    
    let connected = false;
    let challengeReceived = false;
    let connectResponse = null;
    
    ws.on('open', () => {
      console.log('✓ WebSocket 连接成功');
      connected = true;
    });
    
    ws.on('message', (data) => {
      const msg = JSON.parse(data.toString());
      console.log('  收到消息:', msg.type, msg.event || msg.method || '');
      
      if (msg.type === 'event' && msg.event === 'connect.challenge') {
        challengeReceived = true;
        console.log('  收到 challenge，正在签名...');
        
        // 签名并发送 connect 请求
        const deviceIdentity = device.signChallenge(
          msg.payload.nonce,
          msg.payload.ts
        );
        
        const connectReq = {
          type: 'req',
          id: `req_${crypto.randomBytes(6).toString('hex')}`,
          method: 'connect',
          params: {
            minProtocol: 3,
            maxProtocol: 3,
            client: {
              id: 'cli',           // 正确的 client ID
              version: '1.0.0',
              platform: 'windows',
              mode: 'cli'          // 正确的 mode: "cli" 而不是 "operator"
            },
            role: 'operator',
            scopes: ['operator.read', 'operator.write'],
            caps: [],
            commands: [],
            permissions: {},
            auth: { token: CONFIG.gateway.token },
            locale: 'zh-CN',
            userAgent: 'openclaw-cli/1.0.0',
            device: deviceIdentity
          }
        };
        
        ws.send(JSON.stringify(connectReq));
        console.log('  已发送 connect 请求');
        
      } else if (msg.type === 'res' && msg.id) {
        connectResponse = msg;
        console.log();
        console.log('='.repeat(70));
        
        if (msg.ok && msg.payload?.type === 'hello-ok') {
          console.log('✓ 协议握手成功！');
          console.log(`  协议版本: ${msg.payload.protocol}`);
          console.log(`  Device Token: ${msg.payload.auth?.deviceToken?.substring(0, 30)}...`);
          console.log();
          console.log('Gateway 连接正常，可以开始开发 Flutter 客户端。');
        } else {
          console.log('✗ 握手失败');
          console.log('  错误:', msg.error || '未知错误');
        }
        
        console.log('='.repeat(70));
        ws.close();
        process.exit(msg.ok ? 0 : 1);
      }
    });
    
    ws.on('error', (err) => {
      console.log('✗ WebSocket 错误:', err.message);
      process.exit(1);
    });
    
    // 超时处理
    setTimeout(() => {
      if (!connectResponse) {
        console.log();
        console.log('✗ 连接超时 (15s)');
        if (!challengeReceived) {
          console.log('  未收到 challenge，可能:');
          console.log('  1. Token 无效');
          console.log('  2. 需要设备配对批准');
        }
        ws.terminate();
        process.exit(1);
      }
    }, 15000);
    
  } catch (err) {
    console.log('✗ 连接失败:', err.message);
    process.exit(1);
  }
}

// 主函数
testConnection().catch(err => {
  console.error('测试异常:', err);
  process.exit(1);
});
