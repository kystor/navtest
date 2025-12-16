#!/bin/bash
# -----------------------------------------------------------------------------
# entrypoint.sh - 容器启动入口
# -----------------------------------------------------------------------------

# 1. 判断是否传入了 GitHub Token
#    如果传入了 Token，说明用户想启用备份功能
if [ -n "$GITHUB_TOKEN" ]; then
    echo "[Entrypoint] 检测到 GITHUB_TOKEN，正在后台启动自动备份服务..."
    
    # 在后台运行备份脚本 (& 符号表示后台运行)
    # 并将日志输出到标准输出，方便 docker logs 查看
    ./backup.sh &
else
    echo "[Entrypoint] 未检测到 GITHUB_TOKEN，跳过自动备份服务。"
fi

# 2. 启动主程序 (这是原来 Dockerfile 里的 CMD)
#    使用 exec 可以让 node 进程替换当前 shell 成为 PID 1，利于信号接收
echo "[Entrypoint] 正在启动应用程序..."
exec npm start
