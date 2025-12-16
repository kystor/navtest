# -----------------------------------------------------------------------------
# Dockerfile
# -----------------------------------------------------------------------------
FROM node:20-alpine3.20 AS frontend-builder

WORKDIR /app

COPY web/package*.json ./
RUN npm install

COPY web/ ./
RUN npm run build

# 生产环境
FROM node:20-alpine3.20 AS production

# [修改点 1] 安装 git 和 bash (用于备份脚本)
RUN apk add --no-cache \
    sqlite \
    git \
    bash \
    && rm -rf /var/cache/apk/*

WORKDIR /app

RUN mkdir -p uploads database web/dist

COPY package*.json ./
RUN npm install

COPY app.js config.js db.js ./
COPY routes/ ./routes/
COPY --from=frontend-builder /app/dist ./web/dist

# [修改点 2] 复制备份脚本和启动脚本到容器中
COPY backup.sh entrypoint.sh ./

# [修改点 3] 赋予脚本可执行权限
RUN chmod +x backup.sh entrypoint.sh

ENV NODE_ENV=production

EXPOSE 3000/tcp

# [修改点 4] 使用自定义的启动脚本替代原来的 CMD
ENTRYPOINT ["./entrypoint.sh"]
