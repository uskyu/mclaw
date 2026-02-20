#!/usr/bin/env bash
set -euo pipefail

DOMAIN=""
PORT="18789"
CONFIG_PATH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --domain)
      DOMAIN="${2:-}"
      shift 2
      ;;
    --port)
      PORT="${2:-18789}"
      shift 2
      ;;
    --config)
      CONFIG_PATH="${2:-}"
      shift 2
      ;;
    *)
      echo "Unknown arg: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$CONFIG_PATH" ]]; then
  if [[ -f "/root/.openclaw/openclaw.json" ]]; then
    CONFIG_PATH="/root/.openclaw/openclaw.json"
  else
    CONFIG_PATH="$HOME/.openclaw/openclaw.json"
  fi
fi

mkdir -p "$(dirname "$CONFIG_PATH")"
if [[ ! -f "$CONFIG_PATH" ]]; then
  printf '{}' > "$CONFIG_PATH"
fi

BACKUP_PATH="${CONFIG_PATH}.backup.$(date +%s)"
cp "$CONFIG_PATH" "$BACKUP_PATH" 2>/dev/null || true

python3 - "$CONFIG_PATH" "$PORT" <<'PY'
import json
import secrets
import sys

config_path = sys.argv[1]
port = int(sys.argv[2])

try:
    with open(config_path, "r", encoding="utf-8") as f:
        raw = f.read().strip()
        cfg = json.loads(raw) if raw else {}
except Exception:
    cfg = {}

gateway = cfg.get("gateway") if isinstance(cfg.get("gateway"), dict) else {}
auth = gateway.get("auth") if isinstance(gateway.get("auth"), dict) else {}
control = gateway.get("controlUi") if isinstance(gateway.get("controlUi"), dict) else {}

token = auth.get("token") if isinstance(auth.get("token"), str) and auth.get("token") else secrets.token_hex(24)

auth["mode"] = "token"
auth["token"] = token
gateway["auth"] = auth
gateway["bind"] = "loopback"
gateway["port"] = port

control["allowedOrigins"] = ["*"]
control["allowInsecureAuth"] = True
gateway["controlUi"] = control

cfg["gateway"] = gateway

with open(config_path, "w", encoding="utf-8") as f:
    json.dump(cfg, f)

print(token)
PY

TOKEN="$(python3 - "$CONFIG_PATH" "$PORT" <<'PY'
import json, sys
cfg = json.load(open(sys.argv[1], 'r', encoding='utf-8'))
print(cfg.get('gateway', {}).get('auth', {}).get('token', ''))
PY
)"

if command -v systemctl >/dev/null 2>&1; then
  systemctl restart openclaw || true
else
  pkill -f "openclaw gateway" || true
  nohup openclaw gateway >/dev/null 2>&1 &
fi

MODE="direct-ws"
URL="ws://$(hostname -I | awk '{print $1}'):${PORT}"

if [[ -n "$DOMAIN" ]]; then
  MODE="wss"
  if ! command -v caddy >/dev/null 2>&1; then
    if command -v apt-get >/dev/null 2>&1; then
      apt-get update -y >/dev/null 2>&1 || true
      apt-get install -y caddy >/dev/null 2>&1 || true
    elif command -v dnf >/dev/null 2>&1; then
      dnf install -y caddy >/dev/null 2>&1 || true
    elif command -v yum >/dev/null 2>&1; then
      yum install -y caddy >/dev/null 2>&1 || true
    fi
  fi

  if command -v caddy >/dev/null 2>&1; then
    cat >/etc/caddy/Caddyfile <<EOF
$DOMAIN {
  reverse_proxy 127.0.0.1:$PORT
}
EOF
    systemctl enable caddy >/dev/null 2>&1 || true
    systemctl restart caddy >/dev/null 2>&1 || true
    URL="wss://$DOMAIN"
  else
    MODE="direct-ws"
  fi
fi

cat <<EOF
{
  "success": true,
  "mode": "$MODE",
  "gatewayUrl": "$URL",
  "gatewayToken": "$TOKEN",
  "configPath": "$CONFIG_PATH",
  "backupPath": "$BACKUP_PATH"
}
EOF
