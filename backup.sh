#!/bin/bash
# -----------------------------------------------------------------------------
# backup.sh - 自动备份脚本 (修复 SQLite 只读报错版)
# -----------------------------------------------------------------------------

# ================= 配置区域 =================
SOURCE_FILE="${DB_PATH:-/app/database/nav.db}"
SOURCE_DIR=$(dirname "$SOURCE_FILE")  # 获取父目录 /app/database
BACKUP_DIR="/app/nav-backup-repo"
GITHUB_EMAIL="${GITHUB_EMAIL:-bot@nav.backup}"
GITHUB_NAME="${GITHUB_NAME:-NavBackupBot}"

# URL 解析
if [ -n "$BACKUP_REPO_URL" ]; then
    TEMP_URL="${BACKUP_REPO_URL#https://github.com/}"
    TEMP_URL="${TEMP_URL#http://github.com/}"
    TEMP_URL="${TEMP_URL%.git}"
    TEMP_URL="${TEMP_URL%/}"
    GITHUB_USER=$(echo "$TEMP_URL" | cut -d'/' -f1)
    GITHUB_REPO=$(echo "$TEMP_URL" | cut -d'/' -f2)
else
    GITHUB_USER="${GITHUB_USER}"
    GITHUB_REPO="${GITHUB_REPO}"
fi

# 安全检查
if [ -z "$GITHUB_TOKEN" ] || [ -z "$GITHUB_USER" ] || [ -z "$GITHUB_REPO" ]; then
    echo "[错误] 环境变量缺失，无法启动同步。"
    exit 1
fi

GIT_URL="https://${GITHUB_USER}:${GITHUB_TOKEN}@github.com/${GITHUB_USER}/${GITHUB_REPO}.git"
CHECK_INTERVAL="${BACKUP_INTERVAL:-10}"

# =============================================================

# --- 辅助函数：暴力修复权限 ---
fix_permissions() {
    # 1. 确保目录本身可写 (SQLite 需要创建 journal 文件)
    if [ -d "$SOURCE_DIR" ]; then
        chmod 777 "$SOURCE_DIR"
    fi

    # 2. 确保数据库文件可读写
    if [ -f "$SOURCE_FILE" ]; then
        chmod 666 "$SOURCE_FILE"
    fi
}

# --- 初始化环境 ---
init_repo() {
    git config --global --add safe.directory "$BACKUP_DIR"

    if [ ! -d "$BACKUP_DIR" ]; then
        echo "[同步服务] 初始化：正在克隆仓库..."
        git clone "$GIT_URL" "$BACKUP_DIR"
        
        if [ $? -ne 0 ]; then
            exit 1
        fi
        
        cd "$BACKUP_DIR" || exit
        git config user.email "$GITHUB_EMAIL"
        git config user.name "$GITHUB_NAME"
        
        # 初始加载
        if [ -f "nav.db" ]; then
             echo "[同步服务] 初始覆盖本地数据库..."
             # [关键技巧] 使用 cat 重定向，保留原文件属性，不破坏 inode
             cat nav.db > "$SOURCE_FILE"
             fix_permissions
        fi
        
        cd ..
    fi
    
    # 无论是否克隆，启动时先修复一次权限
    fix_permissions
}

# --- 核心监控循环 ---
monitor() {
    echo "[同步服务] 启动监控..."
    
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
            echo "[同步服务] 云端有更新，正在拉取..."
            git pull origin main --rebase
            
            if [ -f "nav.db" ]; then
                echo "[同步服务] 覆盖本地数据库..."
                
                # [关键技巧] 使用 cat 而不是 cp
                # cat 的原理是将内容写入已存在的文件，而不是替换文件
                # 这样可以最大程度避免权限丢失问题
                cat nav.db > "$SOURCE_FILE"
                
                # 再次暴力修复权限，确保万无一失
                fix_permissions
                
                LAST_TIME=$(stat -c %Y "$SOURCE_FILE")
            fi
        fi
        cd .. 

        # === 阶段二：上行同步 (Local -> Cloud) ===
        if [ ! -f "$SOURCE_FILE" ]; then continue; fi

        CURRENT_TIME=$(stat -c %Y "$SOURCE_FILE")

        if [ "$CURRENT_TIME" != "$LAST_TIME" ]; then
            sleep 2
            FINAL_TIME=$(stat -c %Y "$SOURCE_FILE")
            if [ "$FINAL_TIME" != "$CURRENT_TIME" ]; then continue; fi
            
            # 只有当时间变了，我们再检查一次权限，防止因为意外变为只读
            fix_permissions
            
            echo "[同步服务] 本地变化，准备上传..."
            cd "$BACKUP_DIR" || exit
            git pull origin main --rebase > /dev/null 2>&1
            
            # 这里用 cp 没关系，因为是往仓库里备
            cp -f "$SOURCE_FILE" .
            
            if [ -n "$(git status --porcelain)" ]; then
                git add .
                git commit -m "自动同步: $(date '+%Y-%m-%d %H:%M:%S')"
                git push origin main
                if [ $? -eq 0 ]; then
                    echo "[同步服务] 推送成功。"
                fi
            fi
            
            LAST_TIME=$FINAL_TIME
            cd ..
        fi
    done
}

init_repo
monitor
