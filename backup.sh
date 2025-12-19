#!/bin/bash
# -----------------------------------------------------------------------------
# backup.sh - SQL 文本同步脚本 (安全写入版)
# -----------------------------------------------------------------------------

# ================= 配置区域 =================
SOURCE_FILE="${DB_PATH:-/app/database/nav.db}"
SOURCE_DIR=$(dirname "$SOURCE_FILE")
BACKUP_DIR="/app/nav-backup-repo"
SQL_FILE="nav_data.sql"  # 🟢 核心差异：我们同步 SQL 文件，而不是 db 文件

# Git 环境变量
GITHUB_EMAIL="${GITHUB_EMAIL:-bot@nav.backup}"
GITHUB_NAME="${GITHUB_NAME:-NavBackupBot}"

# --- URL 解析 (保持不变) ---
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

# --- 辅助函数：权限修复 ---
fix_permissions() {
    # 确保目录和文件对当前用户可写
    if [ -d "$SOURCE_DIR" ]; then chmod 777 "$SOURCE_DIR"; fi
    if [ -f "$SOURCE_FILE" ]; then chmod 666 "$SOURCE_FILE"; fi
}

# 🟢 核心功能 1: 导出 (DB -> SQL)
export_db_to_sql() {
    # 使用 .dump 生成 SQL 文本，方便 GitHub 比较版本差异
    sqlite3 "$SOURCE_FILE" .dump > "$BACKUP_DIR/$SQL_FILE"
}

# 🟢 核心功能 2: 还原 (SQL -> Temp DB -> Cat -> Live DB)
restore_db_from_sql() {
    echo "[同步服务] 正在准备从 SQL 还原数据库..."
    
    # 定义临时文件路径 (放在 /tmp 目录下，避免污染数据目录)
    TEMP_DB="/tmp/nav_restore.db"
    
    # 1. 清理旧的临时文件
    if [ -f "$TEMP_DB" ]; then rm "$TEMP_DB"; fi
    
    # 2. 【转换】将 SQL 文本转回 二进制数据库
    # 这一步是安全隔离的，如果 SQL 文件坏了，报错只会在这里停止，不会损坏正式库
    echo "[同步服务] 正在构建临时数据库..."
    sqlite3 "$TEMP_DB" < "$BACKUP_DIR/$SQL_FILE"
    
    # 3. 【验证】检查临时数据库是否生成成功
    if [ -f "$TEMP_DB" ] && [ -s "$TEMP_DB" ]; then
        echo "[同步服务] 临时库构建成功，准备安全写入..."
        
        # (可选) 稍微备份一下当前的（防止万一），不想要可以注释掉
        # cp "$SOURCE_FILE" "${SOURCE_FILE}.bak_overwrite" 2>/dev/null
        
        # 4. 【核心】使用 cat 覆盖写入
        # 作用：保留 nav.db 原有的 Inode 和权限，只替换文件内容
        cat "$TEMP_DB" > "$SOURCE_FILE"
        
        # 5. 清理
        rm "$TEMP_DB"
        fix_permissions
        
        echo "[同步服务] 数据库还原完成 (Safe Mode)。"
    else
        echo "[错误] SQL 转换失败或文件为空，跳过还原，原数据库未受影响。"
    fi
}

# --- 初始化逻辑 ---
init_repo() {
    git config --global --add safe.directory "$BACKUP_DIR"

    if [ ! -d "$BACKUP_DIR" ]; then
        echo "[同步服务] 初始化：正在克隆仓库..."
        git clone "$GIT_URL" "$BACKUP_DIR"
        
        if [ $? -ne 0 ]; then exit 1; fi
        
        cd "$BACKUP_DIR" || exit
        git config user.email "$GITHUB_EMAIL"
        git config user.name "$GITHUB_NAME"
        
        # 🟢 启动检查：如果云端有 SQL 备份，优先恢复
        # 这防止了新部署的环境（空数据库）覆盖掉云端数据
        if [ -f "$SQL_FILE" ]; then
             echo "[同步服务] 检测到云端备份，执行初始恢复..."
             cd .. # 回到根目录以便操作 database
             restore_db_from_sql
             cd "$BACKUP_DIR" || exit
        else
            echo "[同步服务] 云端无备份，使用当前本地数据初始化。"
        fi
        
        cd ..
    fi
    fix_permissions
}

# --- 监控循环 ---
monitor() {
    echo "[同步服务] 启动监控 (模式: SQL文本同步)..."
    
    # 初始化时间戳
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
            echo "[同步服务] 云端有更新 ($BEHIND_COUNT 个提交)，正在拉取..."
            git pull origin main --rebase
            
            # 检查是否有 SQL 文件的变更
            # 如果只是改了 README.md，我们不需要重置数据库
            if git diff HEAD@{1} HEAD --name-only | grep -q "$SQL_FILE"; then
                echo "[同步服务] SQL 数据文件发生变更，执行还原..."
                cd ..
                restore_db_from_sql
                cd "$BACKUP_DIR" || exit
                
                # 更新时间戳，防止脚本误判为本地修改
                if [ -f "$SOURCE_FILE" ]; then
                    LAST_TIME=$(stat -c %Y "$SOURCE_FILE")
                fi
            fi
        fi
        cd .. 

        # === 阶段二：上行同步 (Local -> Cloud) ===
        if [ ! -f "$SOURCE_FILE" ]; then continue; fi

        CURRENT_TIME=$(stat -c %Y "$SOURCE_FILE")

        # 检查本地文件修改时间
        if [ "$CURRENT_TIME" != "$LAST_TIME" ]; then
            sleep 2 # 等待写入完成
            FINAL_TIME=$(stat -c %Y "$SOURCE_FILE")
            if [ "$FINAL_TIME" != "$CURRENT_TIME" ]; then continue; fi
            
            echo "[同步服务] 检测到本地变化，生成 SQL 快照..."
            
            # 1. 导出 SQL
            export_db_to_sql
            
            cd "$BACKUP_DIR" || exit
            
            # 2. 清理旧的二进制文件（如果之前误传过 nav.db）
            if [ -f "nav.db" ]; then
                git rm --cached nav.db 2>/dev/null
                rm nav.db 2>/dev/null
            fi
            
            # 3. 提交 SQL
            git add "$SQL_FILE"
            
            if [ -n "$(git status --porcelain)" ]; then
                git commit -m "数据更新: $(date '+%Y-%m-%d %H:%M:%S')"
                git push origin main
                if [ $? -eq 0 ]; then
                    echo "[同步服务] 推送成功。"
                fi
            else
                echo "[同步服务] 数据库时间变了但内容没变 (SQL一致)，跳过提交。"
            fi
            
            LAST_TIME=$FINAL_TIME
            cd ..
        fi
    done
}

init_repo
monitor
