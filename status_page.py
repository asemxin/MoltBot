"""MoltBot 状态监控网页"""

import json
import os
import subprocess
import time
from datetime import datetime, timedelta

import psutil
from flask import Flask, Response

app = Flask(__name__)
START_TIME = time.time()


def get_gateway_status():
    """检查 OpenClaw Gateway 是否在运行"""
    for proc in psutil.process_iter(["pid", "name", "cmdline"]):
        try:
            cmdline = " ".join(proc.info.get("cmdline") or [])
            if "openclaw" in cmdline and "gateway" in cmdline:
                return {"running": True, "pid": proc.info["pid"]}
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            continue
    return {"running": False, "pid": None}


def get_feishu_status():
    """检查飞书连接状态（通过日志）"""
    log_file = f"/tmp/openclaw/openclaw-{datetime.now().strftime('%Y-%m-%d')}.log"
    if not os.path.exists(log_file):
        return "unknown"
    try:
        result = subprocess.run(
            ["tail", "-100", log_file],
            capture_output=True, text=True, timeout=5
        )
        lines = result.stdout
        if "[feishu]" in lines:
            if "ws client ready" in lines or "Received from" in lines:
                return "connected"
            elif "auto-restart" in lines:
                return "reconnecting"
        return "initializing"
    except Exception:
        return "unknown"


def get_message_count():
    """统计今日消息数"""
    log_file = f"/tmp/openclaw/openclaw-{datetime.now().strftime('%Y-%m-%d')}.log"
    if not os.path.exists(log_file):
        return 0
    try:
        result = subprocess.run(
            ["grep", "-c", "Received from", log_file],
            capture_output=True, text=True, timeout=5
        )
        return int(result.stdout.strip() or 0)
    except Exception:
        return 0


def get_system_info():
    """获取系统资源信息"""
    uptime = timedelta(seconds=int(time.time() - START_TIME))
    return {
        "cpu_percent": psutil.cpu_percent(interval=0.5),
        "memory": psutil.virtual_memory()._asdict(),
        "uptime": str(uptime),
    }


def format_bytes(b):
    """格式化字节"""
    for unit in ["B", "KB", "MB", "GB"]:
        if b < 1024:
            return f"{b:.1f} {unit}"
        b /= 1024
    return f"{b:.1f} TB"


STATUS_COLORS = {
    "connected": "#00e676",
    "reconnecting": "#ffc107",
    "initializing": "#2196f3",
    "unknown": "#9e9e9e",
}

STATUS_TEXT = {
    "connected": "✅ 已连接",
    "reconnecting": "🔄 重连中",
    "initializing": "⏳ 初始化中",
    "unknown": "❓ 未知",
}


@app.route("/")
def index():
    gw = get_gateway_status()
    feishu = get_feishu_status()
    msgs = get_message_count()
    sys_info = get_system_info()
    mem = sys_info["memory"]

    feishu_color = STATUS_COLORS.get(feishu, "#9e9e9e")
    feishu_text = STATUS_TEXT.get(feishu, "❓ 未知")
    gw_color = "#00e676" if gw["running"] else "#f44336"
    gw_text = f"✅ 运行中 (PID {gw['pid']})" if gw["running"] else "❌ 已停止"

    html = f"""<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<meta http-equiv="refresh" content="30">
<title>MoltBot 状态监控</title>
<style>
* {{ margin: 0; padding: 0; box-sizing: border-box; }}
body {{
    font-family: 'Segoe UI', -apple-system, BlinkMacSystemFont, sans-serif;
    background: linear-gradient(135deg, #0f0c29, #302b63, #24243e);
    min-height: 100vh;
    color: #e0e0e0;
    padding: 20px;
}}
.container {{ max-width: 800px; margin: 0 auto; }}
.header {{
    text-align: center;
    padding: 40px 20px 30px;
}}
.header h1 {{
    font-size: 2.2em;
    background: linear-gradient(135deg, #667eea, #764ba2);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    margin-bottom: 8px;
}}
.header p {{ color: #9e9e9e; font-size: 0.95em; }}
.cards {{ display: grid; grid-template-columns: 1fr 1fr; gap: 16px; margin-top: 24px; }}
.card {{
    background: rgba(255,255,255,0.06);
    backdrop-filter: blur(12px);
    border: 1px solid rgba(255,255,255,0.08);
    border-radius: 16px;
    padding: 24px;
    transition: transform 0.2s, box-shadow 0.2s;
}}
.card:hover {{
    transform: translateY(-2px);
    box-shadow: 0 8px 32px rgba(102,126,234,0.15);
}}
.card-title {{
    font-size: 0.85em;
    color: #9e9e9e;
    text-transform: uppercase;
    letter-spacing: 1px;
    margin-bottom: 12px;
}}
.card-value {{
    font-size: 1.4em;
    font-weight: 600;
}}
.status-dot {{
    display: inline-block;
    width: 10px; height: 10px;
    border-radius: 50%;
    margin-right: 8px;
    animation: pulse 2s infinite;
}}
@keyframes pulse {{
    0%, 100% {{ opacity: 1; }}
    50% {{ opacity: 0.5; }}
}}
.card-full {{ grid-column: 1 / -1; }}
.stats-grid {{ display: grid; grid-template-columns: repeat(3, 1fr); gap: 12px; margin-top: 12px; }}
.stat {{ text-align: center; }}
.stat-value {{ font-size: 1.6em; font-weight: 700; color: #667eea; }}
.stat-label {{ font-size: 0.8em; color: #9e9e9e; margin-top: 4px; }}
.progress-bar {{
    width: 100%;
    height: 8px;
    background: rgba(255,255,255,0.1);
    border-radius: 4px;
    margin-top: 8px;
    overflow: hidden;
}}
.progress-fill {{
    height: 100%;
    border-radius: 4px;
    transition: width 0.5s;
}}
.footer {{
    text-align: center;
    padding: 30px;
    color: #616161;
    font-size: 0.85em;
}}
@media (max-width: 600px) {{
    .cards {{ grid-template-columns: 1fr; }}
    .stats-grid {{ grid-template-columns: 1fr; }}
}}
</style>
</head>
<body>
<div class="container">
    <div class="header">
        <h1>🤖 MoltBot AI</h1>
        <p>飞书智能助手 · 状态监控</p>
    </div>

    <div class="cards">
        <div class="card">
            <div class="card-title">OpenClaw 网关</div>
            <div class="card-value">
                <span class="status-dot" style="background:{gw_color}"></span>
                {gw_text}
            </div>
        </div>

        <div class="card">
            <div class="card-title">飞书连接</div>
            <div class="card-value">
                <span class="status-dot" style="background:{feishu_color}"></span>
                {feishu_text}
            </div>
        </div>

        <div class="card card-full">
            <div class="card-title">系统概览</div>
            <div class="stats-grid">
                <div class="stat">
                    <div class="stat-value">{sys_info['uptime']}</div>
                    <div class="stat-label">运行时长</div>
                </div>
                <div class="stat">
                    <div class="stat-value">{msgs}</div>
                    <div class="stat-label">今日消息</div>
                </div>
                <div class="stat">
                    <div class="stat-value">{os.environ.get('MODEL_NAME', 'N/A')}</div>
                    <div class="stat-label">当前模型</div>
                </div>
            </div>
        </div>

        <div class="card">
            <div class="card-title">CPU 使用率</div>
            <div class="card-value">{sys_info['cpu_percent']}%</div>
            <div class="progress-bar">
                <div class="progress-fill" style="width:{sys_info['cpu_percent']}%;background:linear-gradient(90deg,#667eea,#764ba2)"></div>
            </div>
        </div>

        <div class="card">
            <div class="card-title">内存使用</div>
            <div class="card-value">{format_bytes(mem['used'])} / {format_bytes(mem['total'])}</div>
            <div class="progress-bar">
                <div class="progress-fill" style="width:{mem['percent']}%;background:linear-gradient(90deg,#00e676,#00c853)"></div>
            </div>
        </div>
    </div>

    <div class="footer">
        最后更新: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')} · 自动刷新 30s
    </div>
</div>
</body>
</html>"""
    return Response(html, content_type="text/html; charset=utf-8")


@app.route("/health")
def health():
    gw = get_gateway_status()
    return json.dumps({
        "status": "ok" if gw["running"] else "error",
        "gateway": gw,
        "feishu": get_feishu_status(),
        "uptime": time.time() - START_TIME,
    }), 200 if gw["running"] else 503


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=7860)
