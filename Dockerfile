FROM node:24-slim

# 系统依赖
RUN apt-get update && apt-get install -y \
    python3 python3-pip curl git procps lsof \
    && rm -rf /var/lib/apt/lists/*

# Python 依赖
RUN pip3 install flask psutil --break-system-packages

# 安装 OpenClaw
RUN npm install -g openclaw@latest

# 创建目录
RUN mkdir -p /root/.openclaw/workspace /root/.openclaw/extensions /root/.openclaw/credentials

# 安装飞书插件
RUN openclaw plugins install feishu-openclaw 2>/dev/null || true
RUN cd /root/.openclaw/extensions/feishu-openclaw && npm install @sinclair/typebox 2>/dev/null || true

# 复制文件
COPY SOUL.md /root/.openclaw/workspace/SOUL.md
COPY status_page.py /app/status_page.py
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

EXPOSE 7860

CMD ["/app/entrypoint.sh"]
