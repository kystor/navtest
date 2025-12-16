#!/bin/bash
# -----------------------------------------------------------------------------
# entrypoint.sh - 容器启动入口脚本
# 作用：作为 Docker 的 PID 1 进程，负责初始化环境、启动辅助进程，最后启动主程序
# -----------------------------------------------------------------------------

# 0. 权限修正 (关键步骤)
# 确保 backup.sh 有执行权限，防止因文件权限问题导致 "Permission denied" 错误
if [ -f "./backup.sh" ]; then
    chmod +x ./backup.sh
fi

# 1. 判断是否启用备份服务
# 逻辑：只要检测到 GITHUB_TOKEN，就认为用户想要开启备份
if [ -n "$GITHUB_TOKEN" ]; then
    echo "[Entrypoint] 检测到 GITHUB_TOKEN..."
    
    if [ -f "./backup.sh" ]; then
        echo "[Entrypoint] 正在后台启动自动备份服务 (backup.sh)..."
        
        # 核心知识点解释：
        # & 符号：将命令放入后台运行 (Background)。
        # 如果不加 &，容器会卡在这里死等 backup.sh 结束（而它是个死循环），导致主程序永远无法启动。
        ./backup.sh &
        
    else
        echo "[Entrypoint-警告] 想要启动备份，但未找到 backup.sh 文件！"
    fi
else
    echo "[Entrypoint] 未检测到 GITHUB_TOKEN，跳过自动备份服务。"
    echo "[Entrypoint] 提示：如果需要备份，请设置 GITHUB_TOKEN 和 BACKUP_REPO_URL 环境变量。"
fi

# -----------------------------------------------------------------------------

# 2. 启动主程序 (Node.js 应用)
echo "[Entrypoint] 正在启动应用程序 (npm start)..."

# 核心知识点解释：
# exec 命令：用接下来的命令 (npm start) 替换当前的 Shell 进程。
# 结果：npm start 产生的 node 进程会变成容器的 PID 1。
# 好处：当你执行 docker stop 时，停止信号 (SIGTERM) 能直接传给 node 进程，实现优雅退出。
# 如果不用 exec，Shell 会保留为 PID 1，node 是它的子进程，往往无法正确接收停止信号。
exec npm start
