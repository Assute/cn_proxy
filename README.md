# CN Proxy 安装脚本说明

`cn_proxy.sh` 是一个一键部署脚本，主要用于被屏蔽海外访问的国内服务器做加速：在国内服务器上快速搭建中继代理服务，将请求转发到你已部署的上游 `gh-proxy`。

## 一键安装

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Assute/cn_proxy/main/cn_proxy.sh)
```

## 安装时会让你填写

- `gh-proxy` 地址（示例：`http://1.2.3.4:8080`）
- 本机监听端口（默认：`9010`）

## 脚本会自动完成

- 识别系统（Alpine / Debian/Ubuntu / CentOS/RHEL）
- 安装并配置 Nginx
- 生成代理配置并启动服务
- 输出可直接使用的访问地址

## 使用示例

```bash
wget "http://你的服务器IP:9010/https://github.com/user/repo/archive/refs/heads/main.zip"
```

## 说明

- 请先确保上游 `gh-proxy` 可用。
- 脚本需在 Linux 服务器执行，并具备安装软件权限（通常为 root）。

