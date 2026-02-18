#!/bin/bash
# MoltBot AI 助手 - 一键部署脚本（仅飞书）
# 使用方法: bash setup.sh

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}"
echo "╔══════════════════════════════════════╗"
echo "║      🤖 MoltBot AI 助手部署         ║"
echo "║   基于 OpenClaw 的飞书 AI 机器人     ║"
echo "╚══════════════════════════════════════╝"
echo -e "${NC}"

# ============================================
# Step 1: 安装 OpenClaw
# ============================================
echo -e "${YELLOW}[1/5] 安装 OpenClaw...${NC}"
if command -v openclaw &> /dev/null; then
    echo "OpenClaw 已安装，跳过"
else
    curl -fsSL https://molt.bot/install.sh | bash
fi

# ============================================
# Step 2: 配置 AI 模型
# ============================================
echo -e "${YELLOW}[2/5] 配置 AI 模型...${NC}"

if [ ! -f ~/.openclaw/openclaw.json ]; then
    echo -e "${RED}请先运行 openclaw 初始化向导${NC}"
    openclaw
    exit 1
fi

# 读取用户配置
CONFIG_FILE="$(dirname "$0")/config.env"
if [ -f "$CONFIG_FILE" ]; then
    echo "加载 config.env 配置..."
    source "$CONFIG_FILE"
else
    echo -e "${YELLOW}未找到 config.env，将使用交互模式...${NC}"
    echo ""
    read -p "AI 模型 API 基础地址 (留空跳过): " API_BASE_URL
    read -p "AI 模型 API Key: " API_KEY
    read -p "AI 模型名称 (如 gemini-3-flash): " MODEL_NAME
    echo ""
    echo -e "${YELLOW}飞书配置:${NC}"
    read -p "  App ID: " FEISHU_APP_ID
    read -p "  App Secret: " FEISHU_APP_SECRET
fi

# ============================================
# Step 3: 安装飞书插件
# ============================================
echo -e "${YELLOW}[3/5] 安装飞书插件...${NC}"

if [ -n "$FEISHU_APP_ID" ]; then
    echo "安装飞书插件..."
    openclaw plugins install feishu-openclaw 2>/dev/null || echo "feishu-openclaw 可能已安装"
    cd ~/.openclaw/extensions/feishu-openclaw && npm install @sinclair/typebox 2>/dev/null || true
    cd ~
else
    echo -e "${RED}未配置飞书 App ID，跳过${NC}"
fi

# ============================================
# Step 4: 写入配置
# ============================================
echo -e "${YELLOW}[4/5] 写入配置...${NC}"

python3 << PYEOF
import json, os

config_path = os.path.expanduser('~/.openclaw/openclaw.json')
with open(config_path) as f:
    config = json.load(f)

feishu_app_id = os.environ.get('FEISHU_APP_ID', '$FEISHU_APP_ID')
if feishu_app_id and feishu_app_id != '':
    config.setdefault('channels', {})['feishu'] = {
        'enabled': True,
        'appId': feishu_app_id,
        'appSecret': os.environ.get('FEISHU_APP_SECRET', '$FEISHU_APP_SECRET'),
    }

# 修正 context window
for pid, prov in config.get('models', {}).get('providers', {}).items():
    for m in prov.get('models', []):
        m['contextWindow'] = 1000000
        m['maxTokens'] = 32000

with open(config_path, 'w') as f:
    json.dump(config, f, indent=2, ensure_ascii=False)

print('配置写入完成!')
PYEOF

# ============================================
# Step 5: 创建 SOUL.md 人设文件 & 启动
# ============================================
echo -e "${YELLOW}[5/5] 创建 AI 人设 & 启动...${NC}"

SOUL_SRC="$(dirname "$0")/SOUL.md"
SOUL_DST="$HOME/.openclaw/workspace/SOUL.md"

if [ -f "$SOUL_SRC" ]; then
    mkdir -p ~/.openclaw/workspace
    cp "$SOUL_SRC" "$SOUL_DST"
    echo "已复制 SOUL.md 到工作空间"
fi

echo -e "${GREEN}"
echo "╔══════════════════════════════════════╗"
echo "║      ✅ MoltBot AI 配置完成！       ║"
echo "╚══════════════════════════════════════╝"
echo -e "${NC}"
echo "运行以下命令启动网关："
echo "  openclaw gateway --force"
