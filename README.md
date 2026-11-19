# opencode-docker

基于 Debian 的 [OpenCode](https://github.com/anomalyco/opencode) 容器镜像，适合通过 Docker Compose 运行 OpenCode 服务。镜像面向 `linux/amd64`，并附带 Node.js 24、Python 虚拟环境、pnpm、uv/uvx、Chromium 等常用工具。

## 特性

- 每天自动检查上游 OpenCode 稳定版，并发布到 GitHub Container Registry（GHCR）。
- 支持指定 OpenCode 版本或手动强制重建。
- 使用 glibc 的 x64 baseline 二进制并校验 SHA256，兼容不支持 AVX2 的部分旧款 x86_64 CPU。
- 基于 Debian Trixie，包含 Node.js 24、Git、Python、pnpm、uv/uvx、Chromium 等工具。
- Compose 持久化会话数据、凭据、配置和工作区。

## 快速开始

### 1. 配置镜像地址

编辑 `docker-compose.yml`，将镜像占位符替换为仓库所有者的 GitHub 用户名（小写）：

```yaml
image: ghcr.io/<你的GitHub用户名小写>/opencode-debian:latest
```

例如本仓库的镜像地址是 `ghcr.io/wodeupan1/opencode-debian:latest`。

### 2. 设置访问密码

修改 Compose 文件中的 `OPENCODE_PASSWORD`，使用足够长且随机的密码。HTTP Basic Auth 用户名固定为 `opencode`。也可以按需配置模型 API Key，例如 `ANTHROPIC_API_KEY` 或 `OPENAI_API_KEY`；请勿把真实密钥提交到公开仓库。

### 3. 启动服务

在 `docker-compose.yml` 所在目录运行：

```bash
mkdir -p data config workspace
docker compose up -d
```

服务启动后访问 <http://localhost:4096>，使用用户名 `opencode` 和设置的密码进行认证。查看日志或停止服务：

```bash
docker compose logs -f opencode
docker compose down
```

## 数据与目录

Compose 文件将以下目录挂载到容器中：

| 主机目录 | 容器路径 | 用途 |
| --- | --- | --- |
| `./data` | `/root/.local/share/opencode` | 会话数据库、`auth.json` 凭据和日志 |
| `./config` | `/root/.config/opencode` | OpenCode 全局配置，例如 `opencode.json` |
| `./workspace` | `/workspace` | OpenCode 操作的项目文件 |

请妥善保护 `data` 中的凭据文件，并定期备份需要保留的数据。

## 镜像构建与发布

GitHub Actions 会每天北京时间 02:00 检查上游稳定版本，并将镜像推送至 GHCR：

- `ghcr.io/<用户名小写>/opencode-debian:<版本号>`
- `ghcr.io/<用户名小写>/opencode-debian:latest`

同一版本标签已经发布时，自动任务会跳过重复构建。也可以在仓库的 **Actions → build-opencode-image → Run workflow** 中手动运行：

- `opencode_version` 留空时自动选择最新稳定版；也可以填写指定版本号。
- 修改 Dockerfile 或工具链后，可勾选 `force` 强制重新构建。

构建平台为 `linux/amd64`。Dockerfile 也支持直接构建；留空时会在构建过程中解析上游最新稳定版本：

```bash
docker build -f dockerfile -t opencode-debian:latest .
```

指定版本：

```bash
docker build -f dockerfile --build-arg OPENCODE_VERSION=<版本号> -t opencode-debian:<版本号> .
```

## 安全提示

默认 Compose 配置将服务端口映射到主机的 `4096` 端口。不要使用示例密码，也不要在未配置 HTTPS、安全访问控制及网络限制的情况下将服务直接暴露到公网。模型 API Key 和 OpenCode 凭据具有敏感性，请限制配置文件和数据目录的访问权限。

## 许可证

本仓库当前未声明许可证。请在使用或再分发前确认仓库许可证状态；OpenCode 上游项目的许可条款请参阅其官方仓库。