# -----------------------------------------------------------------------------
# Dockerfile - 最终生产环境版
# -----------------------------------------------------------------------------
FROM node:20-alpine3.20 AS frontend-builder

WORKDIR /app
COPY web/package*.json ./
RUN npm install
COPY web/ ./
RUN npm run build

# 生产环境
FROM node:20-alpine3.20 AS production

# [关键 1] 安装所有依赖：
# - tzdata: 用于设置时区
# - git, bash: 用于备份脚本
# - sed: 用于修复 Windows 换行符
# - sqlite: 用于调试数据库
RUN apk add --no-cache \
    sqlite \
    git \
    bash \
    sed \
    tzdata \
    && rm -rf /var/cache/apk/*

# [关键 2] 设置时区为亚洲/上海 (北京时间)
# 这会让 date 命令和日志都显示正确的时间
ENV TZ=Asia/Shanghai

WORKDIR /app

RUN mkdir -p uploads database web/dist

COPY package*.json ./
RUN npm install

COPY app.js config.js db.js ./
COPY routes/ ./routes/
COPY --from=frontend-builder /app/dist ./web/dist

# [关键 3] 复制备份脚本
COPY backup.sh entrypoint.sh ./

# [关键 4] 权限与格式修复
# sed -i 's/\r$//' ... 去除 Windows 的回车符，防止报错
RUN sed -i 's/\r$//' backup.sh entrypoint.sh && \
    chmod +x backup.sh entrypoint.sh

ENV NODE_ENV=production
EXPOSE 3000/tcp

# 使用 entrypoint 启动
ENTRYPOINT ["./entrypoint.sh"]
