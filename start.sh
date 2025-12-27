#!/bin/bash

# ====================================================
#            Pterodactyl 超级启动脚本 (三合一)
#        1. 自动备份  2. 哪吒探针  3. 网站主程序
# ====================================================

# ⚠️⚠️⚠️ [重点] 哪吒探针安装命令 ⚠️⚠️⚠️
NEZHA_COMMAND=""

# ====================================================
# [模块 1] 哪吒探针功能函数
# ====================================================
init_nezha() {
    if [ -z "$NEZHA_COMMAND" ]; then
        echo "--- [Nezha] 未配置安装命令，跳过启动。"
        return
    fi
    
    # 解析参数
    NZ_SERVER=$(echo "$NEZHA_COMMAND" | grep -o "NZ_SERVER=[^ ]*" | cut -d= -f2)
    NZ_SECRET=$(echo "$NEZHA_COMMAND" | grep -o "NZ_CLIENT_SECRET=[^ ]*" | cut -d= -f2)
    NZ_TLS=$(echo "$NEZHA_COMMAND" | grep -o "NZ_TLS=[^ ]*" | cut -d= -f2)
    [ -z "$NZ_TLS" ] && NZ_TLS="false"

    if [ -z "$NZ_SERVER" ] || [ -z "$NZ_SECRET" ]; then
        echo "--- [Nezha] 参数解析失败，请检查命令格式。"
        return
    fi

    echo "--- [Nezha] 正在配置探针..."
    
    # 下载探针
    bin_file="/home/container/nezha-agent"
    if [ ! -f "$bin_file" ]; then
        case "$(uname -m)" in
            aarch64|arm64) arch="arm64" ;;
            *) arch="amd64" ;;
        esac
        
        echo "--- [Nezha] 正在下载适配 $arch 的探针..."
        download_url="https://github.com/nezhahq/agent/releases/latest/download/nezha-agent_linux_${arch}.zip"
        
        if curl -L -o nezha.zip "$download_url"; then
            unzip -o nezha.zip
            chmod +x "$bin_file"
            rm nezha.zip
        else
            echo "--- [Nezha] 下载失败，请检查网络！"
            return
        fi
    fi

    # 生成配置
    CONFIG_FILE="/home/container/nezha.yml"
    echo "server: $NZ_SERVER" > "$CONFIG_FILE"
    echo "client_secret: $NZ_SECRET" >> "$CONFIG_FILE"
    echo "tls: $NZ_TLS" >> "$CONFIG_FILE"

    # 恢复 UUID
    if [ -f "/home/container/uuid.bak" ]; then
        old_uuid=$(cat /home/container/uuid.bak)
        if [ -n "$old_uuid" ]; then
            echo "uuid: $old_uuid" >> "$CONFIG_FILE"
            echo "--- [Nezha] 已恢复旧 UUID"
        fi
    fi

    # 启动
    echo "--- [Nezha] 启动代理程序..."
    nohup "$bin_file" -c "$CONFIG_FILE" >/dev/null 2>&1 &
    
    # 备份 UUID
    sleep 3
    if grep -q "uuid:" "$CONFIG_FILE"; then
        grep "uuid:" "$CONFIG_FILE" | awk '{print $2}' > /home/container/uuid.bak
    fi
}

# ====================================================
# [主流程] 开始按顺序执行
# ====================================================

# --- 步骤 1: 启动自动备份 (SQL文本 + 触发器版) ---
echo "--- [Backup] 正在启动自动同步服务..."
if [ -f "/home/container/auto_backup.sh" ]; then
    chmod +x /home/container/auto_backup.sh
    # 后台运行备份脚本
    nohup /home/container/auto_backup.sh > /home/container/backup.log 2>&1 &
    echo "--- [Backup] 同步服务已启动 (日志: backup.log)"
else
    echo "--- [Backup] 警告：找不到 auto_backup.sh，跳过备份步骤。"
fi

# --- 步骤 2: 启动哪吒探针 ---
init_nezha

# --- 步骤 3: 启动网站 (主进程 - 热重载版) ---
echo "--- [App] 正在准备网站环境..."

PROJECT_DIR="/home/container/nav-Item"

if [ -d "$PROJECT_DIR/web" ]; then
    # 1. 构建前端
    echo "--- [App] 构建前端资源..."
    cd "$PROJECT_DIR/web"
    npm install  # 确保前端依赖安装
    npm run build
    
    # 2. 回到主目录准备启动后端
    cd "$PROJECT_DIR"
    
    # 3. 安装后端依赖
    echo "--- [App] 检查后端依赖..."
    if [ ! -d "node_modules" ]; then
        npm install
    fi
    
    # 4. 准备热重载环境
    TRIGGER_FILE=".restart_trigger"
    if [ ! -f "$TRIGGER_FILE" ]; then
        touch "$TRIGGER_FILE"
    fi
    
    # 🟢 5. 智能安装 Nodemon (自动判断权限)
    if ! command -v nodemon &> /dev/null; then
        echo "--- [App] 未检测到 Nodemon，正在安装..."
        # 尝试全局安装，如果失败则回退到本地安装
        if npm install -g nodemon 2>/dev/null; then
            echo "--- [App] Nodemon 全局安装成功。"
            NODEMON_CMD="nodemon"
        else
            echo "--- [App] 无 Root 权限，切换为本地安装..."
            npm install nodemon --save-dev
            NODEMON_CMD="./node_modules/.bin/nodemon"
        fi
    else
        NODEMON_CMD="nodemon"
    fi
    
    echo "--- [App] 启动网站主程序 (监听模式)..."
    echo "--- [App] 监听文件: $TRIGGER_FILE"
    
    # 🟢 6. 启动主程序
    # exec 确保 nodemon 替换当前 shell 成为 PID 1，正确接收停止信号
    # --watch "$TRIGGER_FILE": 只有当备份脚本更新了这个文件时，才重启应用
    # --delay 1: 延迟重启，确保文件写入完毕
    exec $NODEMON_CMD \
      --watch "$TRIGGER_FILE" \
      --delay 1 \
      app.js

else
    echo "--- [Error] 找不到网站目录 $PROJECT_DIR，无法启动！"
    # 挂起容器防止无限崩溃重启，方便排查错误
    tail -f /dev/null
fi
