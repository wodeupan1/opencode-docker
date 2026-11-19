FROM --platform=linux/amd64 debian:trixie-slim

ARG OPENCODE_VERSION=""
ARG NODE_VERSION=24.11.0
ARG DEBIAN_FRONTEND=noninteractive

ENV BUN_RUNTIME_TRANSPILER_CACHE_PATH=0

# ── 构建期：官方源（GHA 海外 runner 直连最快）──
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl wget xz-utils \
      git nano jq procps unzip openssl \
      python3 python3-venv python3-pip \
      chromium fonts-liberation fonts-noto-cjk \
      ripgrep libstdc++6 bash tar gzip \
 && rm -rf /var/lib/apt/lists/*

# Node 24 LTS 官方二进制 + sha256 校验
RUN set -eux; \
    cd /tmp; \
    curl -fsSLO "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz"; \
    curl -fsSLO "https://nodejs.org/dist/v${NODE_VERSION}/SHASUMS256.txt"; \
    grep "node-v${NODE_VERSION}-linux-x64.tar.xz" SHASUMS256.txt | sha256sum -c -; \
    tar -xJf "node-v${NODE_VERSION}-linux-x64.tar.xz" -C /usr/local --strip-components=1; \
    rm -f "node-v${NODE_VERSION}-linux-x64.tar.xz" SHASUMS256.txt; \
    node --version && npm --version

# pnpm（构建期走 npmjs 官方）
RUN npm install -g pnpm && npm cache clean --force

# uv / uvx（GHA 直连 ghcr 很快）
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/

# 默认 venv（规避 PEP 668）
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:${PATH}" \
    CHROME_BIN=/usr/bin/chromium \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium

# 无头 chromium 包装（root 需 --no-sandbox）；git 放行挂载目录
RUN printf '#!/bin/sh\nexec /usr/bin/chromium --headless=new --no-sandbox --disable-gpu "$@"\n' \
      > /usr/local/bin/chromium-headless \
 && chmod +x /usr/local/bin/chromium-headless \
 && git config --system --add safe.directory '*'

# opencode glibc baseline（amd64）+ sha256 校验；版本自动取 semver 最大
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

# ── 运行期：切国内源（容器在国内使用，agent 装包/apt 都走国内）──
RUN sed -i 's|deb.debian.org|mirrors.aliyun.com|g; s|security.debian.org|mirrors.aliyun.com|g' \
      /etc/apt/sources.list.d/debian.sources \
 && npm config set registry https://registry.npmmirror.com --location=global

ENV NPM_CONFIG_REGISTRY=https://registry.npmmirror.com \
    COREPACK_NPM_REGISTRY=https://registry.npmmirror.com \
    PIP_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple \
    UV_DEFAULT_INDEX=https://pypi.tuna.tsinghua.edu.cn/simple

WORKDIR /workspace
ENTRYPOINT ["opencode"]
