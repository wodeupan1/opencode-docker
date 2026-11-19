FROM --platform=linux/amd64 debian:trixie-slim

# 留空 = 构建时自动取上游最新稳定版（按 semver 取最大，避开 v1 维护线）
ARG OPENCODE_VERSION=""
ARG DEBIAN_FRONTEND=noninteractive

# 与官方镜像一致：关闭 bun 转译缓存
ENV BUN_RUNTIME_TRANSPILER_CACHE_PATH=0

# 基础工具 + Node 24 LTS（NodeSource，Debian 自带 node 太旧）+ 常用工具链
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl wget gnupg \
 && curl -fsSL https://deb.nodesource.com/setup_24.x | bash - \
 && apt-get install -y --no-install-recommends \
      nodejs \
      git nano jq procps unzip openssl \
      python3 python3-venv python3-pip \
      chromium fonts-liberation fonts-noto-cjk \
      ripgrep libstdc++6 bash tar gzip \
 && rm -rf /var/lib/apt/lists/*

# npm 全局包
RUN npm install -g pnpm && npm cache clean --force

# uv / uvx（官方静态二进制，glibc 下可用）
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/

# 默认 venv：规避 Debian PEP 668 限制，python/pip 开箱即用
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:${PATH}" \
    CHROME_BIN=/usr/bin/chromium \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium

# 无头 chromium 包装（容器 root 必须 --no-sandbox）；git 放行挂载目录
RUN printf '#!/bin/sh\nexec /usr/bin/chromium --headless=new --no-sandbox --disable-gpu "$@"\n' \
      > /usr/local/bin/chromium-headless \
 && chmod +x /usr/local/bin/chromium-headless \
 && git config --system --add safe.directory '*'

# opencode glibc baseline 二进制（amd64，兼容 J4125 等无 AVX2 CPU）+ sha256 校验
RUN set -eux; \
    cd /tmp; \
    if [ -z "$OPENCODE_VERSION" ]; then \
      OPENCODE_VERSION="$(curl -fsSL 'https://api.github.com/repos/anomalyco/opencode/releases?per_page=100' \
        | jq -r ' \
            [.[] | select(.draft == false and .prerelease == false) | .tag_name \
             | select(test("^v[0-9]+\\.[0-9]+\\.[0-9]+$"))] \
            | sort_by(ltrimstr("v") | split(".") | map(tonumber)) \
            | last // error("no stable release found") \
            | ltrimstr("v")')"; \
    fi; \
    test -n "$OPENCODE_VERSION"; \
    echo "building opencode v${OPENCODE_VERSION}"; \
    base="https://github.com/anomalyco/opencode/releases/download/v${OPENCODE_VERSION}"; \
    curl -fsSLO "${base}/opencode-linux-x64-baseline.tar.gz"; \
    curl -fsSLO "${base}/SHA256SUMS"; \
    grep "opencode-linux-x64-baseline.tar.gz" SHA256SUMS | sha256sum -c -; \
    tar -xzf opencode-linux-x64-baseline.tar.gz -C /usr/local/bin; \
    chmod +x /usr/local/bin/opencode; \
    ln -s opencode /usr/local/bin/opencode2; \
    rm -f opencode-linux-x64-baseline.tar.gz SHA256SUMS; \
    opencode --version

WORKDIR /workspace
ENTRYPOINT ["opencode"]
