#!/bin/bash

echo "========================================"
echo "  GitHub 代理中继服务 - 一键安装"
echo "========================================"
echo ""

# 输入已部署的 gh-proxy 地址
read -p "请输入已部署的 gh-proxy 地址 (例如 http://1.2.3.4:80 或 https://ghproxy.example.com): " C_SERVER
C_SERVER="${C_SERVER%/}"

if [ -z "$C_SERVER" ]; then
    echo "错误: gh-proxy 地址不能为空！"
    exit 1
fi

# 输入本服务监听端口
read -p "请输入本服务监听端口 [默认: 9010]: " PORT
PORT=${PORT:-9010}

# 创建工作目录
WORK_DIR="/opt/cn_proxy"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# 生成 requirements.txt
cat > requirements.txt << 'EOF'
flask
requests
EOF

# 生成 relay_proxy.py
cat > relay_proxy.py << 'PYEOF'
# -*- coding: utf-8 -*-
import os
import requests
from flask import Flask, Response, request, redirect
from urllib.parse import quote

C_SERVER = os.environ.get('C_SERVER', '').rstrip('/')
if not C_SERVER:
    print('错误: 请设置环境变量 C_SERVER')
    exit(1)
HOST = '0.0.0.0'
PORT = int(os.environ.get('PORT', '9010'))

app = Flask(__name__)
CHUNK_SIZE = 1024 * 10
NO_PROXY = {'http': None, 'https': None}

INDEX_HTML = '''<!DOCTYPE html>
<html lang="zh">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>通用加速中继</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, "Segoe UI", sans-serif;
            min-height: 100vh;
            display: flex; align-items: center; justify-content: center;
            background: linear-gradient(135deg, #0f0c29, #302b63, #24243e);
            color: #e0e0e0;
        }
        .container { width: 100%; max-width: 560px; padding: 20px; }
        h1 {
            font-size: 28px; font-weight: 700; text-align: center;
            background: linear-gradient(90deg, #667eea, #764ba2);
            -webkit-background-clip: text; -webkit-text-fill-color: transparent;
            margin-bottom: 8px;
        }
        .subtitle { text-align: center; color: #999; font-size: 14px; margin-bottom: 30px; }
        .input-box {
            display: flex; gap: 8px;
            background: rgba(255,255,255,0.06); border-radius: 12px;
            padding: 6px; border: 1px solid rgba(255,255,255,0.1);
        }
        .input-box input {
            flex: 1; padding: 12px 16px; font-size: 15px;
            background: transparent; border: none; outline: none;
            color: #fff;
        }
        .input-box input::placeholder { color: #666; }
        .input-box button {
            padding: 12px 24px; font-size: 15px; font-weight: 600;
            background: linear-gradient(135deg, #667eea, #764ba2);
            color: #fff; border: none; border-radius: 8px; cursor: pointer;
            transition: opacity 0.2s;
        }
        .input-box button:hover { opacity: 0.85; }
        .tips {
            margin-top: 28px; padding: 16px 20px;
            background: rgba(255,255,255,0.04); border-radius: 10px;
            border: 1px solid rgba(255,255,255,0.06);
        }
        .tips p { font-size: 13px; color: #888; line-height: 2; }
        .tips code {
            background: rgba(255,255,255,0.08); padding: 2px 6px;
            border-radius: 4px; font-size: 12px; color: #a8b2d1;
        }
        .tag {
            display: inline-block; font-size: 11px; padding: 2px 8px;
            border-radius: 4px; margin-right: 4px; font-weight: 600;
        }
        .tag-get { background: rgba(102,126,234,0.2); color: #667eea; }
        .tag-clone { background: rgba(118,75,162,0.2); color: #a78bfa; }
    </style>
</head>
<body>
    <div class="container">
        <h1>⚡ 通用加速中继</h1>
        <p class="subtitle">支持任意 HTTPS 链接加速访问 · 脚本自动替换</p>
        <form action="/" method="get">
            <div class="input-box">
                <input name="q" placeholder="粘贴完整URL，如 https://github.com/..." autofocus />
                <button type="submit">GO</button>
            </div>
        </form>
        <div class="tips">
            <p><span class="tag tag-get">下载</span> <code>http://本站/https://github.com/user/repo/archive/master.zip</code></p>
            <p><span class="tag tag-clone">克隆</span> <code>git clone http://本站/https://github.com/user/repo.git</code></p>
            <p><span class="tag tag-get">通用</span> <code>http://本站/https://任意网站/路径/文件</code></p>
        </div>
    </div>
</body>
</html>'''


@app.route('/')
def index():
    if 'q' in request.args:
        return redirect('/' + request.args.get('q'))
    return INDEX_HTML


import re

def replace_urls(content, proxy_base):
    # 将脚本中所有 https:// 链接替换为代理链接
    # 避免替换已经是代理链接的URL
    def replacer(match):
        url = match.group(0)
        if proxy_base in url:
            return url
        return proxy_base + '/' + url
    content = re.sub(r'https?://[a-zA-Z0-9][-a-zA-Z0-9.]*\.[a-zA-Z]{2,}', replacer, content)
    return content


SCRIPT_EXTENSIONS = {'.sh', '.bash', '.py', '.rb', '.pl', '.yml', '.yaml', '.txt', '.md', '.conf', '.cfg'}


def is_script_file(url_path):
    path = url_path.split('?')[0].lower()
    for ext in SCRIPT_EXTENSIONS:
        if path.endswith(ext):
            return True
    return False


@app.route('/<path:u>', methods=['GET', 'POST'])
def relay(u):
    target_url = C_SERVER + '/' + u
    query_string = request.query_string.decode('utf-8')
    if query_string:
        target_url += '?' + query_string
    headers = {k: v for k, v in request.headers if k.lower() not in ('host', 'accept-encoding')}
    try:
        r = requests.request(
            method=request.method,
            url=target_url,
            data=request.data,
            headers=headers,
            stream=True,
            allow_redirects=False,
            timeout=300,
            proxies=NO_PROXY
        )
        resp_headers = dict(r.headers)
        if 'Location' in resp_headers:
            location = resp_headers['Location']
            if location.startswith(C_SERVER):
                location = location[len(C_SERVER):]
            if location.startswith('/'):
                resp_headers['Location'] = location
            elif location.startswith('http'):
                resp_headers['Location'] = '/' + location
        for h in ('Transfer-Encoding', 'Content-Encoding', 'Content-Length'):
            resp_headers.pop(h, None)
        if is_script_file(u):
            content = r.content.decode('utf-8', errors='replace')
            proxy_base = request.host_url.rstrip('/')
            modified = replace_urls(content, proxy_base)
            return Response(modified, headers=resp_headers, status=r.status_code,
                            content_type='text/plain; charset=utf-8')
        def generate():
            for chunk in r.iter_content(chunk_size=CHUNK_SIZE):
                if chunk:
                    yield chunk
        return Response(generate(), headers=resp_headers, status=r.status_code)
    except requests.exceptions.ConnectionError:
        return Response(f'无法连接到上游服务器: {C_SERVER}', status=502)
    except requests.exceptions.Timeout:
        return Response('连接上游服务器超时', status=504)
    except Exception as e:
        return Response(f'代理错误: {str(e)}', status=500)


if __name__ == '__main__':
    print(f'中继代理已启动 | 监听: {HOST}:{PORT} | 上游: {C_SERVER}')
    app.run(host=HOST, port=PORT)
PYEOF

cat > Dockerfile << 'EOF'
FROM swr.cn-north-4.myhuaweicloud.com/ddn-k8s/docker.io/python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -i https://pypi.tuna.tsinghua.edu.cn/simple -r requirements.txt
COPY relay_proxy.py .
EXPOSE 9010
CMD ["python", "relay_proxy.py"]
EOF

# 停止旧容器
docker stop cn_proxy 2>/dev/null && docker rm cn_proxy 2>/dev/null

# 构建镜像
echo ""
echo ">> 构建 Docker 镜像..."
docker build -t cn_proxy .

if [ $? -ne 0 ]; then
    echo "错误: 镜像构建失败！"
    exit 1
fi

# 启动容器
echo ">> 启动容器..."
docker run -d \
    --name cn_proxy \
    -p "0.0.0.0:${PORT}:9010" \
    -e "C_SERVER=${C_SERVER}" \
    --restart=always \
    cn_proxy

if [ $? -eq 0 ]; then
    SERVER_IP=$(curl -s4 --max-time 5 ifconfig.me 2>/dev/null || hostname -I 2>/dev/null | awk '{print $1}' || echo "本机IP")
    echo ""
    echo "========================================"
    echo "  ✅ 部署成功！"
    echo "  服务地址: http://${SERVER_IP}:${PORT}"
    echo ""
    echo "  使用方式："
    echo "  wget http://${SERVER_IP}:${PORT}/https://github.com/user/repo/archive/master.zip"
    echo "  git clone http://${SERVER_IP}:${PORT}/https://github.com/user/repo.git"
    echo "========================================"
else
    echo "错误: 容器启动失败！"
    exit 1
fi
