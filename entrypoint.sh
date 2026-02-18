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

# 生成 provider ID：从 URL 提取域名部分，加 custom- 前缀
# 例如 https://asem12345-cliproxyapi.hf.space/v1 → custom-asem12345-cliproxyapi-hf-space
PROVIDER_ID="custom-$(echo "$API_BASE_URL" | sed 's|https\?://||' | sed 's|/.*||' | sed 's|[^a-zA-Z0-9]|-|g' | sed 's|-*$||')"

OPENCLAW_DIR="$HOME/.openclaw"

# 创建必要目录
mkdir -p "$OPENCLAW_DIR/agents/main/sessions"
mkdir -p "$OPENCLAW_DIR/workspace"
chmod 700 "$OPENCLAW_DIR" 2>/dev/null || true

# 先写一个最小配置让 doctor 能跑
cat > "$OPENCLAW_DIR/openclaw.json" << JSONEOF
{
  "gateway": {
    "port": 18789,
    "bind": "loopback",
    "mode": "local"
  },
  "channels": {
    "feishu": {
      "enabled": true,
      "appId": "${FEISHU_APP_ID}",
      "appSecret": "${FEISHU_APP_SECRET}"
    }
  }
}
JSONEOF

echo "✅ 最小配置已生成"
echo "   飞书 App ID: ${FEISHU_APP_ID}"

# ============================================
# 运行 doctor --fix（自动安装飞书插件等）
# ============================================
echo "🔧 运行 doctor --fix..."
openclaw doctor --fix || true

# ============================================
# doctor 完成后，写入完整配置（包含自定义模型）
# doctor 有时会覆盖我们的配置，所以放在 doctor 之后
# ============================================
echo "📝 写入完整配置..."

# 用 python 合并配置（保留 doctor 添加的字段如 meta, wizard, plugins 等）
python3 << PYEOF
import json, os

config_path = os.path.expanduser("~/.openclaw/openclaw.json")

# 读取 doctor 生成的配置
try:
    with open(config_path) as f:
        config = json.load(f)
except:
    config = {}

# 设置 gateway
config.setdefault("gateway", {})
config["gateway"]["port"] = 18789
config["gateway"]["bind"] = "loopback"
config["gateway"]["mode"] = "local"

# 设置自定义 provider
config.setdefault("models", {})
config["models"]["mode"] = "merge"
config["models"].setdefault("providers", {})
config["models"]["providers"]["${PROVIDER_ID}"] = {
    "baseUrl": "${API_BASE_URL}",
    "apiKey": "${API_KEY}",
    "api": "openai-completions",
    "models": [
        {
            "id": "${MODEL_NAME}",
            "name": "${MODEL_NAME} (Custom Provider)",
            "reasoning": False,
            "input": ["text"],
            "cost": {"input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0},
            "contextWindow": 131072,
            "maxTokens": 8192
        }
    ]
}

# 设置 agent defaults
config.setdefault("agents", {}).setdefault("defaults", {})
config["agents"]["defaults"]["model"] = {
    "primary": "${PROVIDER_ID}/${MODEL_NAME}"
}
config["agents"]["defaults"].setdefault("models", {})
config["agents"]["defaults"]["models"]["${PROVIDER_ID}/${MODEL_NAME}"] = {}
config["agents"]["defaults"].setdefault("workspace", os.path.expanduser("~/.openclaw/workspace"))
config["agents"]["defaults"].setdefault("compaction", {"mode": "safeguard"})
config["agents"]["defaults"].setdefault("maxConcurrent", 4)

# 设置飞书 channel
config.setdefault("channels", {})
config["channels"]["feishu"] = {
    "enabled": True,
    "appId": "${FEISHU_APP_ID}",
    "appSecret": "${FEISHU_APP_SECRET}"
}

with open(config_path, "w") as f:
    json.dump(config, f, indent=2)

print(f"✅ 完整配置已写入 {config_path}")
print(f"   模型: ${PROVIDER_ID}/${MODEL_NAME}")

# 同时写入 agent 级别的 models.json（防止 fallback 到 anthropic）
agent_dir = os.path.expanduser("~/.openclaw/agents/main/agent")
os.makedirs(agent_dir, exist_ok=True)

agent_models = {
    "providers": {
        "github-copilot": {
            "baseUrl": "https://api.individual.githubcopilot.com",
            "models": []
        },
        "${PROVIDER_ID}": {
            "baseUrl": "${API_BASE_URL}",
            "apiKey": "${API_KEY}",
            "api": "openai-completions",
            "models": [
                {
                    "id": "${MODEL_NAME}",
                    "name": "${MODEL_NAME} (Custom Provider)",
                    "reasoning": False,
                    "input": ["text"],
                    "cost": {"input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0},
                    "contextWindow": 131072,
                    "maxTokens": 8192
                }
            ]
        }
    }
}

models_path = os.path.join(agent_dir, "models.json")
with open(models_path, "w") as f:
    json.dump(agent_models, f, indent=2)

# 确保 auth.json 存在
auth_path = os.path.join(agent_dir, "auth.json")
if not os.path.exists(auth_path):
    with open(auth_path, "w") as f:
        json.dump({}, f)

print(f"✅ Agent 配置已写入 {agent_dir}")
PYEOF

# ============================================
# 启动 OpenClaw Gateway（后台）
# ============================================
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

