# -----------------------------------------------------------------------------
# Dockerfile - 最终优化版
# -----------------------------------------------------------------------------
FROM node:20-alpine3.20 AS frontend-builder

WORKDIR /app

COPY web/package*.json ./
RUN npm install

COPY web/ ./
RUN npm run build

# 生产环境
FROM node:20-alpine3.20 AS production

# [修改点 1] 安装依赖
# 增加 sed 是为了处理文本格式，git 和 bash 是为了备份脚本
RUN apk add --no-cache \
    sqlite \
    git \
    bash \
    sed \
    && rm -rf /var/cache/apk/*

WORKDIR /app

RUN mkdir -p uploads database web/dist

COPY package*.json ./
RUN npm install

COPY app.js config.js db.js ./
COPY routes/ ./routes/
COPY --from=frontend-builder /app/dist ./web/dist

# [修改点 2] 复制备份脚本和启动脚本
COPY backup.sh entrypoint.sh ./

# [修改点 3] 关键修改：权限赋予 + 格式转换
# sed -i 's/\r$//' ... 这行命令会把 Windows 的回车符删掉，防止脚本报错
RUN sed -i 's/\r$//' backup.sh entrypoint.sh && \
    chmod +x backup.sh entrypoint.sh

ENV NODE_ENV=production

EXPOSE 3000/tcp

# [修改点 4] 启动入口
ENTRYPOINT ["./entrypoint.sh"]
