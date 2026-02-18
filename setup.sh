#!/bin/bash
# MoltBot AI 助手 - 一键部署脚本
# 使用方法: bash setup.sh

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}"
echo "╔══════════════════════════════════════╗"
echo "║      🤖 MoltBot AI 助手部署         ║"
echo "║   基于 OpenClaw 的多渠道 AI 机器人   ║"
echo "╚══════════════════════════════════════╝"
echo -e "${NC}"

# ============================================
# Step 1: 安装 OpenClaw
# ============================================
echo -e "${YELLOW}[1/6] 安装 OpenClaw...${NC}"
if command -v openclaw &> /dev/null; then
    echo "OpenClaw 已安装，跳过"
else
    curl -fsSL https://molt.bot/install.sh | bash
fi

# ============================================
# Step 2: 配置 AI 模型
# ============================================
echo -e "${YELLOW}[2/6] 配置 AI 模型...${NC}"

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
    
    # AI 模型配置
    read -p "AI 模型 API 基础地址 (留空跳过): " API_BASE_URL
    read -p "AI 模型名称 (如 gemini-3-flash): " MODEL_NAME
    
    # 企业微信配置
    echo ""
    echo -e "${YELLOW}企业微信配置 (留空跳过):${NC}"
    read -p "  CorpID: " WECOM_CORP_ID
    read -p "  AgentID: " WECOM_AGENT_ID
    read -p "  CorpSecret: " WECOM_CORP_SECRET
    read -p "  Token: " WECOM_TOKEN
    read -p "  EncodingAESKey: " WECOM_ENCODING_AES_KEY
    
    # 飞书配置
    echo ""
    echo -e "${YELLOW}飞书配置 (留空跳过):${NC}"
    read -p "  App ID: " FEISHU_APP_ID
    read -p "  App Secret: " FEISHU_APP_SECRET
fi

# ============================================
# Step 3: 安装插件
# ============================================
echo -e "${YELLOW}[3/6] 安装渠道插件...${NC}"

# 企微自建应用插件
if [ -n "$WECOM_CORP_ID" ]; then
    echo "安装企微自建应用插件 (wecom-app)..."
    openclaw plugins install openclaw-plugin-wecom-app 2>/dev/null || echo "wecom-app 可能已安装"
fi

# 飞书插件
if [ -n "$FEISHU_APP_ID" ]; then
    echo "安装飞书插件..."
    openclaw plugins install feishu-openclaw 2>/dev/null || echo "feishu-openclaw 可能已安装"
fi

# 微信小程序插件
echo "安装微信小程序插件..."
openclaw plugins install openclawwechat 2>/dev/null || echo "openclawwechat 可能已安装"

# ============================================
# Step 4: 写入配置
# ============================================
echo -e "${YELLOW}[4/6] 写入配置...${NC}"

python3 << PYEOF
import json, os

config_path = os.path.expanduser('~/.openclaw/openclaw.json')
with open(config_path) as f:
    config = json.load(f)

# 配置企微
wecom_corp_id = os.environ.get('WECOM_CORP_ID', '$WECOM_CORP_ID')
if wecom_corp_id and wecom_corp_id != '':
    config.setdefault('channels', {})['wecom-app'] = {
        'enabled': True,
        'corpId': wecom_corp_id,
        'corpSecret': os.environ.get('WECOM_CORP_SECRET', '$WECOM_CORP_SECRET'),
        'agentId': int(os.environ.get('WECOM_AGENT_ID', '$WECOM_AGENT_ID') or 0),
        'token': os.environ.get('WECOM_TOKEN', '$WECOM_TOKEN'),
        'encodingAESKey': os.environ.get('WECOM_ENCODING_AES_KEY', '$WECOM_ENCODING_AES_KEY'),
        'dmPolicy': 'open',
    }

# 配置飞书
feishu_app_id = os.environ.get('FEISHU_APP_ID', '$FEISHU_APP_ID')
if feishu_app_id and feishu_app_id != '':
    config.setdefault('channels', {})['feishu'] = {
        'enabled': True,
        'appId': feishu_app_id,
        'appSecret': os.environ.get('FEISHU_APP_SECRET', '$FEISHU_APP_SECRET'),
    }

# 配置模型参数
config.setdefault('models', {}).setdefault('defaults', {})
config['models']['defaults']['contextWindow'] = 131072
config['models']['defaults']['maxTokens'] = 8192

with open(config_path, 'w') as f:
    json.dump(config, f, indent=2, ensure_ascii=False)

print('配置写入完成!')
PYEOF

# ============================================
# Step 5: 创建 SOUL.md 人设文件
# ============================================
echo -e "${YELLOW}[5/6] 创建 AI 人设...${NC}"

SOUL_SRC="$(dirname "$0")/SOUL.md"
SOUL_DST="$HOME/.openclaw/workspace/SOUL.md"

if [ -f "$SOUL_SRC" ]; then
    mkdir -p ~/.openclaw/workspace
    cp "$SOUL_SRC" "$SOUL_DST"
    echo "已复制 SOUL.md 到工作空间"
else
    echo "未找到 SOUL.md，跳过人设配置"
fi

# ============================================
# Step 6: 启动网关
# ============================================
echo -e "${YELLOW}[6/6] 启动 OpenClaw 网关...${NC}"
openclaw gateway --force

echo -e "${GREEN}"
echo "╔══════════════════════════════════════╗"
echo "║      ✅ MoltBot AI 部署完成！       ║"
echo "╚══════════════════════════════════════╝"
echo -e "${NC}"
