# 🤖 MoltBot AI

基于 [OpenClaw](https://openclaw.ai) 的飞书 AI 助手，通过 Docker 部署到 Hugging Face Spaces。

## ✨ 功能

- 🔗 **飞书集成** — WebSocket 长连接，无需公网 IP
- 🧠 **自定义 AI 人设** — 通过 [SOUL.md](SOUL.md) 定义
- 📊 **状态监控** — 内置 Web 监控页面
- 🐳 **Docker 部署** — 一键部署到 HF Spaces

## 🚀 快速部署

### 方式一：Hugging Face Spaces（推荐）

1. Fork 本仓库
2. 新建 HF Space（选 Docker 类型）
3. 关联 GitHub 仓库
4. 在 Settings → Secrets 中添加：

| Secret | 说明 |
|---|---|
| `FEISHU_APP_ID` | 飞书 App ID |
| `FEISHU_APP_SECRET` | 飞书 App Secret |
| `API_BASE_URL` | AI 模型 API 地址 |
| `API_KEY` | API 密钥 |
| `MODEL_NAME` | 模型名称（如 `gemini-3-flash`） |

5. 部署完成后访问 Space URL 查看状态监控

### 方式二：GitHub Codespaces

1. 点击 Code → Codespaces → 新建
2. 在终端运行：

```bash
bash setup.sh
```

3. 按提示配置飞书凭证和 AI 模型

### 方式三：本地 Docker

```bash
docker build -t moltbot .
docker run -p 7860:7860 \
  -e FEISHU_APP_ID=your_app_id \
  -e FEISHU_APP_SECRET=your_app_secret \
  -e API_BASE_URL=https://your-api.hf.space/v1 \
  -e API_KEY=your_key \
  -e MODEL_NAME=gemini-3-flash \
  moltbot
```

## 📁 文件说明

| 文件 | 说明 |
|---|---|
| `Dockerfile` | Docker 镜像定义 |
| `entrypoint.sh` | 容器启动脚本 |
| `status_page.py` | 状态监控网页 |
| `SOUL.md` | AI 人设定义 |
| `setup.sh` | Codespaces 一键部署脚本 |
| `config.env.example` | 配置模板 |

## 🔧 飞书配置

1. 打开 [飞书开放平台](https://open.feishu.cn)
2. 创建企业自建应用
3. 添加「机器人」能力
4. 事件订阅 → 使用长连接
5. 添加事件 `im.message.receive_v1`
6. 权限：`im:message`、`im:message.group_at_msg`、`im:message.p2p_msg`、`im:message:send_as_bot`
7. 发布应用

## 📄 License

MIT
