#!/usr/bin/env bash

set -Eeuo pipefail

cd /app

# 生产模式必须显式配置必要的密钥
if [[ -z "${CPK_INTELLIGENCE_API_KEY:-}" ]]; then
    echo "ERROR: CPK_INTELLIGENCE_API_KEY is required."
    exit 1
fi

if [[ "${WORKSPACE_MODE:-live}" == "live" ]]; then
    if [[ -z "${OPENMUSE_ACCESS_KEY:-}" ]]; then
        echo "ERROR: OPENMUSE_ACCESS_KEY is required."
        exit 1
    fi

    if [[ -z "${TOKEN_ENCRYPTION_KEY:-}" ]]; then
        echo "ERROR: TOKEN_ENCRYPTION_KEY is required."
        exit 1
    fi
fi

# 统一配置运行参数
export NODE_ENV=production
export HOST=127.0.0.1
export PORT=8787
export WORKER_HOST=127.0.0.1
export WORKER_DATA_DIR=/data/browser-profiles
export DATA_DIR=/data/openmuse
export BROWSER_WORKER_URL=http://127.0.0.1:8790

mkdir -p "$DATA_DIR" "$WORKER_DATA_DIR"

# Browser Worker
node --experimental-strip-types \
    apps/worker/src/index.ts &
WORKER_PID=$!

# API
node dist/apps/server/src/index.js &
API_PID=$!

# Nginx 前台进程
nginx -g 'daemon off;' &
NGINX_PID=$!

shutdown() {
    echo "Stopping OpenMuse..."

    kill -TERM "$NGINX_PID" "$API_PID" "$WORKER_PID" 2>/dev/null || true

    wait "$NGINX_PID" "$API_PID" "$WORKER_PID" 2>/dev/null || true
}

trap shutdown SIGTERM SIGINT

# 任一核心进程退出时，结束容器
set +e
wait -n "$WORKER_PID" "$API_PID" "$NGINX_PID"
STATUS=$?
set -e

shutdown
exit "$STATUS"
