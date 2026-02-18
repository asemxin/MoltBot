# 🤖 MoltBot AI

基于 [OpenClaw](https://github.com/openclaw/openclaw) 的多渠道个人 AI 助手，支持企业微信、飞书和微信小程序。通过 GitHub Codespaces 一键部署。

## ✨ 功能

| 渠道 | 私聊 | 群聊 | 说明 |
|------|------|------|------|
| 企业微信 (WeCom) | ✅ | ⚠️ 需要智能机器人权限 | 自建应用，支持主动推送 |
| 飞书 (Feishu) | ✅ | ✅ | WebSocket 长连接，无需公网 IP |
| 微信 (ClawChat) | ✅ | - | 通过小程序扫码配对 |

- 🧠 自定义 AI 人设（`SOUL.md`）
- 🔧 可扩展的 Skills 系统
- 💾 持久对话记忆
- 🌊 流式输出 (飞书)

## 🚀 快速部署

### 1. 创建 Codespace

点击仓库的 `Code` → `Codespaces` → `Create codespace on main`

### 2. 一键安装

```bash
# 安装 OpenClaw
curl -fsSL https://molt.bot/install.sh | bash

# 运行部署脚本
bash setup.sh
```

### 3. 手动配置（可选）

```bash
# 复制配置模板
cp config.env.example config.env

# 编辑配置（填入你的 API 密钥）
nano config.env

# 运行部署
bash setup.sh
```

## ⚙️ 配置说明

### 企业微信

1. [企微管理后台](https://work.weixin.qq.com/) → 应用管理 → 创建自建应用
2. 获取 CorpID、AgentID、Secret
3. 设置 API 接收消息：
   - URL: `https://<your-codespace-url>/wecom-app`
   - Token 和 EncodingAESKey 自定义
4. 添加企业可信 IP（`curl -s ifconfig.me` 获取 Codespace 出站 IP）

### 飞书

1. [飞书开放平台](https://open.feishu.cn/) → 创建应用 → 添加机器人能力
2. 获取 App ID 和 App Secret
3. 事件与回调 → 选择「长连接」模式
4. 添加事件 `im.message.receive_v1`
5. 开通权限 `im:message`、`im:message.group_at_msg`
6. 创建版本并发布

### 微信小程序

```bash
openclaw plugins install openclawwechat
cd ~/.openclaw/extensions/openclawwechat && npm run config-init
```

微信搜索「ClawChat」小程序扫码配对。

## 🎭 自定义人设

编辑 `SOUL.md` 文件定义 AI 的性格和说话风格，然后复制到工作空间：

```bash
cp SOUL.md ~/.openclaw/workspace/SOUL.md
openclaw gateway --force
```

## 📁 项目结构

```
MoltBot/
├── setup.sh              # 一键部署脚本
├── config.env.example    # 配置模板（不含敏感信息）
├── SOUL.md               # AI 人设定义
├── README.md             # 本文件
├── LICENSE               # MIT License
└── .gitignore            # Git 忽略规则
```

## ⚠️ 注意事项

- Codespace 重启后 **IP 会变**，需要更新企微的可信 IP
- `config.env` 包含敏感信息，**不要提交到 Git**
- 飞书使用 WebSocket 长连接，无需公网 IP 配置
- 企微群聊需要「智能机器人」类型应用权限

## 📄 License

MIT
