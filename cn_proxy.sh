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

if command -v nginx &>/dev/null; then
    echo ">> nginx 已安装，跳过"
else
    case "$OS" in
        alpine)
            # 释放页面缓存，腾出内存
            sync && echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
            # 只用 main 仓库，减少 APKINDEX 加载量
            ALPINE_VER=$(cat /etc/alpine-release | cut -d'.' -f1-2)
            echo "https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VER}/main" > /tmp/apk_repos
            apk add --no-cache --repositories-file /tmp/apk_repos nginx
            # 若仍失败，尝试直接下载 .apk 安装（完全跳过索引加载）
            if ! command -v nginx &>/dev/null; then
                echo ">> 常规安装失败，尝试直接下载安装..."
                ARCH=$(uname -m)
                BASE="https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VER}/main/${ARCH}"
                mkdir -p /tmp/ngx_pkgs
                for pkg in pcre nginx; do
                    FNAME=$(wget -qO- "${BASE}/" 2>/dev/null | grep -o "\"${pkg}-[0-9][^\"]*\.apk\"" | head -1 | tr -d '"')
                    [ -n "$FNAME" ] && wget -qP /tmp/ngx_pkgs "${BASE}/${FNAME}"
                done
                apk add --allow-untrusted /tmp/ngx_pkgs/*.apk 2>/dev/null
                rm -rf /tmp/ngx_pkgs
            fi
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
fi

if ! command -v nginx &>/dev/null; then
    echo "错误: nginx 安装失败！"
    echo "提示: 可能是内存不足，尝试先创建 swap："
    echo "  dd if=/dev/zero of=/swapfile bs=1M count=256 && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile"
    exit 1
fi

# 生成首页 HTML
cat > "$WORK_DIR/index.html" << 'HTMLEOF'
<!DOCTYPE html>
<html lang="zh">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>通用加速代理</title>
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
        <h1>⚡ 通用加速代理</h1>
        <p class="subtitle">支持任意 HTTPS 链接加速访问</p>
        <div class="input-box">
            <input id="url" placeholder="粘贴完整URL，如 https://github.com/..." autofocus />
            <button onclick="go()">GO</button>
        </div>
        <div class="tips">
            <p><span class="tag tag-get">下载</span> <code>http://本站/https://github.com/user/repo/archive/master.zip</code></p>
            <p><span class="tag tag-clone">克隆</span> <code>git clone http://本站/https://github.com/user/repo.git</code></p>
            <p><span class="tag tag-get">通用</span> <code>http://本站/https://任意网站/路径/文件</code></p>
        </div>
    </div>
    <script>
        function go() {
            var u = document.getElementById('url').value.trim();
            if (u) window.location.href = '/' + u;
        }
        document.getElementById('url').addEventListener('keydown', function(e) {
            if (e.key === 'Enter') go();
        });
    </script>
</body>
</html>
HTMLEOF

# 确定 nginx 配置目录（Alpine 用 http.d，其他系统用 conf.d）
if [ "$OS" = "alpine" ]; then
    CONF_DIR="/etc/nginx/http.d"
else
    CONF_DIR="/etc/nginx/conf.d"
fi
mkdir -p "$CONF_DIR"

# 生成 nginx 配置
cat > "$CONF_DIR/cn_proxy.conf" << EOF
server {
    listen ${PORT};
    merge_slashes off;
    resolver 114.114.114.114 223.5.5.5 valid=300s;

    root ${WORK_DIR};

    location = / {
        try_files /index.html =404;
    }

    location ~ "^/(.*\.(sh|bash|py|rb|pl|yml|yaml|txt|conf|cfg))\$" {
        proxy_pass ${C_SERVER}/\$1\$is_args\$args;
        proxy_ssl_server_name on;
        proxy_ssl_verify off;
        proxy_set_header Host ${C_SERVER_HOST};
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header Accept-Encoding "";
        proxy_read_timeout 300;
        proxy_buffering off;
        client_max_body_size 0;
        sub_filter_once off;
        sub_filter_types *;
        sub_filter 'https://' '\$scheme://\$host/https://';
    }

    location ~ ^/(.+)\$ {
        proxy_pass ${C_SERVER}/\$1\$is_args\$args;
        proxy_ssl_server_name on;
        proxy_ssl_verify off;
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

# 启动或重载，并设置开机自启
if [ "$OS" = "alpine" ]; then
    nginx -s reload 2>/dev/null || nginx
    rc-update add nginx default 2>/dev/null || true
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
