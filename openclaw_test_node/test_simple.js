/**
 * OpenClaw Gateway Connection Test - Simple Version
 * =================================================
 * 简化的连接测试，尝试不同的认证方式
 */

const crypto = require('crypto');
const WebSocket = require('ws');

const CONFIG = {
  gateway: {
    host: 'localhost',
    port: 18789,
    token: '30bfd2b063ab78d7054bdc575678f14591209c7a9789767c'
  }
};

async function testSimple() {
  console.log('='.repeat(70));
  console.log('OpenClaw Gateway 简化连接测试');
  console.log('='.repeat(70));
  console.log(`目标: ${CONFIG.gateway.host}:${CONFIG.gateway.port}`);
  console.log('='.repeat(70));
  console.log();

  const wsUrl = `ws://${CONFIG.gateway.host}:${CONFIG.gateway.port}`;
  
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(wsUrl);
    let step = 0;
    
    ws.on('open', () => {
      console.log('✓ WebSocket 连接成功');
    });
    
    ws.on('message', (data) => {
      const msg = JSON.parse(data.toString());
      console.log(`  [步骤 ${step + 1}] 收到:`, msg.type, msg.event || '');
      
      if (msg.type === 'event' && msg.event === 'connect.challenge') {
        step = 1;
        
        // 尝试简单的 connect（不带完整 device identity）
        const connectReq = {
          type: 'req',
          id: `req_${crypto.randomBytes(6).toString('hex')}`,
          method: 'connect',
          params: {
            minProtocol: 3,
            maxProtocol: 3,
            client: {
              id: 'cli',
              version: '1.0.0',
              platform: 'windows',
              mode: 'cli'
            },
            role: 'operator',
            scopes: ['operator.read', 'operator.write'],
            auth: { token: CONFIG.gateway.token },
            locale: 'zh-CN',
            userAgent: 'openclaw-test/1.0.0'
            // 注意：这里不发送 device identity，看看会怎样
          }
        };
        
        console.log('  发送 connect 请求（无 device identity）...');
        ws.send(JSON.stringify(connectReq));
        
      } else if (msg.type === 'res') {
        step = 2;
        console.log();
        console.log('='.repeat(70));
        
        if (msg.ok) {
          console.log('✓ 连接成功！');
          console.log('  响应:', JSON.stringify(msg.payload, null, 2));
        } else {
          console.log('✗ 连接失败');
          console.log('  错误:', msg.error);
          
          // 如果失败是因为缺少 device，尝试带 device 的方式
          if (msg.error?.message?.includes('device') || msg.error?.code === 'DEVICE_REQUIRED') {
            console.log();
            console.log('  尝试带 device identity 重新连接...');
            // 这里可以继续尝试其他方式
          }
        }
        
        console.log('='.repeat(70));
        ws.close();
        resolve(msg.ok);
      }
    });
    
    ws.on('error', (err) => {
      console.log('✗ WebSocket 错误:', err.message);
      reject(err);
    });
    
    setTimeout(() => {
      ws.terminate();
      reject(new Error('连接超时'));
    }, 15000);
  });
}

testSimple()
  .then(success => {
    console.log();
    console.log(success ? '✓ 测试通过' : '✗ 测试失败');
    process.exit(success ? 0 : 1);
  })
  .catch(err => {
    console.error('测试异常:', err);
    process.exit(1);
  });
