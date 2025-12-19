# -----------------------------------------------------------------------------
# Dockerfile - (支持 SQL 文本备份 + 自动刷新)
# -----------------------------------------------------------------------------
FROM node:20-alpine3.20 AS frontend-builder

WORKDIR /app
COPY web/package*.json ./
RUN npm install
COPY web/ ./
RUN npm run build

# --- 生产环境 ---
FROM node:20-alpine3.20 AS production

# [关键修改] 安装 sqlite (用于导出/导入 SQL) 和 git
RUN apk add --no-cache \
    sqlite \
    git \
    bash \
    sed \
    tzdata \
    && rm -rf /var/cache/apk/* \
    && npm install -g nodemon

# 设置时区
ENV TZ=Asia/Shanghai

WORKDIR /app
RUN mkdir -p uploads database web/dist

COPY package*.json ./
RUN npm install

COPY app.js config.js db.js ./
COPY routes/ ./routes/
COPY --from=frontend-builder /app/dist ./web/dist

# 复制脚本
COPY backup.sh entrypoint.sh ./

# 权限处理 (确保脚本可执行)
RUN sed -i 's/\r$//' backup.sh entrypoint.sh && \
    chmod +x backup.sh entrypoint.sh

ENV NODE_ENV=production
EXPOSE 3000/tcp

# 启动入口
ENTRYPOINT ["./entrypoint.sh"]
