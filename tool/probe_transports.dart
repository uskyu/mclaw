import 'dart:io';

import 'package:clawapp/services/gateway_protocol_service.dart';
import 'package:clawapp/services/ssh_tunnel_service.dart';

Future<void> main() async {
  final host = _mustEnv('OPENCLAW_HOST');
  final token = _mustEnv('OPENCLAW_TOKEN');
  final port =
      int.tryParse(Platform.environment['OPENCLAW_PORT'] ?? '') ?? 18789;
  final sshUser = Platform.environment['OPENCLAW_SSH_USER'] ?? 'root';
  final sshPass = Platform.environment['OPENCLAW_SSH_PASSWORD'] ?? '';
  final sshPort =
      int.tryParse(Platform.environment['OPENCLAW_SSH_PORT'] ?? '') ?? 22;

  print('=== Transport Probe ===');
  print('Target host: $host:$port');
  print('');

  final direct = await _probeDirect(host: host, port: port, token: token);

  final ssh = await _probeViaSsh(
    host: host,
    remotePort: port,
    token: token,
    sshUser: sshUser,
    sshPass: sshPass,
    sshPort: sshPort,
  );

  print('');
  print('=== Result Summary ===');
  print('Direct WS: ${direct ? 'PASS' : 'FAIL'}');
  print('SSH Tunnel: ${ssh ? 'PASS' : 'FAIL'}');
}

Future<bool> _probeDirect({
  required String host,
  required int port,
  required String token,
}) async {
  final protocol = GatewayProtocolService();
  final wsUrl = 'ws://$host:$port';
  print('[Direct] connect $wsUrl');
  try {
    await protocol.connect(wsUrl);
    final ok = await protocol.handshake(
      clientId: 'clawchat-transport-probe',
      clientVersion: '1.0.0',
      platform: 'android',
      mode: 'ui',
      token: token,
      locale: 'zh-CN',
    );
    print('[Direct] handshake: ${ok ? 'OK' : 'FAIL'}');
    if (!ok) {
      print('[Direct] error: ${protocol.lastError ?? 'unknown'}');
    }
    await protocol.disconnect();
    return ok;
  } catch (e) {
    print('[Direct] exception: $e');
    await protocol.disconnect();
    return false;
  }
}

Future<bool> _probeViaSsh({
  required String host,
  required int remotePort,
  required String token,
  required String sshUser,
  required String sshPass,
  required int sshPort,
}) async {
  final tunnel = SshTunnelService();
  final protocol = GatewayProtocolService();
  print('[SSH] connect $sshUser@$host:$sshPort, remote 127.0.0.1:$remotePort');
  try {
    await tunnel.connect(
      host: host,
      port: sshPort,
      username: sshUser,
      password: sshPass,
      localPort: 18789,
      remoteHost: '127.0.0.1',
      remotePort: remotePort,
    );

    final localPort = tunnel.localPort ?? 18789;
    final wsUrl = 'ws://127.0.0.1:$localPort';
    print('[SSH] local forward ready: $wsUrl');
    await protocol.connect(wsUrl);
    final ok = await protocol.handshake(
      clientId: 'clawchat-transport-probe',
      clientVersion: '1.0.0',
      platform: 'android',
      mode: 'ui',
      token: token,
      locale: 'zh-CN',
    );
    print('[SSH] handshake: ${ok ? 'OK' : 'FAIL'}');
    if (!ok) {
      print('[SSH] error: ${protocol.lastError ?? 'unknown'}');
    }
    await protocol.disconnect();
    await tunnel.disconnect();
    return ok;
  } catch (e) {
    print('[SSH] exception: $e');
    await protocol.disconnect();
    await tunnel.disconnect();
    return false;
  }
}

String _mustEnv(String key) {
  final value = Platform.environment[key];
  if (value == null || value.trim().isEmpty) {
    stderr.writeln('Missing env var: $key');
    exit(2);
  }
  return value.trim();
}
