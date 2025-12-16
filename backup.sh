#!/bin/bash
# -----------------------------------------------------------------------------
# backup.sh - 自动备份脚本 (适配容器版)
# -----------------------------------------------------------------------------

# ================= 配置区域 (优先读取环境变量) =================

# 1. 监控源文件 (容器内的固定路径)
SOURCE_FILE="${DB_PATH:-/app/database/nav.db}"

# 2. 备份目录 (容器内的临时目录，重启后会重置，但这没关系，因为会拉取云端)
BACKUP_DIR="/app/nav-backup-repo"

# 3. GitHub 信息 (必须通过环境变量传入)
#    GITHUB_TOKEN 在 entrypoint.sh 中已检查，这里直接使用
GITHUB_USER="${GITHUB_USER:-kystor}"        # 默认值 kystor，可覆盖
GITHUB_REPO="${GITHUB_REPO:-nav-backup}"    # 默认值 nav-backup，可覆盖
GITHUB_EMAIL="${GITHUB_EMAIL:-bot@nav.backup}"
GITHUB_NAME="${GITHUB_NAME:-NavBackupBot}"

# 4. 组合仓库地址
GIT_URL="https://${GITHUB_USER}:${GITHUB_TOKEN}@github.com/${GITHUB_USER}/${GITHUB_REPO}.git"

# 5. 检查频率 (秒)
CHECK_INTERVAL="${BACKUP_INTERVAL:-10}"

# =============================================================

# --- 初始化环境 ---
init_repo() {
    # 确保 Git 不过分提示安全目录问题
    git config --global --add safe.directory "$BACKUP_DIR"

    if [ ! -d "$BACKUP_DIR" ]; then
        echo "[备份服务] 初始化：正在克隆仓库 $GITHUB_USER/$GITHUB_REPO ..."
        git clone "$GIT_URL" "$BACKUP_DIR"
        
        if [ $? -ne 0 ]; then
            echo "[备份服务-错误] 无法克隆仓库，请检查 Token 权限或仓库是否存在！"
            # 这里不退出，避免影响主程序，只是停止备份逻辑
            exit 1
        fi
        
        # 配置本地 Git 用户信息
        cd "$BACKUP_DIR" || exit
        git config user.email "$GITHUB_EMAIL"
        git config user.name "$GITHUB_NAME"
        cd ..
        echo "[备份服务] 初始化完成。"
    fi
}

# --- 核心监控循环 ---
monitor() {
    echo "[备份服务] 启动监控，频率: ${CHECK_INTERVAL}s，目标: $SOURCE_FILE"
    
    # 初始时间戳
    LAST_TIME=$(stat -c %Y "$SOURCE_FILE" 2>/dev/null)

    while true; do
        sleep "$CHECK_INTERVAL"

        if [ ! -f "$SOURCE_FILE" ]; then
            continue
        fi

        CURRENT_TIME=$(stat -c %Y "$SOURCE_FILE")

        if [ "$CURRENT_TIME" != "$LAST_TIME" ]; then
            echo "[备份服务] 检测到数据库变化..."
            
            # 等待写入稳定
            sleep 2
            FINAL_TIME=$(stat -c %Y "$SOURCE_FILE")
            
            if [ "$FINAL_TIME" != "$CURRENT_TIME" ]; then
                continue
            fi
            
            # 开始备份流程
            cd "$BACKUP_DIR" || exit

            # 拉取最新代码 (防止冲突)
            git pull origin main --rebase > /dev/null 2>&1

            # 复制数据库文件过来
            cp -f "$SOURCE_FILE" .

            # 提交并推送
            if [ -n "$(git status --porcelain)" ]; then
                git add .
                git commit -m "自动备份: $(date '+%Y-%m-%d %H:%M:%S')"
                git push origin main
                
                if [ $? -eq 0 ]; then
                    echo "[备份服务] 备份成功！已推送到 GitHub。"
                else
                    echo "[备份服务-错误] 推送失败。"
                fi
            else
                echo "[备份服务] 文件时间戳变了但内容没变 (Git未检测到差异)。"
            fi

            # 更新基准时间
            LAST_TIME=$FINAL_TIME
            cd .. # 回到 /app
        fi
    done
}

# --- 入口 ---
init_repo
monitor
