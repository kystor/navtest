#!/bin/bash
# -----------------------------------------------------------------------------
# entrypoint.sh - 容器启动引导 (优化版)
# -----------------------------------------------------------------------------

# 定义一个用于触发重启的空文件
TRIGGER_FILE="/app/.restart_trigger"
if [ ! -f "$TRIGGER_FILE" ]; then
    touch "$TRIGGER_FILE"
fi

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

# 3. 启动应用程序
echo "[Entrypoint] 正在启动应用程序..."
echo "[Entrypoint] 监听模式: 仅在云端同步触发时重启 (监听 .restart_trigger)"

# 核心修改：
# 不再监听 nav.db，而是监听 .restart_trigger
# 这样你本地添加书签、登录时，服务不会重启，体验更丝滑
exec nodemon \
  --watch "$TRIGGER_FILE" \
  --delay 1 \
  app.js
