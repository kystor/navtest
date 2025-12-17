#!/bin/bash
# -----------------------------------------------------------------------------
# entrypoint.sh - 容器启动引导 (支持热重载)
# -----------------------------------------------------------------------------

# 1. 确保 backup.sh 可执行
if [ -f "./backup.sh" ]; then
    chmod +x ./backup.sh
fi

# 2. 启动自动同步服务 (后台运行)
if [ -n "$GITHUB_TOKEN" ]; then
    echo "[Entrypoint] 检测到 GITHUB_TOKEN..."
    if [ -f "./backup.sh" ]; then
        echo "[Entrypoint] 正在后台启动自动同步服务..."
        ./backup.sh &
    else
        echo "[Entrypoint-警告] 未找到 backup.sh 文件！"
    fi
else
    echo "[Entrypoint] 未设置 GITHUB_TOKEN，仅启动主程序。"
fi

# 3. 启动应用程序 (核心修改点)
echo "[Entrypoint] 正在启动应用程序 (使用 Nodemon 监控数据库变动)..."

# 解析：
# exec: 替换当前进程
# nodemon: 监控工具
# --watch database/nav.db: 只要这个文件变了，就重启
# --delay 2: 变动后等2秒再重启 (防止文件还没复制完就重启)
# app.js: 你的入口文件

exec nodemon \
  --watch database/nav.db \
  --delay 2 \
  app.js
