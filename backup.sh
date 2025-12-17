#!/bin/bash
# -----------------------------------------------------------------------------
# backup.sh - 自动备份脚本 (修复权限版)
# -----------------------------------------------------------------------------

# ================= 配置区域 =================
SOURCE_FILE="${DB_PATH:-/app/database/nav.db}"
BACKUP_DIR="/app/nav-backup-repo"
GITHUB_EMAIL="${GITHUB_EMAIL:-bot@nav.backup}"
GITHUB_NAME="${GITHUB_NAME:-NavBackupBot}"

# URL 解析逻辑
if [ -n "$BACKUP_REPO_URL" ]; then
    TEMP_URL="${BACKUP_REPO_URL#https://github.com/}"
    TEMP_URL="${TEMP_URL#http://github.com/}"
    TEMP_URL="${TEMP_URL%.git}"
    TEMP_URL="${TEMP_URL%/}"
    GITHUB_USER=$(echo "$TEMP_URL" | cut -d'/' -f1)
    GITHUB_REPO=$(echo "$TEMP_URL" | cut -d'/' -f2)
    echo "[配置] 解析 URL -> 用户: $GITHUB_USER, 仓库: $GITHUB_REPO"
else
    GITHUB_USER="${GITHUB_USER}"
    GITHUB_REPO="${GITHUB_REPO}"
fi

# 安全性检查
if [ -z "$GITHUB_TOKEN" ]; then
    echo "[错误] 未检测到 GITHUB_TOKEN，脚本无法运行！"
    exit 1
fi
if [ -z "$GITHUB_USER" ] || [ -z "$GITHUB_REPO" ]; then
    echo "[错误] 无法获取仓库信息！"
    exit 1
fi

GIT_URL="https://${GITHUB_USER}:${GITHUB_TOKEN}@github.com/${GITHUB_USER}/${GITHUB_REPO}.git"
CHECK_INTERVAL="${BACKUP_INTERVAL:-10}"

# =============================================================

# --- 初始化环境 ---
init_repo() {
    git config --global --add safe.directory "$BACKUP_DIR"

    if [ ! -d "$BACKUP_DIR" ]; then
        echo "[同步服务] 初始化：正在克隆仓库..."
        git clone "$GIT_URL" "$BACKUP_DIR"
        
        if [ $? -ne 0 ]; then
            echo "[同步服务-错误] 克隆失败，请检查 Token 或 URL。"
            exit 1
        fi
        
        cd "$BACKUP_DIR" || exit
        git config user.email "$GITHUB_EMAIL"
        git config user.name "$GITHUB_NAME"
        
        # 第一次启动：如果云端有数据，覆盖本地
        if [ -f "nav.db" ]; then
             echo "[同步服务] 初始加载：检测到云端有 nav.db，覆盖本地..."
             cp -f nav.db "$SOURCE_FILE"
             # [修复] 强制赋予读写权限 (chmod 666)
             chmod 666 "$SOURCE_FILE"
        fi
        
        cd ..
    fi
}

# --- 核心监控循环 ---
monitor() {
    echo "[同步服务] 启动双向监控，频率: ${CHECK_INTERVAL}s"
    
    if [ -f "$SOURCE_FILE" ]; then
        LAST_TIME=$(stat -c %Y "$SOURCE_FILE")
    else
        LAST_TIME=0
    fi

    while true; do
        sleep "$CHECK_INTERVAL"
        
        # === 阶段一：下行同步 (Cloud -> Local) ===
        cd "$BACKUP_DIR" || exit
        git fetch origin main > /dev/null 2>&1
        BEHIND_COUNT=$(git rev-list HEAD..origin/main --count)
        
        if [ "$BEHIND_COUNT" -gt 0 ]; then
            echo "[同步服务] 检测到云端有 $BEHIND_COUNT 个新提交，正在拉取..."
            git pull origin main --rebase
            
            if [ -f "nav.db" ]; then
                echo "[同步服务] 云端更新 -> 覆盖本地数据库"
                
                # [关键步骤] 覆盖文件
                cp -f nav.db "$SOURCE_FILE"
                
                # [修复] 强制赋予读写权限，防止 SQLITE_READONLY
                chmod 666 "$SOURCE_FILE"
                
                # 更新时间戳防止回环
                LAST_TIME=$(stat -c %Y "$SOURCE_FILE")
            fi
        fi
        
        cd .. 

        # === 阶段二：上行同步 (Local -> Cloud) ===
        if [ ! -f "$SOURCE_FILE" ]; then
            continue
        fi

        CURRENT_TIME=$(stat -c %Y "$SOURCE_FILE")

        if [ "$CURRENT_TIME" != "$LAST_TIME" ]; then
            # 等待写入稳定
            sleep 2
            FINAL_TIME=$(stat -c %Y "$SOURCE_FILE")
            if [ "$FINAL_TIME" != "$CURRENT_TIME" ]; then continue; fi
            
            echo "[同步服务] 检测到本地数据库变化，准备上传..."
            
            cd "$BACKUP_DIR" || exit
            git pull origin main --rebase > /dev/null 2>&1
            
            cp -f "$SOURCE_FILE" .
            
            if [ -n "$(git status --porcelain)" ]; then
                git add .
                CURRENT_DATE_LOG=$(date '+%Y-%m-%d %H:%M:%S')
                git commit -m "自动同步: $CURRENT_DATE_LOG"
                git push origin main
                
                if [ $? -eq 0 ]; then
                    echo "[同步服务] 本地更改 -> 已推送到云端 (时间: $CURRENT_DATE_LOG)"
                else
                    echo "[同步服务-错误] 推送失败。"
                fi
            else
                echo "[同步服务] 文件时间变了但内容没变 (Hash一致)，跳过提交。"
            fi
            
            LAST_TIME=$FINAL_TIME
            cd ..
        fi
    done
}

init_repo
monitor
