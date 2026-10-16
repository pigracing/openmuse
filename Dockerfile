FROM mcr.microsoft.com/playwright:v1.62.1-noble

ENV NODE_ENV=production
ENV PNPM_HOME=/pnpm
ENV PATH=/pnpm:$PATH

WORKDIR /app

# 安装 pnpm
RUN npm install -g pnpm@11.19.0

# 复制源代码
COPY . .

# 安装依赖，构建 API 和 Web
RUN pnpm install --frozen-lockfile \
    && pnpm build:server \
    && pnpm --dir apps/mobile exec expo export \
       --platform web \
       --output-dir dist/web \
       --clear

# 安装 Worker 生产依赖
RUN cd apps/worker \
    && npm ci --omit=dev --ignore-scripts

# 创建数据目录
RUN mkdir -p /data/openmuse /data/browser-profiles

# API
ENV HOST=0.0.0.0
ENV PORT=8787
ENV DATA_DIR=/data/openmuse

# Browser Worker
ENV WORKER_HOST=0.0.0.0
ENV WORKER_DATA_DIR=/data/browser-profiles
ENV BROWSER_WORKER_URL=http://127.0.0.1:8790

EXPOSE 8080 8787 8790

COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]
