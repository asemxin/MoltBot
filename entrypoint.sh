#!/bin/bash
set -e

echo "🤖 MoltBot AI - Starting..."

# ============================================
# 从环境变量生成 OpenClaw 配置
# ============================================
FEISHU_APP_ID="${FEISHU_APP_ID:-}"
FEISHU_APP_SECRET="${FEISHU_APP_SECRET:-}"
API_BASE_URL="${API_BASE_URL:-https://asem12345-cliproxyapi.hf.space/v1}"
API_KEY="${API_KEY:-}"
MODEL_NAME="${MODEL_NAME:-gemini-3-flash}"

if [ -z "$FEISHU_APP_ID" ] || [ -z "$FEISHU_APP_SECRET" ]; then
    echo "❌ 错误: 请设置 FEISHU_APP_ID 和 FEISHU_APP_SECRET 环境变量"
    echo "   在 HF Space Settings → Secrets 中添加"
    exit 1
fi

echo "📝 生成 OpenClaw 配置..."

# 生成 provider ID（把 URL 转成合法 ID）
PROVIDER_ID=$(echo "$API_BASE_URL" | sed 's|https\?://||' | sed 's|[^a-zA-Z0-9]|-|g' | sed 's|-*$||')

cat > /root/.openclaw/openclaw.json << JSONEOF
{
  "gateway": {
    "port": 18789,
    "bind": "loopback",
    "mode": "local",
    "auth": {
      "mode": "token"
    }
  },
  "agents": {
    "defaults": {
      "memorySearch": {
        "enabled": false
      }
    }
  },
  "models": {
    "mode": "merge",
    "providers": {
      "${PROVIDER_ID}": {
        "baseUrl": "${API_BASE_URL}",
        "apiKey": "${API_KEY}",
        "api": "openai-completions",
        "models": [
          {
            "id": "${MODEL_NAME}",
            "name": "${MODEL_NAME}",
            "reasoning": false,
            "input": ["text"],
            "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 },
            "contextWindow": 1000000,
            "maxTokens": 32000
          }
        ]
      }
    }
  },
  "channels": {
    "feishu": {
      "enabled": true,
      "appId": "${FEISHU_APP_ID}",
      "appSecret": "${FEISHU_APP_SECRET}"
    }
  },
  "plugins": {
    "entries": {
      "feishu-openclaw": {
        "enabled": true
      }
    }
  }
}
JSONEOF

# 创建必要目录
mkdir -p /root/.openclaw/agents/main/sessions
chmod 700 /root/.openclaw

echo "✅ 配置已生成"
echo "   模型: ${PROVIDER_ID}/${MODEL_NAME}"
echo "   飞书 App ID: ${FEISHU_APP_ID}"

# ============================================
# 启动 OpenClaw Gateway（后台）
# ============================================
echo "🔧 运行 doctor --fix..."
openclaw doctor --fix || true

echo "🚀 启动 OpenClaw Gateway..."
openclaw gateway --force &
GATEWAY_PID=$!
echo "   Gateway PID: $GATEWAY_PID"

# 等待网关启动
sleep 5

# ============================================
# 启动状态监控网页（前台，端口 7860）
# ============================================
echo "📊 启动状态监控网页 (端口 7860)..."
exec python3 /app/status_page.py

