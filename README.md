# ⚡ CN-Proxy - 通用加速中继

国内服务器专用的代理中继，部署在可访问海外的国内服务器上，将请求转发到海外的 [DL-Proxy](https://github.com/Assute/dl_proxy)，实现无海外访问能力的服务器也能下载 GitHub 等资源。

## 功能特点

- 🔗 **通用中继** — 支持代理任意 HTTPS 链接
- 📜 **脚本自动替换** — 自动检测 `.sh`、`.py` 等脚本文件，将内部所有 HTTPS 链接替换为代理链接
- 🐳 **一键 Docker 部署** — 使用国内镜像源，无需海外网络
- 🔄 **自动重启** — 容器异常退出后自动恢复

## 架构

```
客户端(A) → CN-Proxy(B:9010) → DL-Proxy(C:9011) → 目标网站
```

- **A 服务器**：无法访问海外
- **B 服务器**：国内，可访问 C（部署 CN-Proxy）
- **C 服务器**：海外，可访问目标网站（部署 [DL-Proxy](https://github.com/Assute/dl_proxy)）

## 前置条件

先在 C 服务器部署 [DL-Proxy](https://github.com/Assute/dl_proxy)：

```bash
bash <(curl -sL https://raw.githubusercontent.com/Assute/dl_proxy/main/dl_proxy.sh)
```

## 快速安装

在 B 服务器上执行：

```bash
bash <(curl -sL https://raw.githubusercontent.com/Assute/cn_proxy/main/cn_proxy.sh)
```

安装时需要输入：
1. **DL-Proxy 地址**（C 服务器地址，如 `http://1.2.3.4:9011`）
2. **监听端口**（默认 `9010`）

## 使用方式

```bash
# 下载文件
wget http://B服务器IP:9010/https://github.com/user/repo/archive/master.zip

# 克隆仓库
git clone http://B服务器IP:9010/https://github.com/user/repo.git

# 下载并执行脚本（内部链接自动替换）
bash <(curl -sL http://B服务器IP:9010/https://raw.githubusercontent.com/user/repo/main/install.sh)

# 代理任意网站
curl http://B服务器IP:9010/https://example.com/path/to/file
```

## 脚本自动替换

当下载的文件是脚本类型时（`.sh`、`.py`、`.yml` 等），CN-Proxy 会自动将脚本内的所有 HTTPS 链接替换为代理链接，确保脚本执行时也走代理。

**示例：** 原始脚本中的
```
curl -sL https://github.com/user/repo/releases/download/v1.0/app
```
会被自动替换为
```
curl -sL http://B服务器IP:9010/https://github.com/user/repo/releases/download/v1.0/app
```

## 管理命令

```bash
# 查看日志
docker logs -f cn_proxy

# 重启服务
docker restart cn_proxy

# 停止服务
docker stop cn_proxy

# 卸载
docker stop cn_proxy && docker rm cn_proxy && docker rmi cn_proxy
```

## 系统要求

- Linux 服务器（国内可访问 C 服务器）
- Docker 已安装
- C 服务器已部署 [DL-Proxy](https://github.com/Assute/dl_proxy)

## License

MIT
