#!/bin/bash

echo "========================================"
echo "  GitHub 代理中继服务 - 一键安装"
echo "========================================"
echo ""

# 输入已部署的 gh-proxy 地址
read -p "请输入已部署的 gh-proxy 地址 (例如 http://1.2.3.4:8080 或 https://ghproxy.example.com): " C_SERVER
C_SERVER="${C_SERVER%/}"

if [ -z "$C_SERVER" ]; then
    echo "错误: gh-proxy 地址不能为空！"
    exit 1
fi

# 输入本服务监听端口
read -p "请输入本服务监听端口 [默认: 9010]: " PORT
PORT=${PORT:-9010}

# 提取上游 host（用于 SNI 和 Host 头）
C_SERVER_HOST=$(echo "$C_SERVER" | sed 's|https\?://||' | cut -d'/' -f1)

# 创建工作目录
WORK_DIR="/opt/cn_proxy"
mkdir -p "$WORK_DIR"

# 检测系统并安装 nginx
echo ""
echo ">> 检测系统..."
if [ -f /etc/alpine-release ]; then
    OS="alpine"
elif [ -f /etc/debian_version ]; then
    OS="debian"
elif [ -f /etc/redhat-release ] || [ -f /etc/centos-release ]; then
    OS="rhel"
else
    echo "错误: 不支持的系统！（仅支持 Alpine / Debian/Ubuntu / CentOS/RHEL）"
    exit 1
fi
echo ">> 检测到系统: $OS，安装 nginx..."

case "$OS" in
    alpine)
        apk add --no-cache nginx
        ;;
    debian)
        apt-get update -qq && apt-get install -y -q nginx
        ;;
    rhel)
        if command -v dnf &>/dev/null; then
            dnf install -y nginx
        else
            yum install -y nginx
        fi
        ;;
esac

# 生成首页 HTML
cat > "$WORK_DIR/index.html" << 'HTMLEOF'
<!DOCTYPE html>
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
        <h1>通用加速中继</h1>
        <p class="subtitle">支持任意 HTTPS 链接加速访问</p>
        <div class="tips">
            <p><span class="tag tag-get">下载</span> <code>http://本站/https://github.com/user/repo/archive/master.zip</code></p>
            <p><span class="tag tag-clone">克隆</span> <code>git clone http://本站/https://github.com/user/repo.git</code></p>
            <p><span class="tag tag-get">通用</span> <code>http://本站/https://任意网站/路径/文件</code></p>
        </div>
    </div>
</body>
</html>
HTMLEOF

# 检测 nginx 配置目录（Alpine 新版用 http.d，旧版用 conf.d）
if grep -q 'http.d' /etc/nginx/nginx.conf 2>/dev/null; then
    CONF_DIR="/etc/nginx/http.d"
else
    CONF_DIR="/etc/nginx/conf.d"
fi
mkdir -p "$CONF_DIR"

# 生成 nginx 配置
cat > "$CONF_DIR/cn_proxy.conf" << EOF
server {
    listen ${PORT};

    root ${WORK_DIR};

    location = / {
        try_files /index.html =404;
    }

    location ~ ^/(.+)\$ {
        proxy_pass ${C_SERVER}/\$1\$is_args\$args;
        proxy_ssl_server_name on;
        proxy_set_header Host ${C_SERVER_HOST};
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_read_timeout 300;
        proxy_buffering off;
        client_max_body_size 0;
    }
}
EOF

# 检测配置语法
echo ">> 检查 nginx 配置..."
nginx -t
if [ $? -ne 0 ]; then
    echo "错误: nginx 配置有误！"
    exit 1
fi

# 启动或重载
if [ "$OS" = "alpine" ]; then
    nginx -s reload 2>/dev/null || nginx
else
    systemctl enable nginx 2>/dev/null || true
    systemctl restart nginx
fi

if [ $? -eq 0 ]; then
    SERVER_IP=$(curl -s4 --max-time 5 ifconfig.me 2>/dev/null || hostname -I 2>/dev/null | awk '{print $1}' || echo "本机IP")
    echo ""
    echo "========================================"
    echo "  部署成功！"
    echo "  服务地址: http://${SERVER_IP}:${PORT}"
    echo ""
    echo "  使用方式："
    echo "  wget http://${SERVER_IP}:${PORT}/https://github.com/user/repo/archive/master.zip"
    echo "  git clone http://${SERVER_IP}:${PORT}/https://github.com/user/repo.git"
    echo "========================================"
else
    echo "错误: nginx 启动失败！"
    exit 1
fi
